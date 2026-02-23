# 🚀 DevOps Demo — AWS Deployment with IaC, Docker & CI/CD

A production-grade deployment of a Python Flask web application on AWS, automated end-to-end using Terraform, Docker, and GitHub Actions.

---

## 📐 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Developer Laptop                        │
│                                                                 │
│   git push ──────────────────────────────────────────────────► │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub                                   │
│                                                                 │
│  ┌──────────────────┐    ┌──────────────────────────────────┐  │
│  │   Source Repo    │    │     GitHub Actions CI/CD         │  │
│  │                  │───►│  1. Build Docker image           │  │
│  │  app/            │    │  2. Push to GHCR                 │  │
│  │  terraform/      │    │  3. SSH deploy to EC2            │  │
│  │  .github/        │    │  4. Health check verify          │  │
│  └──────────────────┘    └────────────────┬─────────────────┘  │
│                                           │                     │
│  ┌───────────────────────┐               │                     │
│  │  GitHub Container     │◄──────────────┘                     │
│  │  Registry (GHCR)      │                                     │
│  │  ghcr.io/user/repo    │──────────────────────────────────►  │
│  └───────────────────────┘                                     │
└─────────────────────────────────────────────────────────────────┘
                                 │ docker pull
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                      AWS Cloud (us-east-1)                      │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   VPC  10.0.0.0/16                        │  │
│  │                                                           │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │           Public Subnet  10.0.1.0/24                │  │  │
│  │  │                                                     │  │  │
│  │  │  ┌──────────────────────────────────────────────┐   │  │  │
│  │  │  │   EC2 Instance (t3.micro)                    │   │  │  │
│  │  │  │   Amazon Linux 2023                          │   │  │  │
│  │  │  │                                              │   │  │  │
│  │  │  │   ┌──────────────────────────────────────┐   │   │  │  │
│  │  │  │   │  Docker Container                    │   │   │  │  │
│  │  │  │   │  Flask App (port 5000)               │   │   │  │  │
│  │  │  │   │  GET /         → app info            │   │   │  │  │
│  │  │  │   │  GET /health   → health status       │   │   │  │  │
│  │  │  │   └──────────────────────────────────────┘   │   │  │  │
│  │  │  │                                              │   │  │  │
│  │  │  │   CloudWatch Agent → /devops-demo/app        │   │  │  │
│  │  │  └──────────────────────────────────────────────┘   │  │  │
│  │  │                          │                           │  │  │
│  │  │         Security Group   │ allows:                   │  │  │
│  │  │         ┌────────────────┴────────────────┐          │  │  │
│  │  │         │ :22  SSH (your IP only)         │          │  │  │
│  │  │         │ :80  HTTP  (0.0.0.0/0)          │          │  │  │
│  │  │         │ :5000 App  (0.0.0.0/0)          │          │  │  │
│  │  │         └─────────────────────────────────┘          │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────┐   ┌──────────────────┐   ┌───────────────┐   │
│  │ Internet     │   │  Elastic IP      │   │  CloudWatch   │   │
│  │ Gateway      │   │  (static IP)     │   │  Log Groups   │   │
│  └──────────────┘   └──────────────────┘   └───────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                                 ▲
                                 │ HTTP :5000
┌────────────────────────────────┴────────────────────────────────┐
│                        End Users                                │
└─────────────────────────────────────────────────────────────────┘
```

### CI/CD Flow

```
git push main
     │
     ▼
[GitHub Actions Trigger]
     │
     ├─► Job 1: Build
     │       ├── Checkout code
     │       ├── docker buildx build ./app
     │       └── Push to ghcr.io (tagged sha + latest)
     │
     └─► Job 2: Deploy (after Build succeeds)
             ├── SSH into EC2 (key from GitHub Secrets)
             ├── docker pull ghcr.io/.../image:latest
             ├── docker stop old container
             ├── docker run new container
             └── curl /health → verify deployment ✅
```

---

## 🗂️ Repository Structure

```
.
├── app/
│   ├── app.py              # Flask application
│   ├── requirements.txt    # Python dependencies
│   └── Dockerfile          # Multi-stage Docker build
├── terraform/
│   ├── main.tf             # VPC, subnet, EC2, security group
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # IP, URL outputs
│   └── user_data.sh        # EC2 bootstrap script
├── .github/
│   └── workflows/
│       └── deploy.yml      # GitHub Actions CI/CD
├── .gitignore
└── README.md
```

---

## 🛠️ Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.5 | Infrastructure provisioning |
| AWS CLI | >= 2.x | AWS authentication |
| Docker | >= 24.x | Local build testing |
| Git | any | Version control |

You need:
- An AWS account with programmatic access (IAM user or role)
- A GitHub account (for GHCR and Actions)
- An SSH key pair (generate below)

---

## 🚀 Step-by-Step Deployment Guide

### Step 1 — Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/devops-demo.git
cd devops-demo
```

### Step 2 — Generate SSH Key Pair

```bash
# Generate an ED25519 key pair
ssh-keygen -t ed25519 -C "devops-demo-deploy" -f ~/.ssh/devops-demo

# View the public key (you'll need this for Terraform)
cat ~/.ssh/devops-demo.pub

# Keep the private key safe — you'll add it as a GitHub Secret
cat ~/.ssh/devops-demo
```

### Step 3 — Configure AWS Credentials

```bash
# Option A: Environment variables (recommended for CI)
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"

# Option B: AWS CLI profile
aws configure --profile devops-demo
export AWS_PROFILE=devops-demo

# Verify
aws sts get-caller-identity
```

### Step 4 — Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform (downloads providers)
terraform init

# Set your SSH public key (never hardcode in files!)
export TF_VAR_ssh_public_key="$(cat ~/.ssh/devops-demo.pub)"

# Optional: restrict SSH to your IP only (recommended!)
export TF_VAR_ssh_allowed_cidr="$(curl -s ifconfig.me)/32"

# Review what will be created
terraform plan

# Apply (type 'yes' when prompted)
terraform apply

# Save the outputs!
terraform output
# Example output:
#   instance_public_ip = "3.85.xxx.xxx"
#   app_url            = "http://3.85.xxx.xxx:5000"
#   health_url         = "http://3.85.xxx.xxx:5000/health"
#   ssh_command        = "ssh -i ~/.ssh/devops-demo ec2-user@3.85.xxx.xxx"
```

⏱️ Terraform apply takes ~2 minutes. The EC2 bootstrap (Docker install) takes another ~3 minutes after the instance starts.

### Step 5 — Configure GitHub Secrets

Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Value | How to get it |
|---|---|---|
| `EC2_HOST` | `3.85.xxx.xxx` | `terraform output instance_public_ip` |
| `EC2_SSH_PRIVATE_KEY` | (full private key contents) | `cat ~/.ssh/devops-demo` |
| `GHCR_READ_TOKEN` | GitHub PAT with `read:packages` | GitHub → Settings → Developer settings → PATs |

> 💡 The `GITHUB_TOKEN` secret is automatically available in GitHub Actions — no setup needed for building and pushing images.

### Step 6 — Create a GitHub Environment (Optional but Recommended)

Go to **Settings** → **Environments** → **New environment** → Name it `production`.

This adds a deployment approval gate before production deploys.

### Step 7 — Trigger the CI/CD Pipeline

```bash
# Make any change and push to main
echo "# Trigger deploy" >> README.md
git add .
git commit -m "feat: initial deployment"
git push origin main
```

Then watch the pipeline at: `https://github.com/YOUR_USERNAME/devops-demo/actions`

The pipeline will:
1. ✅ Build the Docker image (~2 min)
2. ✅ Push to GitHub Container Registry
3. ✅ SSH into EC2 and pull the new image
4. ✅ Replace the running container with zero-downtime swap
5. ✅ Verify `/health` endpoint responds

### Step 8 — Verify the Deployment

```bash
EC2_IP=$(cd terraform && terraform output -raw instance_public_ip)

# Check health endpoint
curl http://$EC2_IP:5000/health
# → {"status": "healthy", "timestamp": "2025-..."}

# Check main endpoint
curl http://$EC2_IP:5000
# → {"message": "Hello from DevOps Demo App!", "version": "...", ...}

# SSH in to check logs
ssh -i ~/.ssh/devops-demo ec2-user@$EC2_IP
docker logs devops-demo-app --tail 50
```

---

## 🔒 Security Implementation

### No Hardcoded Secrets
- SSH keys passed via `TF_VAR_ssh_public_key` environment variable
- AWS credentials via environment variables or IAM roles
- GitHub Secrets for CI/CD sensitive values
- `.gitignore` blocks `*.pem`, `*.key`, `*.tfvars`, `.env`

### SSH Key Authentication
- Password authentication disabled by default on Amazon Linux 2023
- ED25519 key pair: stronger than RSA, smaller key
- Private key stored only in GitHub Secrets and local machine
- EC2 enforces key-based login via `~/.ssh/authorized_keys`

### Minimal Open Ports
| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | Your IP only | SSH management |
| 5000 | TCP | 0.0.0.0/0 | Application traffic |
| 80 | TCP | 0.0.0.0/0 | Future nginx proxy |

All other ports blocked. Outbound unrestricted (for Docker pulls, OS updates).

### Container Security
- Non-root user inside Docker container
- Multi-stage build (no build tools in runtime image)
- `--restart unless-stopped` for resilience

---

## 📊 Logging & Monitoring

### CloudWatch Logs
Two log groups are created automatically:

| Log Group | Contents |
|-----------|----------|
| `/devops-demo/app` | Gunicorn access + error logs |
| `/devops-demo/bootstrap` | EC2 startup script output |

View logs:
```bash
# Via AWS Console: CloudWatch → Log Groups → /devops-demo/app

# Via CLI
aws logs tail /devops-demo/app --follow
```

### On-Instance Logs
```bash
ssh -i ~/.ssh/devops-demo ec2-user@$EC2_IP

# App container logs
docker logs devops-demo-app -f

# Bootstrap log
cat /var/log/user-data.log

# Docker cleanup log
cat /var/log/app/docker-cleanup.log
```

---

## 💰 Estimated AWS Cost Per Day

| Resource | Spec | Cost/day |
|---|---|---|
| EC2 t3.micro | 1 vCPU, 1 GB RAM | ~$0.30 |
| Elastic IP (attached) | Static public IP | $0.00 |
| EBS gp3 volume | 20 GB | ~$0.05 |
| CloudWatch Logs | ~10 MB/day ingest | ~$0.01 |
| Data transfer | ~100 MB/day | ~$0.01 |
| **Total** | | **~$0.37/day** |
| **Monthly** | | **~$11/month** |

> 💡 **Free Tier**: If your AWS account is < 12 months old, t3.micro + 30 GB EBS + 5 GB CloudWatch logs are free. Effective cost could be **$0.00/day**.

---

## 🧹 Teardown

When done, destroy all AWS resources to avoid charges:

```bash
cd terraform
terraform destroy
# Type 'yes' when prompted
```

This removes the EC2 instance, VPC, security group, Elastic IP, and IAM role.

---

## 🔄 Making Changes

To update the application:

1. Edit `app/app.py`
2. Commit and push:
   ```bash
   git add app/app.py
   git commit -m "feat: add new endpoint"
   git push origin main
   ```
3. GitHub Actions automatically builds + deploys in ~3 minutes

To update infrastructure:

```bash
cd terraform
# Edit .tf files
terraform plan    # Review changes
terraform apply   # Apply changes
```

---

## 🐛 Troubleshooting

**App not accessible after deploy?**
```bash
# Check if container is running
ssh -i ~/.ssh/devops-demo ec2-user@$EC2_IP
docker ps
docker logs devops-demo-app

# Check security group allows port 5000
aws ec2 describe-security-groups --filters "Name=group-name,Values=devops-demo-sg"
```

**GitHub Actions deploy failing?**
- Verify `EC2_HOST` secret matches your Elastic IP
- Verify `EC2_SSH_PRIVATE_KEY` includes the full key with headers
- Check the EC2 bootstrap finished: `cat /var/log/user-data.log`

**Terraform error on apply?**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check TF_VAR is set
echo $TF_VAR_ssh_public_key
```

---

## 📦 Tech Stack

- **App**: Python 3.11 + Flask + Gunicorn
- **Container**: Docker (multi-stage build)
- **Registry**: GitHub Container Registry (GHCR)
- **IaC**: Terraform 1.5+ with AWS provider v5
- **CI/CD**: GitHub Actions
- **Cloud**: AWS (EC2, VPC, CloudWatch, IAM)
- **OS**: Amazon Linux 2023

---

## 📝 Complete Journey & Learnings

### Phase 1: Application Development
Started with a minimal Flask app exposing `/` and `/health` endpoints. The `/health` endpoint is critical — it's used by the CI/CD pipeline to verify deployments succeed before marking them complete. Used Gunicorn as the production WSGI server (Flask's dev server is single-threaded and not suitable for production).

### Phase 2: Docker Containerization
Wrote a multi-stage Dockerfile to keep the runtime image small. The builder stage installs all Python packages; the runtime stage copies only the installed packages. Added a Docker HEALTHCHECK instruction so `docker ps` shows health status. Created a non-root user (`appuser`) to run the app — containers running as root are a security risk.

### Phase 3: Infrastructure as Code
Used Terraform to define every AWS resource. Key decisions:
- **Elastic IP** instead of just a public IP — public IPs change on instance stop/start, breaking the GitHub Secret
- **IAM role** for EC2 with `CloudWatchAgentServerPolicy` — never put AWS keys on the instance
- **Encrypted EBS** — enabled root volume encryption with one line
- **SSH CIDR restriction** — pass your own IP to `TF_VAR_ssh_allowed_cidr`

The `user_data.sh` script bootstraps the instance on first boot: installs Docker, configures CloudWatch agent, and writes the `deploy.sh` script.

### Phase 4: CI/CD Pipeline
GitHub Actions workflow has two jobs chained together:
1. **Build** — runs on every push, builds and pushes the Docker image to GHCR
2. **Deploy** — runs only on `main` branch pushes, SSHes into EC2 and calls `deploy.sh`

The deploy script does a graceful swap: stop old container → pull new image → start new container → health check. If the health check fails, the pipeline fails and the team is notified.

### Phase 5: Security Hardening
- All secrets in GitHub Secrets or environment variables
- SSH key auth only (no passwords)
- Docker non-root user
- Minimal security group rules
- Encrypted EBS volume
- `.gitignore` prevents accidental secret commits
