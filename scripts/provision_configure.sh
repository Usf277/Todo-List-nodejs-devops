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
  --values "$ROOT_DIR/helm/monitoring/values-prometheus-stack.yaml"

echo "   Waiting for Prometheus Operator and CRDs to be ready..."
kubectl rollout status deployment/kube-prometheus-stack-operator \
  -n monitoring --timeout=5m
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

# Step 5: Build and push the Docker image to ECR
# The app Deployment pulls from ECR. If no image exists yet (first provision,
# before CI has run), pods get ImagePullBackOff and the Helm --wait times out.
echo "Step 5: Building and pushing Docker image to ECR..."
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin "$ECR_URL"

docker build -f "$ROOT_DIR/docker/Dockerfile" \
  -t "$ECR_URL:latest" \
  "$ROOT_DIR"

docker push "$ECR_URL:latest"
echo "✅ Image pushed to ECR"

# Step 6: Create EBS CSI StorageClass
# EKS 1.23+ drops the in-tree aws-ebs provisioner. The EBS CSI addon (IRSA-backed)
# is installed by Terraform, but the cluster ships with no default StorageClass that
# uses it. Without this, MongoDB's volumeClaimTemplate stays Pending indefinitely.
echo "Step 6: Creating gp2-csi StorageClass for EBS CSI driver..."
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp2-csi
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp2
  fsType: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
echo "✅ gp2-csi StorageClass created (default)"

# Step 7: Deploy the Todo App + MongoDB
# metrics.enabled=true creates a ServiceMonitor — safe because the CRD exists from Step 3.
echo "Step 7: Deploying Todo App via Helm..."
helm upgrade --install todo-app "$ROOT_DIR/helm/todo-app" \
  --namespace default

# Wait for MongoDB first — it needs an EBS volume provisioned (WaitForFirstConsumer).
# Provisioning takes 30-90 seconds; rollout status polls until Ready or timeout.
echo "   Waiting for MongoDB (EBS volume provision + startup)..."
kubectl rollout status statefulset/todo-app-mongodb \
  -n default --timeout=5m

echo "   Waiting for app deployment..."
kubectl rollout status deployment/todo-app \
  -n default --timeout=3m

echo "✅ Todo App deployed"

# Step 8: Install Loki + Promtail
echo "Step 8: Installing Loki + Promtail (log aggregation)..."
helm upgrade --install loki grafana/loki-stack \
  --namespace monitoring \
  --values "$ROOT_DIR/helm/monitoring/values-loki.yaml" \
  --wait --timeout 5m
echo "✅ Loki + Promtail installed"

# Get the public hostname of the app ingress load balancer.
# AWS NLBs take 1-3 minutes to provision after the Service is created.
echo ""
echo "Waiting for AWS NLB to provision (up to 3 minutes)..."
LB_HOST=""
for i in $(seq 1 18); do
  LB_HOST=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "$LB_HOST" ] && break
  echo "   ... waiting (${i}/18)"
  sleep 10
done
[ -z "$LB_HOST" ] && LB_HOST="<still provisioning — run: kubectl get svc -n ingress-nginx>"

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
