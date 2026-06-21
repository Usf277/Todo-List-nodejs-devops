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
- [Part 4: Monitoring & Logging Stack](#part-4-monitoring--logging-stack)
  - [Stack Overview](#stack-overview)
  - [What Gets Monitored](#what-gets-monitored)
  - [What Changed](#what-changed-1)
  - [Accessing the Tools](#accessing-the-tools)
  - [Cost Addition](#cost-addition)
- [Part 5: Production Challenges & Fixes](#part-5-production-challenges--fixes)
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
| **Monitoring** | Prometheus, Grafana, Alertmanager | Metrics collection, dashboards, and alerting (Part 4) |
| **Logging** | Loki, Promtail | Log aggregation and exploration (Part 4) |
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

## Part 4: Monitoring & Logging Stack

Adds full observability to the EKS cluster using two Helm chart installations deployed into a dedicated `monitoring` namespace.

---

### Stack Overview

| Tool | Helm Chart | Purpose |
|------|-----------|---------|
| **Prometheus** | `prometheus-community/kube-prometheus-stack` | Metrics collection and storage |
| **Grafana** | bundled with kube-prometheus-stack | Dashboards and visualization |
| **Alertmanager** | bundled with kube-prometheus-stack | Alert routing and grouping |
| **node-exporter** | bundled with kube-prometheus-stack | Node-level CPU/RAM/disk metrics |
| **kube-state-metrics** | bundled with kube-prometheus-stack | Kubernetes object state metrics |
| **Loki** | `grafana/loki-stack` | Log aggregation and storage |
| **Promtail** | bundled with loki-stack | Log collector DaemonSet |

Prometheus scrapes metrics using `ServiceMonitor` CRDs. Promtail runs as a DaemonSet on every node and ships all pod stdout/stderr to Loki. Both Prometheus and Loki are connected to Grafana as datasources.

---

### What Gets Monitored

| Signal | Source | Dashboard |
|--------|--------|-----------|
| Node CPU & RAM | node-exporter (DaemonSet) | k8s-pods (ID 6417) |
| Pod CPU & RAM | kube-state-metrics + cAdvisor | k8s-pods (ID 6417) |
| HTTP request rate, latency, error rate | NGINX Ingress `/metrics` via ServiceMonitor | nginx-ingress (ID 9614) |
| Node.js heap, event loop, GC, HTTP duration | `prom-client` on `/metrics` via ServiceMonitor | nodejs-app (ID 11159) |
| Container logs (all pods) | Promtail → Loki | loki-logs (ID 13639) |
| K8s alerts (pod crash loop, node not ready, etc.) | kube-prometheus-stack default rules → Alertmanager | built-in |

---

### What Changed

#### Application (`app/`)

| File | Change |
|------|--------|
| `app/package.json` | Added `prom-client: ^15.0.0` dependency |
| `app/index.js` | Added `collectDefaultMetrics()`, HTTP duration Histogram, request duration middleware, and `/metrics` endpoint |

#### Helm Chart (`helm/todo-app/`)

| File | Change |
|------|--------|
| `values.yaml` | Added `metrics.enabled: true` |
| `templates/servicemonitor.yaml` | **New** — tells Prometheus to scrape `/metrics` on the app pods every 30s |

#### Monitoring Values (`helm/monitoring/`)

| File | Purpose |
|------|---------|
| `values-prometheus-stack.yaml` | **New** — kube-prometheus-stack config: resource limits, 5Gi Prometheus storage, Loki datasource, 4 auto-provisioned dashboards, cross-namespace ServiceMonitor discovery |
| `values-loki.yaml` | **New** — Loki + Promtail config: 5Gi log storage, 7-day retention, Grafana disabled (already installed by kube-prometheus-stack) |

#### Scripts

| File | Change |
|------|--------|
| `provision_configure.sh` | Step 3: NGINX now deployed with `controller.metrics.enabled=true`; Step 5 (new): installs kube-prometheus-stack + loki-stack |
| `destroy_all.sh` | Tears down monitoring Helm releases and PVCs before app teardown |

#### CI/CD

| File | Change |
|------|--------|
| `.github/workflows/ci.yml` | NGINX ingress deploy step adds `controller.metrics.enabled=true` and `controller.metrics.serviceMonitor.enabled=true` |

---

### Accessing the Tools

```bash
# Grafana (dashboards)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# → http://localhost:3000  login: admin / admin

# Prometheus (metrics explorer + alert rules)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# → http://localhost:9090  then: Status → Targets (verify app is being scraped)

# Alertmanager (active alerts + silences)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# → http://localhost:9093

# Browse application logs
# Grafana → Explore → select Loki datasource
# → query: {namespace="default"}
```

Grafana is also exposed via the NGINX Ingress on `grafana.todo.example.com` (set in `values-prometheus-stack.yaml`). Update this host to your domain or remove the Ingress block and use port-forward only.

---

### Cost Addition

| New Resource | $/month |
|---|---|
| Prometheus EBS 5Gi | ~$0.50 |
| Loki EBS 5Gi | ~$0.50 |
| Grafana EBS 2Gi | ~$0.20 |
| **Total addition** | **~$1.20** |

Monitoring pods (Prometheus, Grafana, Loki, Promtail, Alertmanager, node-exporter, kube-state-metrics) run within the existing node group — a second t3.small node may spin up depending on available capacity, adding ~$15/month. Destroy with `./scripts/destroy_all.sh` to avoid charges when not in use.

---

## Part 5: Production Challenges & Fixes

This section documents every real failure encountered during the first live provisioning run of the EKS stack, the root cause of each, and the exact fix applied. These are not theoretical — every entry below blocked deployment until it was resolved.

---

### Challenge 1 — MongoDB PVC Stuck `Pending` Forever

**Symptom:** After `helm upgrade --install todo-app`, the MongoDB pod stayed `Pending` and `kubectl rollout status` hung indefinitely.

**Diagnosis:**
```bash
kubectl describe pod todo-app-mongodb-0 -n default
# Events: pod has unbound immediate PersistentVolumeClaims

kubectl get pvc -n default
# STATUS: Pending   STORAGECLASS: <unset>

kubectl get storageclass
# NAME   PROVISIONER             → kubernetes.io/aws-ebs  (old in-tree driver)
```

**Root cause:** EKS 1.23+ removed the in-tree `kubernetes.io/aws-ebs` EBS provisioner. The Terraform stack installed the EBS CSI addon (which uses `ebs.csi.aws.com`) but created no StorageClass for it. The Helm chart's `volumeClaimTemplate` had no `storageClassName`, so the PVC got no provisioner and stayed `Pending` forever.

**Fix:**
- Added Step 6 to `provision_configure.sh`: creates a `gp2-csi` StorageClass using `ebs.csi.aws.com` and marks it as the cluster default, before the Helm deploy.
- Added `storageClassName: gp2-csi` to `helm/todo-app/templates/mongodb-statefulset.yaml` and `values.yaml`.

**Files changed:** `scripts/provision_configure.sh`, `helm/todo-app/templates/mongodb-statefulset.yaml`, `helm/todo-app/values.yaml`

---

### Challenge 2 — MongoDB `CrashLoopBackOff` — Liveness Probe Killing the Container

**Symptom:** After the PVC bound and MongoDB started, the pod entered `CrashLoopBackOff`. The container repeatedly restarted every ~30 seconds with exit code 0.

**Diagnosis:**
```bash
kubectl describe pod todo-app-mongodb-0 -n default
# Warning  Unhealthy  Liveness probe failed: command "mongosh --eval ..." timed out
# Normal   Killing    Container mongodb failed liveness probe, will be restarted
```

Exit code 0 = Kubernetes sent `SIGTERM`. MongoDB was not crashing — it was being **murdered** by the liveness probe.

**Root cause:** The original probe had `initialDelaySeconds: 30` and `timeoutSeconds: 1` (the Kubernetes default). MongoDB 7.0 needs 60–90 seconds to initialize WiredTiger storage on a fresh EBS volume before it can respond to any command. Probing started too early and timed out in under 1 second, causing 3 consecutive failures and a kill.

**Fix:**
- Raised `initialDelaySeconds` from 30 to 90.
- Raised `failureThreshold` on the readiness probe from 3 to 6.
- Raised MongoDB memory limit from 256Mi to 512Mi (256Mi is too low for WiredTiger's initial cache allocation).

**Files changed:** `helm/todo-app/templates/mongodb-statefulset.yaml`, `helm/todo-app/values.yaml`

---

### Challenge 3 — MongoDB Probe Still Timing Out Even at 5s

**Symptom:** After raising `initialDelaySeconds` to 90 and adding `timeoutSeconds: 5`, MongoDB continued crashing. The event still read "command timed out."

**Diagnosis:**
```bash
# Verify the new spec is on the running pod
kubectl get statefulset todo-app-mongodb \
  -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'
# → timeoutSeconds: 5  ✓

# Manually run the exact probe command and time it
time kubectl exec todo-app-mongodb-0 -- mongosh --eval "db.adminCommand('ping')"
# → { ok: 1 }   real: 10.4s

# Check node CPU pressure
kubectl describe node | grep -A5 "Allocated resources"
# → cpu: 1700m limits (88% of 2 vCPU)
```

**Root cause:** The node's CPU was at 88% limits under the full monitoring stack (kube-prometheus-stack alone runs 8 pods). `mongosh` is a Node.js application — spawning a new Node.js process for every probe call competes for CPU. Under heavy throttling, even a simple `db.adminCommand('ping')` took 5–10 seconds. The `exec` probe design was fundamentally wrong for a resource-constrained single node.

**Fix:** Replaced both `exec` probes with `tcpSocket` probes on port 27017. A TCP socket probe is handled entirely inside the kubelet — no process fork, no Node.js startup, completes in microseconds. MongoDB only opens port 27017 after WiredTiger finishes initializing, making it a valid readiness signal. Lowered `initialDelaySeconds` from 90 to 60.

```yaml
readinessProbe:
  tcpSocket:
    port: 27017
  initialDelaySeconds: 20
  periodSeconds: 5
  failureThreshold: 6

livenessProbe:
  tcpSocket:
    port: 27017
  initialDelaySeconds: 60
  periodSeconds: 10
  failureThreshold: 3
```

**Files changed:** `helm/todo-app/templates/mongodb-statefulset.yaml`

---

### Challenge 4 — Loki Pod `Pending` — Node at Maximum Pod Capacity

**Symptom:** Loki `helm upgrade --install` timed out. `loki-0` pod was stuck `Pending`.

**Diagnosis:**
```bash
kubectl describe pod loki-0 -n monitoring
# Warning  FailedScheduling: 0/1 nodes are available: 1 Too many pods.

kubectl get pods -A --no-headers | wc -l
# 18

kubectl describe node | grep "pods:"
# Capacity: pods: 17
```

**Root cause:** A `t3.medium` node has a hard pod limit of 17, determined by the VPC CNI formula `(ENIs × IPs_per_ENI) − ENIs = (3×6)−3 = 15 secondary IPs + 2 = 17 max`. The full stack consumed all 17 slots: kube-system (6 pods) + kube-prometheus-stack (8 pods) + NGINX + app + MongoDB = 17. Loki was pod 18.

**Fix:** Changed `desired_size` from 1 to 2 in `terraform/eks.tf` (the node group already had `max_size = 2`). Applied with `terraform apply -target=aws_eks_node_group.main`. The second node joined within 90 seconds and Loki scheduled immediately.

**Files changed:** `terraform/eks.tf`

---

### Challenge 5 — App Returns 404 Not Found (NGINX)

**Symptom:** All pods running, NLB provisioned, but accessing the ELB URL in a browser returned `404 Not Found nginx`.

**Diagnosis:**
```bash
kubectl get ingress -n default -o yaml | grep -A5 "rules:"
# rules:
#   - host: todo.example.com    ← virtual host filter active

# Test with correct Host header
curl -H "Host: todo.example.com" http://<ELB_HOST>
# → 200  ✓

# Test without (what the browser sends)
curl http://<ELB_HOST>
# → 404  ✗
```

**Root cause:** The Ingress had `host: todo.example.com`. NGINX uses this as a virtual host filter — it only routes requests where the HTTP `Host` header exactly matches. Browsers accessing the raw ELB hostname send `Host: <elb-hostname>`, which matches no Ingress rule, so NGINX returns 404.

**Fix:** Made the `host` field optional in `helm/todo-app/templates/ingress.yaml`. When `host` is empty, NGINX creates a catch-all rule that accepts any `Host` header. Set `host: ""` in `values.yaml` as the default. Set `host: your-domain.com` when real DNS is configured.

**Files changed:** `helm/todo-app/templates/ingress.yaml`, `helm/todo-app/values.yaml`

---

### Challenge 6 — EBS CSI Driver Addon Timeout During Terraform Apply

**Symptom:** `terraform apply` hung for 15+ minutes and eventually timed out at `aws_eks_addon.ebs_csi`.

**Root cause:** The initial implementation attached the EBS CSI policy to the node IAM role (node-level permissions). The EBS CSI addon expects to authenticate via IRSA (IAM Roles for Service Accounts) using the cluster's OIDC provider. Without a dedicated service account role, the addon waited indefinitely for credentials that never arrived.

**Fix:** Implemented full IRSA:
1. Added `terraform/irsa.tf` — creates OIDC provider + dedicated `todo-list-ebs-csi-role` IAM role with a trust policy scoped to the `ebs-csi-controller-sa` service account.
2. Attached `AmazonEBSCSIDriverPolicy` to the IRSA role (removed from node role).
3. Updated `aws_eks_addon.ebs_csi` to reference `service_account_role_arn`.

**Files changed:** `terraform/irsa.tf` (new), `terraform/eks.tf`, `terraform/iam_eks.tf`

---

### Challenge 7 — NGINX Ingress Failed: `ServiceMonitor` CRD Not Found

**Symptom:** During early provisioning runs, `helm upgrade --install nginx-ingress` with `--set controller.metrics.serviceMonitor.enabled=true` failed because the `ServiceMonitor` CRD did not exist yet.

**Root cause:** The provision script was installing NGINX before `kube-prometheus-stack`. `ServiceMonitor` is a CRD installed by the Prometheus Operator (part of kube-prometheus-stack). Trying to create a `ServiceMonitor` resource before its CRD exists causes a hard error.

**Fix:** Reordered the provision script steps:
1. Install `kube-prometheus-stack` first (Prometheus Operator + all CRDs)
2. Wait for the operator deployment to be ready (`kubectl rollout status`)
3. Only then install NGINX Ingress (CRD now exists, `serviceMonitor.enabled=true` is safe)

**Files changed:** `scripts/provision_configure.sh`

---

### Challenge 8 — Provision Script: NLB Hostname Not Available at Script End

**Symptom:** The provision script printed `<still provisioning>` for the app URL every run, because `sleep 15` was not enough time for AWS to provision the NLB.

**Root cause:** AWS Network Load Balancers take 1–3 minutes to provision after the NGINX Ingress Service is created. A static 15-second sleep is never sufficient.

**Fix:** Replaced `sleep 15` with a poll loop that retries every 10 seconds for up to 3 minutes:
```bash
for i in $(seq 1 18); do
  LB_HOST=$(kubectl get svc -n ingress-nginx ... -o jsonpath='{...hostname}')
  [ -n "$LB_HOST" ] && break
  sleep 10
done
```

**Files changed:** `scripts/provision_configure.sh`

---

### Challenge 9 — Destroy Script: Helm Uninstall Hanging Indefinitely

**Symptom:** `./scripts/destroy_all.sh` hung at `helm uninstall kube-prometheus-stack --wait` and never progressed to `terraform destroy`.

**Root cause:** `kube-prometheus-stack` installs admission webhooks. If the webhook pods are partially degraded at destroy time, `helm uninstall --wait` waits for webhook cleanup that never completes. With no timeout, the script blocks forever.

**Fix:**
- Added `--no-hooks` to the kube-prometheus-stack uninstall (skips webhook teardown entirely).
- Added explicit `--timeout` to all `helm uninstall --wait` calls.
- Added `--timeout` to `kubectl delete pvc` and `kubectl delete namespace` commands for the same reason.

**Files changed:** `scripts/destroy_all.sh`

---

### Summary of All Fixes

| # | What broke | Root cause | Fix | Files |
|---|---|---|---|---|
| 1 | MongoDB PVC `Pending` | No StorageClass for EBS CSI driver | Create `gp2-csi` StorageClass in provision script | `provision_configure.sh`, `mongodb-statefulset.yaml`, `values.yaml` |
| 2 | MongoDB `CrashLoopBackOff` | Liveness `initialDelaySeconds: 30` — too short for WiredTiger init | Raised to 90s, memory limit to 512Mi | `mongodb-statefulset.yaml`, `values.yaml` |
| 3 | Probe still timing out | `mongosh` (Node.js) too slow to spawn under 88% CPU | Switched to `tcpSocket` probe — zero cost | `mongodb-statefulset.yaml` |
| 4 | Loki `Pending` | Single t3.medium node at 17-pod hard limit | Scaled `desired_size` to 2 | `terraform/eks.tf` |
| 5 | App 404 from NGINX | Ingress `host` filter — ELB hostname didn't match | Made `host` optional (catch-all when empty) | `ingress.yaml`, `values.yaml` |
| 6 | EBS CSI addon timeout | Node-role auth instead of IRSA | Implemented IRSA with OIDC provider | `irsa.tf`, `eks.tf`, `iam_eks.tf` |
| 7 | NGINX install failed | `ServiceMonitor` CRD missing (kube-prometheus-stack not yet installed) | Install kube-prometheus-stack first, then NGINX | `provision_configure.sh` |
| 8 | No app URL at script end | `sleep 15` too short for NLB provisioning (takes 1–3 min) | Replaced with 3-minute poll loop | `provision_configure.sh` |
| 9 | Destroy script hung | `helm uninstall --wait` blocked by admission webhooks | Added `--no-hooks` and `--timeout` to all uninstalls | `destroy_all.sh` |

---

## Original Application

Based on the Todo List application by [@AnkitVishwakarma](https://github.com/Ankit6098)
