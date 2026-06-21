#!/bin/bash
# provision_configure.sh — One-command deployment to EKS + monitoring stack
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

echo "------------------------------------------------------------------"
echo "🚀 Starting EKS Deployment..."
echo "------------------------------------------------------------------"

# Step 0: Bootstrap remote state backend (S3 + DynamoDB)
echo "Step 0: Bootstrapping Remote State Backend (S3 + DynamoDB)..."
cd "$ROOT_DIR/terraform/bootstrap"
terraform init -input=false
terraform apply -auto-approve

# Step 1: Provision EKS cluster, VPC, IAM roles, and ECR
echo "Step 1: Provisioning EKS Infrastructure with Terraform..."
cd "$ROOT_DIR/terraform"
terraform init -input=false
terraform apply -auto-approve

CLUSTER_NAME=$(terraform output -raw cluster_name)
ECR_URL=$(terraform output -raw ecr_repository_url)
CICD_AK=$(terraform output -raw cicd_access_key_id)
CICD_SK=$(terraform output -raw cicd_secret_access_key)
KUBECONFIG_CMD=$(terraform output -raw kubeconfig_command)

cd "$ROOT_DIR"

echo "------------------------------------------------------------------"
echo "✅ Infrastructure Provisioned!"
echo "   EKS Cluster : $CLUSTER_NAME"
echo "   ECR Repo    : $ECR_URL"
echo "------------------------------------------------------------------"

# Step 2: Point kubectl at the new cluster
echo "Step 2: Configuring kubectl..."
$KUBECONFIG_CMD
echo "✅ kubeconfig updated — kubectl now targets $CLUSTER_NAME"

# Step 3: Install kube-prometheus-stack FIRST
# This installs the Prometheus Operator and its CRDs (including ServiceMonitor).
# NGINX and the app chart both create ServiceMonitor objects — those fail with
# "no matches for kind ServiceMonitor" if the CRD does not exist yet.
echo "Step 3: Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values "$ROOT_DIR/helm/monitoring/values-prometheus-stack.yaml" \
  --wait --timeout 10m
echo "✅ kube-prometheus-stack installed (ServiceMonitor CRD now available)"

# Step 4: Install NGINX Ingress Controller
# serviceMonitor.enabled=true is safe here — the CRD exists from Step 3.
echo "Step 4: Installing NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=1 \
  --set controller.resources.requests.cpu=50m \
  --set controller.resources.requests.memory=90Mi \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --wait --timeout 5m
echo "✅ NGINX Ingress Controller installed"

# Step 5: Deploy the Todo App + MongoDB
# metrics.enabled=true creates a ServiceMonitor — safe because the CRD exists from Step 3.
echo "Step 5: Deploying Todo App via Helm..."
helm upgrade --install todo-app "$ROOT_DIR/helm/todo-app" \
  --namespace default \
  --wait --timeout 5m
echo "✅ Todo App deployed"

# Step 6: Install Loki + Promtail
echo "Step 6: Installing Loki + Promtail (log aggregation)..."
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --values "$ROOT_DIR/helm/monitoring/values-loki.yaml" \
  --wait --timeout 5m
echo "✅ Loki + Promtail installed"

# Get the public hostname of the app ingress load balancer
echo ""
echo "Getting external URL (may take 2-3 minutes for the AWS NLB to provision)..."
sleep 15
LB_HOST=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "<still provisioning>")

echo "------------------------------------------------------------------"
echo "🎉 Deployment Complete!"
echo ""
echo "   App URL    : http://$LB_HOST"
echo "   Grafana    : kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "                then open http://localhost:3000  (admin / admin)"
echo "   Prometheus : kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "------------------------------------------------------------------"
echo "⚠️🚨  ACTION REQUIRED: GITHUB SECRETS SETUP ⚠️🚨"
echo "Add the following secrets to your GitHub Repository:"
echo ""
echo "  AWS_ACCESS_KEY_ID:     $CICD_AK"
echo "  AWS_SECRET_ACCESS_KEY: $CICD_SK"
echo "------------------------------------------------------------------"
