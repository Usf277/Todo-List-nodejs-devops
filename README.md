# Todo List Application - DevOps Infrastructure

A production-ready Node.js Todo List application with complete DevOps infrastructure including automated CI/CD pipelines, Infrastructure as Code, and configuration management.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Infrastructure Components](#infrastructure-components)
  - [Terraform Resources](#terraform-resources)
  - [Ansible Configuration](#ansible-configuration)
  - [CI/CD Pipeline](#cicd-pipeline)
- [Deployment Workflow](#deployment-workflow)
- [Configuration](#configuration)
- [Auto-Update Mechanism](#auto-update-mechanism)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Screenshots](#screenshots)

---

## Overview

This project demonstrates a complete DevOps workflow for deploying a Node.js web application on AWS. The solution implements:

- **Infrastructure as Code** using Terraform to provision AWS resources
- **Configuration Management** using Ansible to configure EC2 instances
- **Containerization** using Docker for application packaging
- **CI/CD Pipeline** using GitHub Actions for automated builds and deployments
- **Auto-Update Mechanism** using cron-based image polling for continuous deployment

### Application Description

The Todo List application is a web-based task management system built with Node.js, Express.js, and MongoDB. Users can create, update, categorize, and delete tasks through an intuitive web interface.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GitHub Repository                                 │
│                                   │                                         │
│                          Push to main/master                                │
│                                   ▼                                         │
│                          ┌──────────────────┐                               │
│                          │  GitHub Actions  │                               │
│                          │   CI Pipeline    │                               │
│                          └────────┬─────────┘                               │
│                                   │                                         │
│                          Build & Push Image                                 │
│                                   ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                              AWS Cloud                                 │ │
│  │                                                                        │ │
│  │   ┌─────────────┐         ┌─────────────────────────────────────────┐  │ │
│  │   │     ECR     │◄────────│              Docker Image               │  │ │
│  │   │  Registry   │         │         (todo-list:latest)              │  │ │
│  │   └──────┬──────┘         └─────────────────────────────────────────┘  │ │
│  │          │                                                             │ │
│  │          │ Pull Image (cron job every 1 min)                           │ │
│  │          ▼                                                             │ │
│  │   ┌─────────────────────┐              ┌─────────────────────┐         │ │
│  │   │   App Server (EC2)  │              │  MongoDB Server     │         │ │
│  │   │   ┌─────────────┐   │              │      (EC2)          │         │ │
│  │   │   │   Docker    │   │    :27017    │   ┌─────────────┐   │         │ │
│  │   │   │  Container  │───┼──────────────┼──►│  MongoDB    │   │         │ │
│  │   │   │  (Port 4000)│   │              │   │   7.0       │   │         │ │
│  │   │   └─────────────┘   │              │   └─────────────┘   │         │ │
│  │   │   Elastic IP        │              │                     │         │ │
│  │   └─────────────────────┘              └─────────────────────┘         │ │
│  │          ▲                                       ▲                     │ │
│  │          │                                       │                     │ │
│  │   ┌──────┴───────┐                      ┌────────┴───────┐             │ │
│  │   │  web_sg      │                      │   mongo_sg     │             │ │
│  │   │  22,80,4000  │                      │   27017 (from  │             │ │
│  │   │  (0.0.0.0/0) │                      │    web_sg)     │             │ │
│  │   └──────────────┘                      └────────────────┘             │ │
│  │                                                                        │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Category | Technology | Purpose |
|----------|------------|---------|
| **Application** | Node.js 18, Express.js, EJS | Web application runtime and templating |
| **Database** | MongoDB 7.0, Mongoose | Data persistence |
| **Containerization** | Docker, Docker Compose | Application packaging and orchestration |
| **Infrastructure** | Terraform | AWS resource provisioning |
| **Configuration** | Ansible | Server configuration management |
| **CI/CD** | GitHub Actions | Automated build and deployment |
| **Cloud Provider** | AWS (EC2, ECR, IAM, EIP) | Cloud infrastructure |
| **OS** | Ubuntu 22.04 LTS | Server operating system |

---

## Project Structure

```
.
├── app/                          # Node.js application source code
│   ├── assets/                   # Static assets (CSS, JS)
│   ├── config/                   # Application configuration
│   │   └── mongoose.js           # MongoDB connection setup
│   ├── controllers/              # Route controllers
│   ├── models/                   # Mongoose data models
│   ├── routes/                   # Express routes
│   ├── views/                    # EJS templates
│   ├── index.js                  # Application entry point
│   └── package.json              # Node.js dependencies
├── ansible/                      # Ansible configuration
│   ├── inventory.ini.example     # Inventory template
│   └── playbook.yml              # Server configuration playbook
├── compose/                      # Docker Compose files
│   └── docker-compose.yml        # Application orchestration
├── docker/                       # Docker configuration
│   └── Dockerfile                # Application container definition
├── scripts/                      # Automation scripts
│   ├── auto-update.sh            # Container auto-update script
│   └── provision_configure.sh    # Full deployment automation
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Core infrastructure (EC2, SG, IAM)
│   ├── ecr.tf                    # ECR repository
│   ├── iam_cicd.tf               # CI/CD IAM user and policies
│   ├── mongo.tf                  # MongoDB server infrastructure
│   ├── variables.tf              # Input variables
│   └── outputs.tf                # Output values
├── .github/workflows/            # GitHub Actions
│   └── ci.yml                    # CI/CD pipeline definition
├── .env.example                  # Environment variables template
└── .dockerignore                 # Docker build exclusions
```

---

## Prerequisites

Before deploying this project, ensure you have the following installed and configured:

| Tool | Version | Purpose |
|------|---------|---------|
| AWS CLI | 2.x | AWS authentication and resource management |
| Terraform | 1.0+ | Infrastructure provisioning |
| Ansible | 2.9+ | Configuration management |
| Docker | 20.10+ | Local container testing |
| Git | 2.x | Version control |

### AWS Requirements

- AWS account with appropriate permissions
- AWS CLI configured with credentials (`aws configure`)
- Permissions for: EC2, ECR, IAM, VPC, EIP

---

## Quick Start

### One-Command Deployment

The fastest way to deploy the entire infrastructure:

```bash
# Clone the repository
git clone https://github.com/Usf277/Todo-List-nodejs-devops.git
cd Todo-List-nodejs-devops

# Run the automated deployment script
./scripts/provision_configure.sh
```

This script will:
1. Provision all AWS infrastructure with Terraform
2. Generate the `.env` configuration file
3. Create the Ansible inventory
4. Configure the EC2 instance with Docker
5. Deploy the application container
6. Output the CI/CD credentials for GitHub Secrets

### Manual Step-by-Step Deployment

#### Step 1: Provision Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

#### Step 2: Configure Environment

Create the `.env` file with outputs from Terraform:

```bash
# Get Terraform outputs
export EIP=$(terraform output -raw public_ip)
export MONGO_IP=$(terraform output -raw mongo_private_ip)
export ECR_URL=$(terraform output -raw ecr_repository_url)

# Create .env file
cat <<EOF > ../.env
PORT=4000
mongoDbUrl=mongodb://${MONGO_IP}:27017/todolistDb
IMAGE_NAME=${ECR_URL}:latest
EOF
```

#### Step 3: Generate Ansible Inventory

```bash
cat <<EOF > ../ansible/inventory.ini
[web]
$EIP ansible_user=ubuntu ansible_ssh_private_key_file=../terraform/tf-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
```

#### Step 4: Configure Server with Ansible

```bash
cd ../ansible
# Wait for EC2 instance to be ready
sleep 30
ansible-playbook -i inventory.ini playbook.yml
```

#### Step 5: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

| Secret Name | Value Source |
|-------------|--------------|
| `AWS_ACCESS_KEY_ID` | `terraform output -raw cicd_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | `terraform output -raw cicd_secret_access_key` |

---

## Infrastructure Components

### Terraform Resources

| Resource | Name | Description |
|----------|------|-------------|
| `aws_instance` | `app_server` | Application server (Ubuntu 22.04, t2.micro) |
| `aws_instance` | `mongo_server` | MongoDB database server |
| `aws_eip` | `lb` | Elastic IP for stable public addressing |
| `aws_ecr_repository` | `app_repo` | Container image registry |
| `aws_security_group` | `web_sg` | App server firewall (ports 22, 80, 4000) |
| `aws_security_group` | `mongo_sg` | MongoDB firewall (port 27017 from web_sg only) |
| `aws_iam_role` | `ec2_role` | EC2 instance role for ECR access |
| `aws_iam_user` | `cicd_user` | CI/CD pipeline IAM user |
| `aws_key_pair` | `kp` | SSH key pair for EC2 access |

### Ansible Configuration

The Ansible playbook (`ansible/playbook.yml`) performs the following tasks:

1. **System Updates**: Updates apt cache and installs dependencies
2. **Docker Installation**: Installs Docker CE and Docker Compose plugin
3. **User Configuration**: Adds ubuntu user to docker group
4. **Application Setup**: Creates app directory and copies configuration files
5. **Auto-Update Setup**: Configures cron job for automatic image updates
6. **ECR Authentication**: Logs into AWS ECR registry
7. **Application Deployment**: Pulls and starts the application container for initial run

### CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) triggers on:
- Push to `main` or `master` branches
- Pull requests to `main` or `master` branches

**Pipeline Steps:**

1. Checkout repository
2. Configure AWS credentials
3. Login to Amazon ECR
4. Build Docker image with commit SHA tag
5. Push image to ECR with both SHA tag and `latest` tag

---

## Deployment Workflow

```
Developer Push → GitHub Actions → ECR → Auto-Update Script → Running Container
     │                │            │            │                    │
     │                │            │            │                    │
     ▼                ▼            ▼            ▼                    ▼
  Code Change    Build Image   Store Image   Pull Latest      Zero-Downtime
                 Tag: sha      Tag: latest   Every 1 min        Update
```

---

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PORT` | Application listening port | `4000` |
| `mongoDbUrl` | MongoDB connection string | `mongodb://<MONGO_IP>:27017/todolistDb` |
| `IMAGE_NAME` | Full ECR image URI | `890742564852.dkr.ecr.us-east-1.amazonaws.com/todo-list:latest` |

### Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `us-east-1` | AWS region for deployment |
| `instance_type` | `t2.micro` | EC2 instance type |

---

## Auto-Update Mechanism

The application implements a pull-based continuous deployment model using a custom cron job and shell script.

### Why This Approach?

Several alternatives were evaluated before choosing this solution:

| Solution | Status | Reason for Rejection |
|----------|--------|---------------------|
| **Watchtower** | ❌ Rejected | Project is **archived and no longer maintained** (deprecated). Using abandoned software in production is a security and reliability risk. |
| **Portainer + Webhooks** | ❌ Rejected | Webhook functionality is only available in **Portainer Business Edition** (paid plan). Not suitable for this project's requirements. |
| **Cron + Auto-Update Script** | ✅ Selected | Simple, reliable, zero-cost solution that meets all requirements for continuous deployment. |

### Solution Details

The chosen approach uses a lightweight cron-based polling mechanism:

1. **Cron Job**: Runs every minute on the app server
2. **Script Location**: `/usr/local/bin/auto-update.sh`
3. **Log File**: `/home/ubuntu/auto-update.log`

**Process:**
```bash
# Pull latest image from ECR
docker compose pull

# Recreate container if image changed
docker compose up -d

# Clean up unused resources
docker system prune -af --volumes
```

### Benefits of This Approach

| Benefit | Description |
|---------|-------------|
| **No External Dependencies** | No need for third-party tools or services |
| **Zero Cost** | Uses native Linux cron scheduler |
| **Full Control** | Complete visibility and customization of update logic |
| **Reliable** | Simple mechanism with minimal failure points |
| **Auditable** | All operations logged to `/home/ubuntu/auto-update.log` |
| **ECR Native** | Works directly with AWS ECR authentication via instance role |

This approach ensures:
- Zero-downtime deployments (Docker Compose handles container recreation gracefully)
- Automatic rollout of new versions within 1 minute of push
- No need for SSH access during deployments
- Automatic cleanup of unused Docker resources

---

## Security Considerations

### Implemented Security Measures

| Area | Implementation |
|------|----------------|
| **Network Isolation** | MongoDB only accessible from app server security group |
| **IAM Least Privilege** | CI/CD user has minimal ECR and EC2 permissions |
| **SSH Key Management** | Terraform-generated key with 0400 permissions |
| **ECR Image Scanning** | Automatic vulnerability scanning on push |
| **Environment Secrets** | `.env` file with 0600 permissions |

---
## Troubleshooting

### Common Issues

**SSH Connection Refused**
```bash
# Wait for instance initialization
sleep 60
# Verify security group allows port 22
aws ec2 describe-security-groups --group-names todo_web_sg
```

**ECR Authentication Failed**
```bash
# Re-authenticate to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ECR_REGISTRY>
```

**Application Not Starting**
```bash
# Check container logs
ssh -i terraform/tf-key.pem ubuntu@<EIP>
docker logs $(docker ps -aq | head -1)

# Check auto-update logs
cat /home/ubuntu/auto-update.log
```

**MongoDB Connection Issues**
```bash
# Verify MongoDB is running
ssh -i terraform/tf-key.pem ubuntu@<MONGO_IP>
sudo systemctl status mongod

# Check MongoDB binding
grep bindIp /etc/mongod.conf
```

### Useful Commands

```bash
# View Terraform state
terraform show

# Destroy infrastructure
terraform destroy

# Re-run Ansible playbook
ansible-playbook -i inventory.ini playbook.yml

# Manual container restart
docker compose down && docker compose up -d
```

---

## Outputs

After successful deployment, Terraform provides:

| Output | Description |
|--------|-------------|
| `public_ip` | Elastic IP of the application server |
| `mongo_private_ip` | Private IP of MongoDB server |
| `app_instance_id` | EC2 instance ID |
| `ecr_repository_url` | ECR repository URL |
| `cicd_access_key_id` | CI/CD IAM user access key |
| `cicd_secret_access_key` | CI/CD IAM user secret key (sensitive) |

---

## License

ISC

---

## Screenshots

This section provides visual evidence of the complete DevOps pipeline in action.

### Application Screenshots

#### Home Page
![Home Page](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/app-home.png?raw=true)

#### Dashboard - Task Management
![Dashboard](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Dashboard%20-%20Task%20Management.png?raw=true)

#### Task Creation
![Task Creation](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Task%20Creation.png?raw=true)

---

### Infrastructure Screenshots

#### Terraform Apply Output
![Terraform Apply](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Terraform%20Apply%20Output.png?raw=true)

#### AWS EC2 Instances
![EC2 Instances](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/AWS%20EC2%20Instances.png?raw=true)

#### AWS ECR Repository
![ECR Repository](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/AWS%20ECR%20Repository.png?raw=true)

#### AWS Security Groups
![Security Groups](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/AWS%20Security%20Groups%20app.png?raw=true)
![Security Groups](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/AWS%20Security%20Groups%20mongo.png?raw=true)

---

### Ansible Screenshots

#### Ansible Playbook Execution
![Ansible Playbook](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Ansible%20Playbook%20Execution.png?raw=true)

---

### CI/CD Pipeline Screenshots

#### GitHub Actions Workflow
![GitHub Actions Runs](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/GitHub%20Actions%20Workflow.png?raw=true)

#### Workflow Run Details
![Workflow Details](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Workflow%20Run%20Details1.png?raw=true)

![Workflow Details](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Workflow%20Run%20Details2.png?raw=true)

#### GitHub Secrets Configuration
![GitHub Secrets](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/GitHub%20Secrets%20Configuration.png?raw=true)

---

### Auto-Update Mechanism Screenshots
![Cron Job](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Cron%20Job%20Configuration.png?raw=true)

#### Auto-Update Logs
![Auto-Update Logs](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Auto-Update%20Logs.png?raw=true)

#### Docker Container Running
![Docker Container](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Docker%20Container%20Running.png?raw=true)

---

### End-to-End Deployment Proof

#### Full Deployment Script Output
![Full Deployment](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Full%20Deployment%20Script%20Output%201.png?raw=true)

![Full Deployment](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Full%20Deployment%20Script%20Output%202.png?raw=true)

![Full Deployment](https://github.com/Usf277/Todo-List-nodejs-devops/blob/master/images/part-2/Full%20Deployment%20Script%20Output%203.png?raw=true)


---

## Original Application

Based on the Todo List application by [@AnkitVishwakarma](https://github.com/Ankit6098)
