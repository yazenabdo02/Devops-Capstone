#!/usr/bin/env bash
# Destroys every AWS resource Terraform created. Pass --yes to skip the prompt.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need terraform; need aws

warn "This destroys the VPC, NAT, k3s nodes, RDS database, ALB and ECR images."
if [ "${1:-}" != "--yes" ]; then
  read -r -p "Type 'destroy' to continue: " answer
  [ "$answer" = "destroy" ] || { log "Aborted, nothing was changed"; exit 1; }
fi

destroy_with_retry() {
  local attempt out
  for attempt in 1 2 3; do
    log "terraform destroy (attempt $attempt of 3)"
    if terraform -chdir="$TF_DIR" destroy -input=false -auto-approve; then
      return 0
    fi
    warn "destroy did not finish, checking whether RDS is already gone"
    # RDS can finish deleting after Terraform stops waiting. Only when AWS itself says
    # the instance does not exist is it safe to drop it from the state.
    if terraform -chdir="$TF_DIR" state list 2>/dev/null | grep -q '^module.rds.aws_db_instance.this$'; then
      out=$(aws rds describe-db-instances --region "$REGION" --db-instance-identifier capstone-postgres 2>&1 || true)
      if echo "$out" | grep -q 'DBInstanceNotFound'; then
        terraform -chdir="$TF_DIR" state rm module.rds.aws_db_instance.this >/dev/null
        ok "RDS is already deleted, removed from the Terraform state"
      fi
    fi
    if [ "$attempt" -lt 3 ]; then
      log "waiting 60s before retrying (network interfaces take a moment to be released)"
      sleep 60
    fi
  done
  return 1
}

log "terraform destroy"
terraform -chdir="$TF_DIR" init -input=false >/dev/null
destroy_with_retry || die "terraform destroy kept failing after 3 attempts, see the output above"

log "Checking for leftovers"
left=0
ec2=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=capstone-*" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' --output text | tr -d '\r')
[ -z "$ec2" ] || { warn "EC2 instances left: $ec2"; left=1; }
rds=$(aws rds describe-db-instances --region "$REGION" \
  --query "DBInstances[?DBInstanceIdentifier=='capstone-postgres'].DBInstanceStatus" --output text | tr -d '\r')
[ -z "$rds" ] || { warn "RDS instance still exists ($rds)"; left=1; }
alb=$(aws elbv2 describe-load-balancers --region "$REGION" \
  --query "LoadBalancers[?LoadBalancerName=='capstone-alb'].LoadBalancerArn" --output text | tr -d '\r')
[ -z "$alb" ] || { warn "ALB still exists"; left=1; }

if [ "$left" -eq 0 ]; then
  ok "Everything is gone. Only the Terraform state bucket and lock table remain (cents per month)."
else
  die "some resources are still being deleted, run this script again in a minute"
fi
