# GitOps-Based Deployment Pipeline on AWS EKS

[![Terraform](https://img.shields.io/badge/Terraform-≥1.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?logo=argo)](https://argoproj.github.io/cd/)
[![Helm](https://img.shields.io/badge/Helm-3.0+-0F1689?logo=helm)](https://helm.sh/)

> **Complete automated CI/CD pipeline with GitOps, featuring automated rollbacks and blue/green deployments**

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Quick Start](#quick-start)
- [Testing](#testing)
- [Documentation](#documentation)
- [Cost Estimate](#cost-estimate)

---

## 🎯 Overview

This project implements a **production-ready GitOps pipeline** for deploying microservices on AWS EKS, featuring:

- ✅ **Infrastructure as Code** with Terraform
- ✅ **GitOps Deployment** with ArgoCD  
- ✅ **Helm Charts** for application packaging
- ✅ **Automated Rollbacks** on failures
- ✅ **Blue/Green Deployments** with Argo Rollouts
- ✅ **Comprehensive Testing** scenarios

**Reference Application**: 2048 game (simple, stateless microservice)

---

## 🏗️ Architecture

### Infrastructure Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Container Orchestration** | AWS EKS (Kubernetes 1.28) | Managed Kubernetes cluster |
| **GitOps Engine** | ArgoCD | Automated deployment from Git |
| **Deployment Strategy** | Argo Rollouts | Blue/green deployments |
| **Package Management** | Helm 3 | Application templating |
| **Load Balancing** | AWS Load Balancer Controller | ALB provisioning |
| **Metrics** | Metrics Server | Resource metrics |
| **Infrastructure** | Terraform | IaC provisioning |

### High-Level Flow

```
Developer → Git Push → ArgoCD Detects → Deploy to EKS → Health Checks → Live
                           ↓
                    Rollback on Failure
```

### Deployment Strategies

**Primary (Helm)**: Rolling Update
- Zero downtime
- Gradual rollout
- Automated rollback on health check failure

**Extra Credit (Argo Rollouts)**: Blue/Green
- Preview environment
- Manual promotion gate
- Instant rollback capability

---

## ✨ Features

### 1. Automated Infrastructure Provisioning

```bash
terraform apply
```

Provisions:
- Multi-AZ VPC with public/private subnets
- EKS cluster with managed node groups
- NAT Gateway for internet access
- IAM roles and security groups
- ArgoCD and addons

### 2. GitOps Continuous Delivery

```bash
git commit -m "Update app version"
git push origin main
# ArgoCD automatically detects and deploys
```

Features:
- Automatic sync from Git
- Self-healing (reverts manual changes)
- Drift detection
- Audit trail in Git history

### 3. Helm-Packaged Microservice

```bash
helm install game-2048 ./helm-charts/game-2048
```

Includes:
- Parameterized configuration
- Health checks (liveness & readiness)
- Resource limits
- Rolling update strategy
- Automated rollback settings

### 4. Automated Rollback Mechanisms

**Kubernetes Level**:
```yaml
spec:
  progressDeadlineSeconds: 600
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0  # Zero downtime
```

**Helm Level**:
```bash
helm upgrade --atomic --timeout 5m
```

**ArgoCD Level**:
- Self-healing
- Auto-sync
- One-click rollback in UI

### 5. Blue/Green Deployment (Extra Credit)

```bash
# Deploy new version to preview
kubectl argo rollouts set image game-2048-rollout \
  game-2048=public.ecr.aws/l6m2t8p7/docker-2048:v2.0

# Test preview environment
curl http://<preview-alb-url>

# Promote to production
kubectl argo rollouts promote game-2048-rollout
```

Benefits:
- Zero downtime
- Test before production
- Instant rollback
- Separate preview URL

---

## 🚀 Quick Start

### Prerequisites

```bash
# Required tools
- AWS CLI (configured with credentials)
- Terraform >= 1.0
- kubectl >= 1.28
- Helm >= 3.0
- (Optional) ArgoCD CLI
```

### Step 1: Deploy Infrastructure (~15 minutes)

```bash
# Clone repository
git clone <your-repo-url>
cd gitops-pipeline

# Initialize and apply Terraform
terraform init
terraform plan
terraform apply

# Configure kubectl
aws eks update-kubeconfig \
  --region us-west-2 \
  --name getting-started-gitops
```

### Step 2: Verify Installation

```bash
# Check nodes
kubectl get nodes

# Check ArgoCD
kubectl get pods -n argocd

# Get ArgoCD credentials
echo "Username: admin"
echo "Password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"

# Access ArgoCD UI (optional)
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
open https://localhost:8080
```

### Step 3: Deploy Application (~5 minutes)

```bash
# Deploy workload via ArgoCD
kubectl apply -f bootstrap/workloads.yaml

# Watch deployment
kubectl get applications -n argocd -w
# Wait for all to show: Synced / Healthy

# Verify application
kubectl get pods -n game-2048
kubectl get ingress -n game-2048

# Get application URL
echo "Application URL: http://$(kubectl get ingress game-2048 -n game-2048 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

### Step 4: Deploy Blue/Green (Extra Credit)

```bash
# Deploy Argo Rollout
kubectl apply -f k8s/rollouts/game-2048-rollout.yaml

# Watch rollout progress
kubectl argo rollouts get rollout game-2048-rollout -n game-2048-rollouts --watch

# Get preview and production URLs
echo "Production URL: http://$(kubectl get ingress game-2048-rollout -n game-2048-rollouts -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Preview URL: http://$(kubectl get ingress game-2048-rollout-preview -n game-2048-rollouts -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

### Step 5: Run Tests

```bash
# Test automated rollback
./tests/scenarios/test-rollback.sh

# Test blue/green deployment  
./tests/scenarios/test-blue-green.sh

# Test GitOps sync
./tests/scenarios/test-gitops-sync.sh
```

### Step 6: Cleanup

```bash
# Destroy all infrastructure
./destroy.sh

# Or manually
terraform destroy
```

---

## 🧪 Testing

### Automated Test Scenarios

Three comprehensive test scripts are provided:

#### 1. Automated Rollback Test

```bash
./tests/scenarios/test-rollback.sh
```

**Demonstrates**:
- Deploying working version
- Triggering deployment failure (invalid image)
- Kubernetes preventing bad deployment
- Manual rollback execution
- Application health verification

#### 2. Blue/Green Deployment Test

```bash
./tests/scenarios/test-blue-green.sh
```

**Demonstrates**:
- Initial blue version deployment
- Green version to preview
- Automated testing on preview
- Traffic switching
- Zero-downtime deployment

#### 3. GitOps Auto-Sync Test

```bash
./tests/scenarios/test-gitops-sync.sh
```

**Demonstrates**:
- ArgoCD monitoring Git repository
- Drift detection
- Manual sync trigger
- Deployment history

### Manual Testing

```bash
# Test deployment update
kubectl set image deployment/game-2048 game-2048=<new-image> -n game-2048

# Test rollback
kubectl rollout undo deployment/game-2048 -n game-2048

# Test blue/green promotion
kubectl argo rollouts promote game-2048-rollout -n game-2048-rollouts

# Test blue/green rollback
kubectl argo rollouts undo game-2048-rollout -n game-2048-rollouts
```

---

## 📚 Documentation

### Main Documentation Files

| File | Description |
|------|-------------|
| **[ASSIGNMENT.md](ASSIGNMENT.md)** | Complete assignment documentation with detailed architecture, design choices, and rationale |
| **[helm-charts/game-2048/](helm-charts/game-2048/)** | Helm chart for 2048 microservice |
| **[k8s/rollouts/](k8s/rollouts/)** | Argo Rollouts manifests for blue/green deployment |
| **[tests/scenarios/](tests/scenarios/)** | Automated test scripts |

### Key Topics in ASSIGNMENT.md

1. **Infrastructure Provisioning**: Terraform setup, VPC configuration, EKS setup
2. **GitOps Setup**: ArgoCD configuration, App of Apps pattern
3. **Application Deployment**: Helm chart structure, deployment strategies
4. **Automated Rollbacks**: Multiple layers of rollback mechanisms
5. **Blue/Green Deployment**: Argo Rollouts implementation
6. **Testing & Validation**: Comprehensive test scenarios
7. **Design Choices**: Detailed rationale for all technical decisions
8. **Cost Analysis**: Daily and monthly cost breakdown

### Quick Reference Commands

```bash
# ArgoCD
kubectl get applications -n argocd
kubectl describe application workloads -n argocd
argocd app sync workloads
argocd app rollback workloads

# Helm
helm list -A
helm history game-2048 -n game-2048
helm rollback game-2048 -n game-2048

# Argo Rollouts
kubectl argo rollouts list rollouts -A
kubectl argo rollouts get rollout <name> -n <namespace>
kubectl argo rollouts promote <name> -n <namespace>
kubectl argo rollouts undo <name> -n <namespace>

# Monitoring
kubectl get pods -A
kubectl top nodes
kubectl top pods -A
kubectl get events -n <namespace>
```

---

## 💰 Cost Estimate

### Daily Costs (us-west-2)

| Component | Cost |
|-----------|------|
| EKS Control Plane | $2.40 |
| Worker Nodes (2× t3.micro) | $0.00* |
| NAT Gateway | $1.08 |
| Data Transfer | $0.45 |
| EBS Volumes | $0.11 |
| ALB (per ingress) | $0.54 |
| Misc | $0.50 |
| **Total** | **~$4.48/day** |

**\*Free Tier**: 750 hours/month for first 12 months

### Monthly Costs

- **With Free Tier**: ~$135/month
- **Without Free Tier**: ~$195/month
- **Production (t3.small)**: ~$225/month

### Cost Optimization Tips

1. Use Spot instances (save 70%)
2. Enable Cluster Autoscaler (scale to 1 node when idle)
3. Use Savings Plans (30-50% savings)
4. VPC endpoints for AWS services (reduce NAT costs)

---

## 🏗️ Project Structure

```
gitops-pipeline/
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Terraform variables
├── outputs.tf                   # Terraform outputs
├── bootstrap/
│   ├── addons.yaml             # ArgoCD addons application
│   └── workloads.yaml          # ArgoCD workloads application
├── helm-charts/
│   └── game-2048/              # Helm chart for microservice
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── hpa.yaml
│           └── ...
├── k8s/
│   ├── game-2048.yaml          # Original manifest (legacy)
│   └── rollouts/
│       ├── game-2048-rollout.yaml    # Blue/green rollout
│       └── analysis-template.yaml     # Automated testing
├── tests/
│   └── scenarios/
│       ├── test-rollback.sh          # Rollback test
│       ├── test-blue-green.sh        # Blue/green test
│       └── test-gitops-sync.sh       # GitOps test
├── ASSIGNMENT.md               # Complete assignment documentation
├── README.md                   # This file (quick start)
└── destroy.sh                  # Cleanup script
```

---

## 🔧 Troubleshooting

### Common Issues

<details>
<summary><b>Pods stuck in ImagePullBackOff</b></summary>

```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Verify image exists
docker pull public.ecr.aws/l6m2t8p7/docker-2048:latest
```
</details>

<details>
<summary><b>ArgoCD application OutOfSync</b></summary>

```bash
# Manual sync
kubectl patch application workloads -n argocd --type merge -p '{"operation":{"sync":{}}}'

# Check diff
argocd app diff workloads
```
</details>

<details>
<summary><b>Ingress not getting ALB</b></summary>

```bash
# Check AWS LB Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```
</details>

<details>
<summary><b>Argo Rollout stuck</b></summary>

```bash
# Check status
kubectl argo rollouts status <name> -n <namespace>

# Abort and rollback
kubectl argo rollouts abort <name> -n <namespace>
kubectl argo rollouts undo <name> -n <namespace>
```
</details>

---

## 📖 Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS Blueprints](https://aws-ia.github.io/terraform-aws-eks-blueprints/)

---

## 🤝 Contributing

This is a take-home assignment submission. For questions or improvements:

1. Review the detailed [ASSIGNMENT.md](ASSIGNMENT.md)
2. Check test scenarios in `tests/scenarios/`
3. Review Helm chart in `helm-charts/game-2048/`

---

## 📄 License

MIT License - Feel free to use this as a reference for your own projects.

---

## ⭐ Key Highlights

This project demonstrates:

✅ **Complete GitOps Pipeline** - From commit to production  
✅ **Multi-Layer Rollback** - Kubernetes, Helm, ArgoCD, Argo Rollouts  
✅ **Production Patterns** - Health checks, resource limits, RBAC  
✅ **Cost Optimized** - ~$4.48/day with Free Tier  
✅ **Well Documented** - Comprehensive documentation and test scenarios  
✅ **Best Practices** - Security, scalability, observability  

**Perfect for**: DevOps interviews, learning GitOps, reference architecture

---

**Made with ❤️ for DevOps Excellence**

