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

log "terraform destroy"
terraform -chdir="$TF_DIR" init -input=false >/dev/null
terraform -chdir="$TF_DIR" destroy -input=false -auto-approve

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
