#!/bin/bash
set -euxo pipefail

# Wait for internet (NAT) and for the control-plane API to answer.
for i in $(seq 1 60); do
  curl -sfI https://get.k3s.io > /dev/null && break
  sleep 5
done

for i in $(seq 1 120); do
  curl -sk https://${control_plane_ip}:6443/ping | grep -q pong && break
  sleep 5
done

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${control_plane_ip}:6443" \
  K3S_TOKEN="${k3s_token}" sh -
