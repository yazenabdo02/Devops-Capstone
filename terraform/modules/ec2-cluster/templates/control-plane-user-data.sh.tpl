#!/bin/bash
set -euxo pipefail

# Wait until the NAT instance gives us internet access.
for i in $(seq 1 60); do
  curl -sfI https://get.k3s.io > /dev/null && break
  sleep 5
done

# Expose Traefik on a fixed NodePort so the ALB can target it.
mkdir -p /var/lib/rancher/k3s/server/manifests
cat > /var/lib/rancher/k3s/server/manifests/traefik-config.yaml <<'EOF'
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    service:
      type: NodePort
    ports:
      web:
        nodePort: 30080
      websecure:
        nodePort: 30443
EOF

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="server --disable servicelb --write-kubeconfig-mode 644" \
  K3S_TOKEN="${k3s_token}" sh -
