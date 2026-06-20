#!/bin/bash
# provision_configure.sh — One-command deployment to EKS
# Replaced EC2+Ansible flow with EKS+Helm flow in Part 3 of the project.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/.."

echo "------------------------------------------------------------------"
echo "🚀 Starting EKS Deployment..."
echo "------------------------------------------------------------------"

# Step 0: Bootstrap remote state backend (S3 + DynamoDB)
# Must run once before main infra. Creates the S3 bucket and DynamoDB table
# that terraform/backend.tf references. Safe to re-run (idempotent).
echo "Step 0: Bootstrapping Remote State Backend (S3 + DynamoDB)..."
cd "$ROOT_DIR/terraform/bootstrap"
terraform init -input=false
terraform apply -auto-approve

# Step 1: Provision EKS cluster, VPC, IAM roles, and ECR
echo "Step 1: Provisioning EKS Infrastructure with Terraform..."
cd "$ROOT_DIR/terraform"
terraform init -input=false
terraform apply -auto-approve

# Extract outputs — note: no more public_ip or mongo_private_ip (those were EC2)
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

# Step 3: Install NGINX Ingress Controller via Helm
# --install makes this idempotent: first run installs, subsequent runs upgrade.
# The controller creates an AWS Network Load Balancer that becomes the public URL.
echo "Step 3: Installing NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.replicaCount=1 \
  --set controller.resources.requests.cpu=50m \
  --set controller.resources.requests.memory=90Mi \
  --wait --timeout 5m
echo "✅ NGINX Ingress Controller installed"

# Step 4: Deploy the Todo App + MongoDB via Helm chart
echo "Step 4: Deploying Todo App via Helm..."
helm upgrade --install todo-app "$ROOT_DIR/helm/todo-app" \
  --namespace default \
  --wait --timeout 5m
echo "✅ Todo App deployed"

# Get the public hostname of the ingress load balancer
echo ""
echo "Getting external URL (may take 2-3 minutes for the AWS NLB to provision)..."
sleep 15
LB_HOST=$(kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "<still provisioning>")

echo "------------------------------------------------------------------"
echo "🎉 Deployment Complete!"
echo "   External URL: http://$LB_HOST"
echo "   (If <still provisioning>, run: kubectl get svc -n ingress-nginx)"
echo "------------------------------------------------------------------"
echo "⚠️🚨  ACTION REQUIRED: GITHUB SECRETS SETUP ⚠️🚨"
echo "Add the following secrets to your GitHub Repository:"
echo ""
echo "  AWS_ACCESS_KEY_ID:     $CICD_AK"
echo "  AWS_SECRET_ACCESS_KEY: $CICD_SK"
echo ""
echo "  These credentials belong to the CI/CD IAM user and already have:"
echo "    - ECR push access (to build and push images)"
echo "    - EKS cluster-admin access (to run helm upgrade in CI)"
echo "------------------------------------------------------------------"
