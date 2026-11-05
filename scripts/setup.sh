#!/usr/bin/env bash
# Verifies that every tool the project needs is installed and authenticated.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

log "Checking required CLI tools"
missing=0
for t in aws terraform kubectl docker git curl; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t found"; else warn "$t NOT found"; missing=1; fi
done
[ "$missing" -eq 0 ] || die "install the missing tools and run this script again"

log "Checking AWS credentials"
arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null | tr -d '\r') \
  || die "AWS CLI is not authenticated (run: aws configure)"
ok "AWS identity: $arn"

log "Checking the Docker daemon"
docker info >/dev/null 2>&1 || die "Docker is installed but the daemon is not running"
ok "Docker daemon reachable"

ok "Setup check passed"
