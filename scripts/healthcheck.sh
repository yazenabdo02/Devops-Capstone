#!/usr/bin/env bash
# Checks the nodes, the pods, every backend /health, and the public ALB URL.
# Exit code 0 = everything healthy, 1 = at least one check failed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for t in aws terraform curl; do need "$t"; done

fail=0
CP=$(tf_out control_plane_instance_id)
ALB=$(tf_out alb_dns_name)

log "Cluster nodes"
nodes=$(ssm_run "$CP" "$K get nodes --no-headers") || die "cannot reach the cluster through SSM"
echo "$nodes"
total=$(echo "$nodes" | grep -c . || true)
notready=$(echo "$nodes" | grep -vc ' Ready ' || true)
if [ "$total" -ge 1 ] && [ "$notready" -eq 0 ]; then ok "$total node(s) Ready"; else warn "$notready of $total node(s) not Ready"; fail=1; fi

log "Pods in namespace marketly"
pods=$(ssm_run "$CP" "$K -n marketly get pods --no-headers") || die "cannot list pods"
echo "$pods"
# Pods that are shutting down during a rollout are expected, not a failure.
bad=$(echo "$pods" | grep -v ' Terminating ' | grep -vc ' Running ' || true)
if [ "$bad" -eq 0 ]; then ok "all pods Running"; else warn "$bad pod(s) not Running"; fail=1; fi

log "Backend /health endpoints (through the ClusterIP services)"
for pair in auth-service:5001 catalog-service:5002 orders-service:5003; do
  svc=${pair%%:*}; port=${pair##*:}
  if ssm_run "$CP" "curl -sf -m 10 http://\$($K -n marketly get svc $svc -o jsonpath='{.spec.clusterIP}'):$port/health" >/dev/null 2>&1; then
    ok "$svc /health"
  else
    warn "$svc /health FAILED"; fail=1
  fi
done

log "Public ALB http://$ALB"
for path in "/" "/api/products?page_size=1"; do
  code=$(curl -s -o /dev/null -m 15 -w '%{http_code}' "http://$ALB$path" || true)
  if [ "$code" = "200" ]; then ok "GET $path -> $code"; else warn "GET $path -> $code"; fail=1; fi
done

if [ "$fail" -eq 0 ]; then ok "All health checks passed"; else warn "Some checks failed"; exit 1; fi
