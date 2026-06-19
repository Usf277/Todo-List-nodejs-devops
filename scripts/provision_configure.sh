#!/bin/bash
set -e

echo "------------------------------------------------------------------"
echo "🚀 Starting Deployment..."
echo "------------------------------------------------------------------"

# Step 0: Bootstrap remote state backend (S3 + DynamoDB)
# This must run once before the main infra — it creates the S3 bucket
# and DynamoDB table that terraform/backend.tf references.
# Safe to re-run: Terraform is idempotent.
echo "Step 0: Bootstrapping Remote State Backend (S3 + DynamoDB)..."
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
cd ../..

# Step 1: Terraform Provisioning
# terraform init connects to the S3 backend configured in backend.tf.
# On first run from a local state, add -migrate-state to move local
# state into S3: terraform init -migrate-state
echo "Step 1: Provisioning Infrastructure with Terraform..."
cd terraform
terraform init
terraform apply -auto-approve

# Extract Output
EIP=$(terraform output -raw public_ip)
MONGO_IP=$(terraform output -raw mongo_private_ip)
ECR_URL=$(terraform output -raw ecr_repository_url)
CICD_AK=$(terraform output -raw cicd_access_key_id)
CICD_SK=$(terraform output -raw cicd_secret_access_key)
APP_INSTANCE_ID=$(terraform output -raw app_instance_id)

cd ..

echo "------------------------------------------------------------------"
echo "✅ Infrastructure Provisioned!"
echo "   App Server IP: $EIP"
echo "   Mongo Server IP: $MONGO_IP"
echo "   SSH Key saved to: terraform/tf-key.pem"
echo "   ECR Repo: $ECR_URL"
echo "------------------------------------------------------------------"

# Step 2: Generate Configuration
echo "Step 2: Generating Configuration (.env)..."
# Create .env locally to be copied by Ansible
cat <<EOF > .env
PORT=4000
mongoDbUrl=mongodb://${MONGO_IP}:27017/todolistDb
IMAGE_NAME=${ECR_URL}:latest
EOF

# Step 3: Generate Ansible Inventory
echo "Step 3: Generating Ansible Inventory..."
cat <<EOF > ansible/inventory.ini
[web]
$EIP ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/tf-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "✅ Inventory generated at ansible/inventory.ini"
echo "------------------------------------------------------------------"

# Step 3: Run Ansible Playbook
echo "Step 3: Configuring Server with Ansible (Installing Docker)..."
echo "⏳ Waiting 30s for SSH to become available..."
sleep 30

cd ansible
ansible-playbook -i inventory.ini playbook.yml

echo "------------------------------------------------------------------"
echo "🎉 Deployment Complete!"
echo "   App Server IP: $EIP"
echo "   You can SSH using: ssh -i terraform/tf-key.pem ubuntu@$EIP"
echo "------------------------------------------------------------------"
echo "⚠️🚨  ACTION REQUIRED: GITHUB SECRETS SETUP ⚠️🚨"
echo "Please add the following secrets to your GitHub Repository:"
echo ""
echo "AWS_ACCESS_KEY_ID:     $CICD_AK"
echo "AWS_SECRET_ACCESS_KEY: $CICD_SK"
echo ""
echo "Note: The AWS Keys provided above are for the CI/CD IAM User created by Terraform."
echo "------------------------------------------------------------------"
