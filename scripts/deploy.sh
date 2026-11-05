#!/usr/bin/env bash
# Local helper: terraform apply, build and push images, create secrets, apply manifests.
# Optional switches:  SKIP_TERRAFORM=1   SKIP_BUILD=1
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for t in aws terraform docker git; do need "$t"; done
cd "$ROOT"

if [ "${SKIP_TERRAFORM:-0}" != "1" ]; then
  log "terraform apply"
  terraform -chdir="$TF_DIR" init -input=false
  terraform -chdir="$TF_DIR" apply -input=false -auto-approve
fi

CP=$(tf_out control_plane_instance_id)
RDS_HOST=$(tf_out rds_endpoint)
DB_PASS=$(tf_out db_password)
ACCOUNT=$(aws sts get-caller-identity --query Account --output text | tr -d '\r')
REG="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
SHA=$(git rev-parse --short HEAD)
SERVICES="auth-service catalog-service orders-service frontend"

log "Waiting for the k3s control-plane to answer"
for i in $(seq 1 60); do
  if ssm_run "$CP" "$K get nodes" >/dev/null 2>&1; then break; fi
  [ "$i" -lt 60 ] || die "the control-plane never became ready"
  sleep 10
done
ok "k3s API is up"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  log "Building and pushing images (tag $SHA)"
  aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REG" >/dev/null
  for svc in auth-service catalog-service orders-service; do
    docker build --provenance=false -t "$REG/capstone/$svc:latest" -t "$REG/capstone/$svc:$SHA" "services/$svc"
  done
  docker build --provenance=false -t "$REG/capstone/frontend:latest" -t "$REG/capstone/frontend:$SHA" frontend
  for svc in $SERVICES; do docker push --all-tags "$REG/capstone/$svc"; done
fi

log "Creating the namespace and secrets on the cluster (nothing is written to git)"
ssm_run "$CP" "$K create namespace marketly --dry-run=client -o yaml | $K apply -f -" >/dev/null

# Keep the existing signing secret so issued tokens stay valid across deploys.
if ! ssm_run "$CP" "$K -n marketly get secret shared-secret" >/dev/null 2>&1; then
  SHARED=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
  ssm_run "$CP" "$K -n marketly create secret generic shared-secret --from-literal=SHARED_SECRET='$SHARED'" >/dev/null
  ok "shared-secret created"
else
  ok "shared-secret already exists, kept"
fi

DB_URL="postgresql://marketly:${DB_PASS}@${RDS_HOST}:5432/marketly"
ssm_run "$CP" "$K -n marketly create secret generic db-credentials --from-literal=DATABASE_URL='$DB_URL' --dry-run=client -o yaml | $K apply -f -" >/dev/null
ok "db-credentials applied"

ECR_PW=$(aws ecr get-login-password --region "$REGION" | tr -d '\r')
ssm_run "$CP" "$K -n marketly create secret docker-registry ecr-pull --docker-server=$REG --docker-username=AWS --docker-password='$ECR_PW' --dry-run=client -o yaml | $K apply -f -" >/dev/null
ok "ecr-pull applied"

log "Applying the manifests from the pushed repository"
REPO_URL=$(git config --get remote.origin.url)
REPO_URL=${REPO_URL/git@github.com:/https://github.com/}
ssm_run "$CP" "command -v git >/dev/null || dnf install -y git; rm -rf /opt/capstone; git clone -q $REPO_URL /opt/capstone && cd /opt/capstone && $K apply -k k8s" >/dev/null \
  || die "could not apply the manifests (is the latest commit pushed to $REPO_URL?)"

log "Rolling out the new images"
for d in $SERVICES; do ssm_run "$CP" "$K -n marketly rollout restart deployment/$d" >/dev/null; done
for d in $SERVICES; do
  ssm_run "$CP" "$K -n marketly rollout status deployment/$d --timeout=180s" >/dev/null \
    || die "rollout of $d failed"
  ok "$d rolled out"
done

log "Applying the HPA (after the first replicas have created their tables)"
ssm_run "$CP" "cd /opt/capstone && $K apply -f k8s/hpa.yaml" >/dev/null
ok "HPA applied"

# The self-hosted runner lives on the control-plane, so every rebuild needs a new one.
# Token source: RUNNER_TOKEN, or the GitHub CLI when it is logged in.
REPO_SLUG=${REPO_URL#https://github.com/}
REPO_SLUG=${REPO_SLUG%.git}
TOKEN="${RUNNER_TOKEN:-}"
if [ -z "$TOKEN" ] && command -v gh >/dev/null 2>&1; then
  TOKEN=$(gh api -X POST "repos/$REPO_SLUG/actions/runners/registration-token" --jq .token 2>/dev/null | tr -d '\r') || TOKEN=""
fi
if [ -n "$TOKEN" ]; then
  log "Registering the self-hosted GitHub runner on the control-plane"
  read -r -d '' RUNNER_SCRIPT <<'EOS' || true
set -e
dnf install -y libicu tar gzip >/dev/null
id runner >/dev/null 2>&1 || useradd -m runner
mkdir -p /opt/actions-runner
cd /opt/actions-runner
if [ ! -f config.sh ]; then
  VER=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
  curl -sL -o runner.tgz "https://github.com/actions/runner/releases/download/v${VER}/actions-runner-linux-x64-${VER}.tar.gz"
  tar xzf runner.tgz
fi
chown -R runner:runner /opt/actions-runner
sudo -H -u runner ./config.sh --unattended --replace --url __URL__ --token __TOKEN__ --name capstone-control-plane --labels k3s >/dev/null
./svc.sh install runner >/dev/null
./svc.sh start >/dev/null
EOS
  RUNNER_SCRIPT=${RUNNER_SCRIPT//__URL__/https://github.com/$REPO_SLUG}
  RUNNER_SCRIPT=${RUNNER_SCRIPT//__TOKEN__/$TOKEN}
  B64=$(printf '%s\n' "$RUNNER_SCRIPT" | base64 | tr -d '\n')
  ssm_run "$CP" "echo $B64 | base64 -d | bash" >/dev/null || die "runner registration failed (token expired?)"
  ok "runner registered (label k3s)"
else
  warn "no RUNNER_TOKEN and the GitHub CLI is not logged in: deploy.yml waits until you register a runner (Settings > Actions > Runners, label k3s)"
fi

ok "Deployed. App URL: http://$(tf_out alb_dns_name)"
