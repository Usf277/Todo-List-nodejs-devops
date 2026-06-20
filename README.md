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
  - [Remote State Management](#remote-state-management)
  - [Ansible Configuration](#ansible-configuration)
  - [CI/CD Pipeline](#cicd-pipeline)
- [Deployment Workflow](#deployment-workflow)
- [Configuration](#configuration)
- [Auto-Update Mechanism](#auto-update-mechanism)
- [Security Considerations](#security-considerations)
- [Part 3: Migration to Kubernetes (EKS + Helm)](#part-3-migration-to-kubernetes-eks--helm)
  - [Architecture — EKS + Helm](#architecture--eks--helm)
  - [What Changed](#what-changed)
  - [Helm Chart](#helm-chart)
  - [CI/CD Pipeline Updates](#cicd-pipeline-updates)
  - [Deployment](#deployment)
  - [Destroy Everything](#destroy-everything)
  - [Cost](#cost-approximate-us-east-1)
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

### Updated Architecture — Custom VPC with Subnet Isolation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GitHub Repository                                 │
│                                   │                                         │
│                          Push to main/master                                │
│                                   ▼                                         │
│                    ┌──────────────────────────┐                             │
│                    │      GitHub Actions       │                            │
│                    │  1. Build Docker image    │                            │
│                    │  2. Smoke test (HTTP 4000)│                            │
│                    │  3. Push to ECR           │                            │
│                    └────────────┬─────────────┘                             │
│                                 │                                           │
│  ┌──────────────────────────────▼──────────────────────────────────────┐    │
│  │                      AWS Cloud (us-east-1)                          │    │
│  │                                                                     │    │
│  │   ┌─────────────┐   Build & Push                                    │    │
│  │   │  S3 Bucket  │◄──────────────── Terraform Remote State           │    │
│  │   │  (tfstate)  │   DynamoDB Lock                                   │    │
│  │   └─────────────┘                                                   │    │
│  │                                                                     │    │
│  │   ┌─────────────┐                                                   │    │
│  │   │     ECR     │◄── CI pushes image                                │    │
│  │   │  Registry   │                                                   │    │
│  │   └──────┬──────┘                                                   │    │
│  │          │                                                          │    │
│  │   ┌──────▼──────────────────────────────────────────────────────┐   │    │
│  │   │              Custom VPC  (10.0.0.0/16)                      │   │    │
│  │   │                                                             │   │    │
│  │   │  ┌──────────────────────────────────────────────────────┐   │   │    │
│  │   │  │           Public Subnet  (10.0.1.0/24)               │   │   │    │
│  │   │  │                                                      │   │   │    │
│  │   │  │  ┌─────────────────────┐  ┌──────────────────────┐   │   │   │    │
│  │   │  │  │  App Server (EC2)   │  │  MongoDB Server (EC2)│   │   │   │    │
│  │   │  │  │  ┌───────────────┐  │  │  ┌────────────────┐  │   │   │   │    │
│  │   │  │  │  │Docker :4000   │──┼──┼─►│  MongoDB :27017│  │   │   │   │    │
│  │   │  │  │  └───────────────┘  │  │  └────────────────┘  │   │   │   │    │
│  │   │  │  │  Elastic IP         │  │  SG: 27017 from      │   │   │   │    │
│  │   │  │  │  SG: 22,80,4000     │  │  web_sg only         │   │   │   │    │
│  │   │  │  └─────────────────────┘  └──────────────────────┘   │   │   │    │
│  │   │  └──────────────────────────────────────────────────────┘   │   │    │
│  │   │                                                             │   │    │
│  │   │  ┌──────────────────────────────────────────────────────┐   │   │    │
│  │   │  │  Private Subnet (10.0.2.0/24) — NAT Gateway target   │   │   │    │
│  │   │  │  MongoDB moves here once a NAT Gateway is added      │   │   │    │
│  │   │  └──────────────────────────────────────────────────────┘   │   │    │
│  │   └─────────────────────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Technology Stack

| Category | Technology | Purpose |
|----------|------------|---------|
| **Application** | Node.js 18, Express.js, EJS | Web application runtime and templating |
| **Database** | MongoDB 7.0, Mongoose | Data persistence |
| **Containerization** | Docker, Docker Compose | Application packaging and local dev |
| **Container Orchestration** | Kubernetes (EKS 1.30) | Production container management (Part 3) |
| **Package Management (K8s)** | Helm 3 | Kubernetes application packaging and deployment (Part 3) |
| **Ingress** | NGINX Ingress Controller | External HTTP routing into the K8s cluster (Part 3) |
| **Infrastructure** | Terraform | AWS resource provisioning |
| **Configuration** | Ansible | Server configuration management (Parts 1 & 2) |
| **CI/CD** | GitHub Actions | Automated build, test, and deployment |
| **Cloud Provider** | AWS (EKS, ECR, VPC, IAM, S3, DynamoDB, EBS, NLB) | Cloud infrastructure |
| **OS** | Ubuntu 22.04 LTS | Worker node operating system |

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
├── ansible/                      # Ansible configuration (Parts 1 & 2)
│   ├── inventory.ini.example     # Inventory template
│   └── playbook.yml              # Server configuration playbook
├── compose/                      # Docker Compose (local dev / Parts 1 & 2)
│   └── docker-compose.yml        # Application orchestration
├── docker/                       # Docker configuration
│   └── Dockerfile                # Application container definition
├── helm/                         # Helm chart — Kubernetes deployment (Part 3)
│   └── todo-app/                 # Chart for Todo App + MongoDB
│       ├── Chart.yaml            # Chart metadata (name, version)
│       ├── values.yaml           # Default configuration values
│       └── templates/            # Kubernetes manifest templates
│           ├── _helpers.tpl      # Shared template helper functions
│           ├── configmap.yaml    # Non-sensitive config (PORT, NODE_ENV)
│           ├── secret.yaml       # Sensitive config (mongoDbUrl)
│           ├── deployment.yaml   # App pod specification
│           ├── service.yaml      # Internal ClusterIP service for app
│           ├── ingress.yaml      # NGINX ingress routing rule
│           ├── mongodb-statefulset.yaml  # MongoDB with persistent EBS volume
│           └── mongodb-service.yaml      # Internal ClusterIP for MongoDB
├── scripts/                      # Automation scripts
│   ├── auto-update.sh            # EC2 cron auto-update (Parts 1 & 2)
│   ├── provision_configure.sh    # One-command EKS deployment (updated Part 3)
│   └── destroy_all.sh            # Nuclear destroy — removes all AWS resources
├── terraform/                    # Infrastructure as Code
│   ├── bootstrap/                # One-time state backend setup
│   │   └── main.tf               # S3 bucket + DynamoDB lock table
│   ├── backend.tf                # S3 remote state configuration
│   ├── vpc.tf                    # VPC, 2-AZ subnets, IGW, route tables
│   ├── main.tf                   # AWS provider declaration
│   ├── eks.tf                    # EKS cluster, node group, access entries (Part 3)
│   ├── iam_eks.tf                # IAM roles for EKS cluster and nodes (Part 3)
│   ├── ecr.tf                    # ECR repository
│   ├── iam_cicd.tf               # CI/CD IAM user and policies
│   ├── variables.tf              # Input variables
│   └── outputs.tf                # Output values
├── .github/workflows/            # GitHub Actions
│   └── ci.yml                    # CI/CD pipeline (build + deploy jobs)
├── .env.example                  # Environment variables template
└── .dockerignore                 # Docker build exclusions
```

---

## Prerequisites

Before deploying this project, ensure you have the following installed and configured:

| Tool | Version | Purpose |
|------|---------|---------|
| AWS CLI | 2.x | AWS authentication and resource management |
| Terraform | 1.5+ | Infrastructure provisioning |
| Ansible | 2.9+ | Configuration management (Parts 1 & 2 only) |
| Docker | 20.10+ | Local container testing |
| kubectl | 1.29+ | Kubernetes cluster management (Part 3) |
| Helm | 3.14+ | Kubernetes package deployment (Part 3) |
| Git | 2.x | Version control |

### AWS Requirements

- AWS account with appropriate permissions
- AWS CLI configured with credentials (`aws configure`)
- Permissions for: EKS, EC2, ECR, IAM, VPC, S3, DynamoDB

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

1. Bootstrap the S3 remote state backend and DynamoDB lock table
2. Provision all AWS infrastructure with Terraform (stored in S3)
3. Generate the `.env` configuration file
4. Create the Ansible inventory
5. Configure the EC2 instance with Docker
6. Deploy the application container
7. Output the CI/CD credentials for GitHub Secrets

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
| `aws_security_group` | `web_sg` | App server firewall (ports 22, 80, 4000) — VPC-scoped |
| `aws_security_group` | `mongo_sg` | MongoDB firewall (port 27017 from web_sg only) — VPC-scoped |
| `aws_iam_role` | `ec2_role` | EC2 instance role for ECR access |
| `aws_iam_user` | `cicd_user` | CI/CD pipeline IAM user |
| `aws_key_pair` | `kp` | SSH key pair for EC2 access |
| `aws_vpc` | `main` | Custom VPC (10.0.0.0/16) replacing the default VPC |
| `aws_subnet` | `public` | Public subnet (10.0.1.0/24) for app and MongoDB servers |
| `aws_subnet` | `private` | Private subnet (10.0.2.0/24) reserved for MongoDB with NAT Gateway |
| `aws_internet_gateway` | `igw` | Internet gateway attached to the VPC |
| `aws_route_table` | `public` | Route table sending 0.0.0.0/0 traffic through the IGW |

### Remote State Management

Terraform state is stored remotely in S3 with DynamoDB locking instead of a local `terraform.tfstate` file. This prevents state corruption from concurrent applies and keeps secrets (IAM keys, IPs) out of the git repository.

**Bootstrap (run once before first `terraform apply`):**

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

This creates:

- `aws_s3_bucket` — `todo-list-tfstate-890742564852` with versioning and AES-256 encryption enabled, all public access blocked
- `aws_dynamodb_table` — `todo-list-tfstate-lock` with a `LockID` hash key (pay-per-request billing)

**Migrating from local state (existing projects only):**

```bash
cd terraform
terraform init -migrate-state
```

This copies the local `terraform.tfstate` into S3 and removes the local file.

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
5. **Smoke test** — run the built image, wait 8 seconds, then hit `GET /` and assert an HTTP response is returned. Fails the pipeline before the push if the container crashes on startup or the server never binds to port 4000.
6. Push image to ECR with both SHA tag and `latest` tag (only reached if smoke test passes)

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
| **Custom VPC** | All resources isolated inside a dedicated VPC (10.0.0.0/16) instead of the shared default VPC |
| **Network Isolation** | MongoDB security group only allows port 27017 from the app server's security group — no public MongoDB exposure |
| **Subnet Separation** | Public subnet for the app server; private subnet defined and ready for MongoDB once a NAT Gateway is added |
| **Remote State Security** | Terraform state in S3 with AES-256 encryption, versioning, and all public access blocked — secrets never stored in git |
| **IAM Least Privilege** | CI/CD user has minimal ECR and EC2 permissions |
| **SSH Key Management** | Terraform-generated RSA-4096 key with 0400 permissions |
| **ECR Image Scanning** | Automatic vulnerability scanning on every push |
| **Environment Secrets** | `.env` file with 0600 permissions, git-ignored |
| **CI Smoke Test** | Broken images are rejected before being pushed to ECR |

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

## Part 3: Migration to Kubernetes (EKS + Helm)

This section documents the migration from the EC2 + Docker Compose architecture (Parts 1 & 2) to a Kubernetes-based deployment on AWS EKS using Helm. MongoDB moves from a standalone EC2 instance into a StatefulSet inside the cluster, the NGINX Ingress Controller replaces direct port exposure, and Helm packages all Kubernetes manifests into a single versioned chart.

---

### Architecture — EKS + Helm

```
                         GitHub Repository
                                │
                       Push to main/master
                                │
              ┌─────────────────▼─────────────────┐
              │         GitHub Actions            │
              │  Job 1: build                     │
              │    - docker build + push to ECR   │
              │    - smoke test                   │
              │  Job 2: deploy (master only)      │
              │    - helm upgrade nginx-ingress   │
              │    - helm upgrade todo-app        │
              └─────────────────┬─────────────────┘
                                │
  ┌─────────────────────────────▼──────────────────────────────────┐
  │                    AWS Cloud (us-east-1)                       │
  │                                                                │
  │  ┌────────────┐  ┌──────────────────────────────────────────┐  │
  │  │ S3 + DDB   │  │  ECR Registry  (todo-list)               │  │
  │  │ (tfstate)  │  │  ← CI pushes image on every merge        │  │
  │  └────────────┘  └─────────────────┬────────────────────────┘  │
  │                                    │ pull (node IAM role)      │
  │  ┌─────────────────────────────────▼──────────────────────┐    │
  │  │           Custom VPC  (10.0.0.0/16)                    │    │
  │  │                                                        │    │
  │  │  ┌─────────────────────────────────────────────────┐   │    │
  │  │  │  EKS Cluster: todo-list-eks  (v1.30)            │   │    │
  │  │  │                                                 │   │    │
  │  │  │  Node Group: 1–2 × t3.small                     │   │    │
  │  │  │  AZ-a: 10.0.1.0/24   AZ-b: 10.0.2.0/24          │   │    │
  │  │  │                                                 │   │    │
  │  │  │  ┌──────────────────────────────────────────┐   │   │    │
  │  │  │  │  nginx-ingress pod ──► AWS NLB (public)  │   │   │    │
  │  │  │  └────────────────┬─────────────────────────┘   │   │    │
  │  │  │                   │ routes /                    │   │    │
  │  │  │  ┌────────────────▼──────┐  ┌─────────────────┐ │   │    │
  │  │  │  │  Deployment           │  │  StatefulSet    │ │   │    │
  │  │  │  │  app pod  :4000       ├─►│  mongodb :27017 │ │   │    │
  │  │  │  │  ConfigMap + Secret   │  │  + EBS PVC 1Gi  │ │   │    │
  │  │  │  └───────────────────────┘  └─────────────────┘ │   │    │
  │  │  └─────────────────────────────────────────────────┘   │    │
  │  └────────────────────────────────────────────────────────┘    │
  └────────────────────────────────────────────────────────────────┘
```

---

### What Changed

#### Infrastructure (Terraform)

| File | Change | Reason |
|------|--------|--------|
| `main.tf` | Rewritten — provider only | EC2 instances, key pair, and security groups removed |
| `vpc.tf` | Added `public_b` subnet (AZ-b) + EKS subnet tags | EKS control plane requires subnets in ≥ 2 AZs; subnet tags required for load balancer provisioning |
| `eks.tf` | **New** — EKS cluster, managed node group, CI/CD access entries | Core cluster definition; access entries grant CI/CD user cluster-admin via EKS API auth |
| `iam_eks.tf` | **New** — EKS cluster role + node role | EKS control plane needs its own IAM role; nodes need roles to join cluster and pull from ECR |
| `iam_cicd.tf` | Added `eks:DescribeCluster` permission | Required by `aws eks update-kubeconfig` in the CI/CD pipeline |
| `variables.tf` | Added `cluster_name`, `node_instance_type` | Parameterise new EKS resources |
| `outputs.tf` | Replaced EC2 outputs with EKS outputs | `public_ip`/`mongo_private_ip`/`app_instance_id` no longer exist |
| `mongo.tf` | **Deleted** | MongoDB runs as a StatefulSet in the cluster; dedicated EC2 instance removed |

#### Deployment Tooling

| Tool | Before | After |
|------|--------|-------|
| Application runtime | EC2 + Docker (via Ansible) | EKS managed node group |
| MongoDB | Dedicated EC2 with `mongod` | StatefulSet pod + EBS-backed PVC |
| Configuration | `.env` file (copied by Ansible) | Kubernetes ConfigMap + Secret |
| External routing | Port 4000 exposed directly on EC2 EIP | NGINX Ingress → AWS NLB |
| Deployment trigger | Cron job polling ECR every minute | `helm upgrade` in CI/CD pipeline |
| Rollback | SSH in and `docker pull` a previous tag | `helm rollback todo-app` |

#### `provision_configure.sh`

Rewritten to reflect the new workflow. Steps are now:

1. Bootstrap S3 + DynamoDB state backend
2. `terraform apply` — provisions EKS cluster, VPC, IAM, ECR
3. `aws eks update-kubeconfig` — points `kubectl` at the new cluster
4. `helm upgrade --install nginx-ingress` — installs NGINX Ingress Controller
5. `helm upgrade --install todo-app` — deploys the application
6. Prints GitHub Secrets (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`)

---

### Helm Chart

The chart at `helm/todo-app/` packages the full application stack.

```
helm/todo-app/
├── Chart.yaml                   # Chart name and version
├── values.yaml                  # Default configuration (image, resources, ingress host)
└── templates/
    ├── _helpers.tpl             # Shared name/label helpers
    ├── configmap.yaml           # PORT, NODE_ENV → env vars in app pod
    ├── secret.yaml              # mongoDbUrl → env var in app pod
    ├── deployment.yaml          # Node.js app (Deployment, 1 replica)
    ├── service.yaml             # ClusterIP on port 80 → pod port 4000
    ├── ingress.yaml             # NGINX ingress rule (host-based routing)
    ├── mongodb-statefulset.yaml # MongoDB 7.0 with volumeClaimTemplates
    └── mongodb-service.yaml     # ClusterIP on port 27017
```

Key `values.yaml` parameters:

| Key | Default | Override with |
|-----|---------|---------------|
| `app.image.tag` | `latest` | `--set app.image.tag=<sha>` (CI sets this automatically) |
| `ingress.host` | `todo.example.com` | `--set ingress.host=<your-domain>` |
| `secrets.mongoDbUrl` | `mongodb://todo-app-mongodb:27017/todolist` | `--set secrets.mongoDbUrl=<uri>` for external MongoDB |
| `mongodb.storage` | `1Gi` | `--set mongodb.storage=5Gi` |

---

### CI/CD Pipeline Updates

The pipeline now has two jobs:

**Job 1 — `build`** (runs on all pushes and PRs):

1. Build Docker image
2. Push to ECR (SHA tag + `latest`)
3. Smoke test (container starts and responds on port 4000)

**Job 2 — `deploy`** (runs on `master`/`main` merge only, after `build` succeeds):

1. `aws eks update-kubeconfig`
2. `helm upgrade --install nginx-ingress` (idempotent — installs on first run, no-ops if unchanged)
3. `helm upgrade --install todo-app --set app.image.tag=<sha>`

---

### Deployment

#### One-command

```bash
./scripts/provision_configure.sh
```

#### Manual

```bash
# 1. Bootstrap state backend (one-time)
cd terraform/bootstrap && terraform init && terraform apply

# 2. Provision EKS (~15 min)
cd ../.. && cd terraform && terraform init && terraform apply

# 3. Connect kubectl
aws eks update-kubeconfig --region us-east-1 --name todo-list-eks

# 4. Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace --wait

# 5. Deploy app
helm upgrade --install todo-app ./helm/todo-app --wait

# 6. Get external URL (wait ~2 min for NLB to provision)
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller
```

#### Terraform Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | EKS API server URL |
| `kubeconfig_command` | Exact `aws eks update-kubeconfig` command |
| `ecr_repository_url` | ECR repository URL |
| `cicd_access_key_id` | CI/CD IAM access key |
| `cicd_secret_access_key` | CI/CD IAM secret key *(sensitive)* |

---

### Destroy Everything

```bash
./scripts/destroy_all.sh
# Type "destroy" when prompted
```

Execution order:

1. `helm uninstall todo-app` — removes app pods and PVCs (releases EBS volumes)
2. `helm uninstall nginx-ingress` — removes the AWS Network Load Balancer
3. 60-second wait — allows AWS to fully deprovision the NLB before VPC deletion
4. `terraform destroy` — removes EKS cluster, VPC, ECR, IAM

> The S3 state bucket and DynamoDB lock table are **not** destroyed automatically. Destroy them manually in `terraform/bootstrap` only after everything else is gone.

---

### Cost (approximate, us-east-1)

| Resource | $/month |
|----------|---------|
| EKS Control Plane | ~$73 |
| 1× t3.small worker node | ~$15 |
| Network Load Balancer | ~$16 |
| EBS gp2 1Gi (MongoDB) | ~$0.10 |
| ECR + S3 + DynamoDB | ~$0.20 |
| **Total** | **~$104** |

Run `./scripts/destroy_all.sh` when the cluster is not in use to avoid ongoing charges.

---

## Original Application

Based on the Todo List application by [@AnkitVishwakarma](https://github.com/Ankit6098)
