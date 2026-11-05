#!/usr/bin/env bash
# Shared helpers for the capstone scripts. Source this file, do not run it.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT/terraform"
REGION="${AWS_REGION:-eu-north-1}"
export PYTHONUTF8=1
# shellcheck disable=SC2034  # used by the scripts that source this file
K="/usr/local/bin/k3s kubectl"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m OK\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }

tf_out() { terraform -chdir="$TF_DIR" output -raw "$1" | tr -d '\r'; }

# ssm_run <instance-id> <one-line shell command>
# Runs the command on the instance (no SSH, no public IP) and prints its stdout.
# Returns 1 if the command failed.
ssm_run() {
  local id="$1" cmd="$2" esc cid status
  esc=${cmd//\\/\\\\}
  esc=${esc//\"/\\\"}
  cid=$(aws ssm send-command --region "$REGION" --instance-ids "$id" \
        --document-name AWS-RunShellScript \
        --parameters "{\"commands\":[\"$esc\"]}" \
        --query Command.CommandId --output text | tr -d '\r') || return 1
  status=Pending
  for _ in $(seq 1 100); do
    status=$(aws ssm get-command-invocation --region "$REGION" --command-id "$cid" \
             --instance-id "$id" --query Status --output text 2>/dev/null | tr -d '\r' || echo Pending)
    case "$status" in Success|Failed|Cancelled|TimedOut) break ;; esac
    sleep 3
  done
  aws ssm get-command-invocation --region "$REGION" --command-id "$cid" --instance-id "$id" \
      --query StandardOutputContent --output text | tr -d '\r'
  if [ "$status" != "Success" ]; then
    aws ssm get-command-invocation --region "$REGION" --command-id "$cid" --instance-id "$id" \
        --query StandardErrorContent --output text >&2
    return 1
  fi
}
