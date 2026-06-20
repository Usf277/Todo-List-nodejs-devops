#!/usr/bin/env bash
# Tears down every AWS resource this project ever created.
# Runs in phases to handle dependency ordering (K8s → LBs → Terraform).
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-todo-list-eks}"
NAMESPACE="${NAMESPACE:-default}"
RELEASE_NAME="${RELEASE_NAME:-todo-app}"
INGRESS_RELEASE="nginx-ingress"
INGRESS_NAMESPACE="ingress-nginx"
MONITORING_NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║    NUCLEAR DESTROY — removes everything      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "This will permanently destroy:"
echo "  • Monitoring stack (Prometheus, Grafana, Loki, Alertmanager)"
echo "  • Helm releases (app + nginx-ingress)"
echo "  • All PersistentVolumeClaims and EBS volumes"
echo "  • EKS cluster, node group, and all pods"
echo "  • VPC, subnets, internet gateway, route tables"
echo "  • ECR repository and ALL pushed images"
echo "  • IAM roles, CI/CD user, and access keys"
echo ""
echo "  NOTE: The S3 state bucket and DynamoDB lock table"
echo "  are NOT destroyed automatically (see Phase 5)."
echo ""
read -rp "  Type 'destroy' to confirm: " CONFIRM
if [[ "$CONFIRM" != "destroy" ]]; then
  echo "  Aborted."
  exit 0
fi

# ── Phase 1: K8s resource cleanup ─────────────────────────────────────────────
echo ""
echo "==> [1/5] Connecting to EKS cluster..."
if aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" 2>/dev/null; then

  echo "==> [2/5] Uninstalling Helm releases..."

  # Monitoring stack first (Prometheus PVCs are expensive; release them early)
  helm uninstall kube-prometheus-stack -n "$MONITORING_NAMESPACE" --wait 2>/dev/null \
    || echo "      kube-prometheus-stack not found — skipping"
  helm uninstall loki -n "$MONITORING_NAMESPACE" --wait 2>/dev/null \
    || echo "      loki not found — skipping"

  # App and ingress
  helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" --wait 2>/dev/null \
    || echo "      $RELEASE_NAME not found — skipping"
  helm uninstall "$INGRESS_RELEASE" -n "$INGRESS_NAMESPACE" --wait 2>/dev/null \
    || echo "      $INGRESS_RELEASE not found — skipping"

  echo "==> [3/5] Deleting PVCs to release EBS volumes..."
  kubectl delete pvc --all -n "$NAMESPACE" --wait=true 2>/dev/null || true
  kubectl delete pvc --all -n "$MONITORING_NAMESPACE" --wait=true 2>/dev/null || true
  kubectl delete namespace "$INGRESS_NAMESPACE" --wait=true 2>/dev/null || true
  kubectl delete namespace "$MONITORING_NAMESPACE" --wait=true 2>/dev/null || true

  echo "      Waiting 60s for AWS Load Balancers to be fully deprovisioned..."
  echo "      (Terraform destroy fails if the LB's ENIs still hold the VPC.)"
  sleep 60
else
  echo "      Cluster not reachable or already deleted — skipping K8s cleanup."
fi

# ── Phase 4: Terraform destroy ────────────────────────────────────────────────
echo ""
echo "==> [4/5] Running terraform destroy (EKS, VPC, ECR, IAM)..."
cd "$TERRAFORM_DIR"
terraform init -reconfigure -input=false -backend-config="region=$REGION"
terraform destroy -auto-approve

# ── Phase 5: Bootstrap resources (manual step) ────────────────────────────────
echo ""
echo "==> [5/5] Bootstrap resources (S3 + DynamoDB) — MANUAL STEP"
echo ""
echo "  The S3 state bucket and DynamoDB lock table were intentionally"
echo "  kept. Destroying them also deletes the Terraform state file."
echo "  If you are 100% done with this project, run:"
echo ""
echo "      cd terraform/bootstrap"
echo "      terraform init"
echo "      # First empty the S3 bucket manually in the AWS console,"
echo "      # then:"
echo "      terraform destroy"
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║   Infrastructure destroyed successfully.    ║"
echo "╚══════════════════════════════════════════════╝"
