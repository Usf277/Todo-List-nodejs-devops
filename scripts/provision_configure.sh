#!/bin/bash
set -e

echo "------------------------------------------------------------------"
echo "🚀 Starting Deployment..."
echo "------------------------------------------------------------------"

# Step 1: Terraform Provisioning
echo "Step 1: Provisioning Infrastructure with Terraform..."
cd terraform
terraform init
terraform apply -auto-approve

# Extract Output
EIP=$(terraform output -raw public_ip)
cd ..

echo "------------------------------------------------------------------"
echo "✅ Infrastructure Provisioned!"
echo "   EC2 Elastic IP: $EIP"
echo "   SSH Key saved to: terraform/tf-key.pem"
echo "------------------------------------------------------------------"

# Step 2: Generate Ansible Inventory
echo "Step 2: Generating Ansible Inventory..."
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
