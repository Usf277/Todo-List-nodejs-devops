# Terraform Infrastructure

Infrastructure as Code for deploying a Todo List application on AWS with EC2, ECR, and IAM resources.

## Overview

Provisions complete AWS infrastructure for a containerized Node.js application with CI/CD capabilities.

**Resources Created:**
- 2 EC2 Instances (App + MongoDB)
- Elastic IP
- ECR Repository
- IAM User (CI/CD) + EC2 Role
- Security Groups
- SSH Key Pair

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│             Terraform Managed Resources                  │
│                                                          │
│  ┌──────────────────┐         ┌──────────────────┐       │
│  │  IAM Resources   │         │   Amazon ECR     │       │
│  │                  │         │                  │       │
│  │ • CI/CD User     │         │ • todo-list repo │       │
│  │ • Access Keys    │         │ • Image Scanning │       │
│  │ • EC2 Role       │         │                  │       │
│  └──────────────────┘         └──────────────────┘       │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │                   VPC (Default)                     │ │
│  │                                                     │ │
│  │  ┌──────────────────┐      ┌──────────────────┐     │ │
│  │  │  EC2 Instance    │      │  EC2 Instance    │     │ │
│  │  │  (App Server)    │──────│  (MongoDB)       │     │ │
│  │  │──────────────────│      │──────────────────│     │ │
│  │  │ • Ubuntu 22.04   │      │ • Ubuntu 22.04   │     │ │
│  │  │ • t2.micro       │      │ • t2.micro       │     │ │
│  │  │ • Elastic IP     │      │ • Private IP     │     │ │
│  │  │ • IAM Profile    │      │ • MongoDB 7.0    │     │ │
│  │  │ • SG: web_sg     │      │ • SG: mongo_sg   │     │ │
│  │  │ • Ports: 22,80   │      │ • Port: 27017    │     │ │
│  │  │         4000     │      │                  │     │ │
│  │  └──────────────────┘      └──────────────────┘     │ │
│  │                                                     │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              SSH Key Pair (TLS Generated)           │ │
│  │              Saved to: tf-key.pem                   │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `main.tf` | EC2 instances, security groups, EIP, SSH keys |
| `ecr.tf` | Container registry |
| `mongo.tf` | MongoDB server |
| `iam_cicd.tf` | CI/CD IAM user and policies |
| `variables.tf` | Input variables |
| `outputs.tf` | Output values |

## Usage

```bash
# Initialize
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Destroy
terraform destroy
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-east-1` | AWS region |
| `instance_type` | `t2.micro` | EC2 instance type |

## Outputs

| Output | Description |
|--------|-------------|
| `public_ip` | Application server Elastic IP |
| `mongo_private_ip` | MongoDB private IP |
| `app_instance_id` | EC2 instance ID |
| `ecr_repository_url` | ECR repository URL |
| `cicd_access_key_id` | CI/CD user access key |
| `cicd_secret_access_key` | CI/CD user secret (sensitive) |

## Security

- MongoDB accessible only from app server
- EC2 role: ECR read-only access
- CI/CD user: ECR push/pull permissions
- SSH key auto-generated with 0400 permissions
- ECR image scanning enabled

## Cost Estimate

~$18/month (us-east-1):
- 2x EC2 t2.micro: $17
- ECR storage: $0.10
- Elastic IP: Free (when attached)

---

**Managed by Terraform** | **Region**: us-east-1
