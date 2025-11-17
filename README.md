## Overview

This repository implements a complete **GitOps-based CI/CD pipeline** for containerized applications on AWS EKS using ArgoCD and Argo Rollouts. The infrastructure automates the deployment of applications with **blue/green deployment strategies**, providing zero-downtime releases and automated rollback capabilities.

### Key Features

- **GitOps Workflow**: Infrastructure and application deployments are managed through Git, ensuring declarative configuration and audit trails
- **CI/CD Pipeline**: GitHub Actions automatically builds Docker images, pushes to ECR, and updates Kubernetes manifests on every code change
- **Blue/Green Deployments**: Argo Rollouts enables safe, zero-downtime deployments with manual promotion gates
- **Automated Rollback**: Configured to automatically rollback failed deployments within 5 minutes
- **AWS Native**: Leverages EKS, ECR, VPC, and AWS Load Balancer Controller for production-ready infrastructure
- **Secure by Default**: GitHub Actions uses OIDC for AWS authentication (no access keys stored)

### Architecture Components

1. **Infrastructure Layer** (Terraform):
   - VPC with public/private subnets and NAT Gateway
   - EKS cluster with managed node groups
   - ECR repository for Docker images
   - IAM roles and OIDC provider for GitHub Actions

2. **GitOps Layer** (ArgoCD):
   - GitOps Bridge for bootstrapping cluster addons
   - ArgoCD Application for deploying workloads
   - Automatic synchronization from Git repository

3. **Deployment Layer** (Argo Rollouts):
   - Blue/Green deployment strategy
   - Active and Preview services
   - Manual promotion gates (auto-promotion disabled by default)

4. **CI/CD Layer** (GitHub Actions):
   - Automated Docker image builds
   - ECR image push with SHA-based tagging
   - GitOps manifest updates

## Getting Started

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl installed
- AWS permissions to create VPC, EKS, ECR resources

### Step 1: Provision Infrastructure

Deploy the infrastructure in stages for better visibility and error handling:

```bash
# Create VPC and networking components
terraform apply -target="module.vpc" -auto-approve

# Create EKS cluster and node groups
terraform apply -target="module.eks" -auto-approve

# Create remaining resources (ECR, IAM roles, outputs)
terraform apply -auto-approve
```

### Step 2: Configure kubectl

Connect your local kubectl to the EKS cluster:

```bash
aws eks --region us-west-2 update-kubeconfig --name app-cluster-us-west-2
```

Verify access:

```bash
kubectl get nodes
```

### Step 3: Bootstrap GitOps Addons

Bootstrap ArgoCD and cluster addons using the GitOps Bridge:

```bash
kubectl apply --server-side -f bootstrap/addons.yaml
```

Wait for ArgoCD to be ready (this may take 2-3 minutes):

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 4: Access ArgoCD UI

Get the ArgoCD access credentials:

```bash
terraform output -raw access_argocd
```

This will display:
- ArgoCD admin username (`admin`)
- Initial admin password
- ArgoCD server URL (if LoadBalancer is configured)

Alternatively, use port-forwarding:

```bash
kubectl port-forward -n argocd svc/argo-cd-argocd-server 8080:80
# Access at http://localhost:8080
```

### Step 5: Deploy the Application

Create the ArgoCD Application that monitors the GitOps repository:

```bash
kubectl apply -f argocd-apps/nginx-gitops-demo.yaml
```

This creates an ArgoCD Application that:
- Monitors the `k8s/rollouts` directory in this repository
- Auto-syncs changes to the `nginx-demo` namespace
- Deploys the Nginx application with Argo Rollouts

### Step 6: Verify Deployment

Check ArgoCD application status:

```bash
kubectl get applications -n argocd
```

Check the rollout status:

```bash
kubectl get rollout -n nginx-demo
kubectl argo rollouts get rollout nginx-demo -n nginx-demo
```

Get the application ingress URL:

```bash
kubectl get ingress -n nginx-demo
```

## Demonstrating Blue/Green Deployment

### Quick Demo Steps

1. **Check Current Status**:
   ```bash
   kubectl argo rollouts get rollout nginx-demo -n nginx-demo
   ```

2. **Trigger a New Deployment**:
   - Make a change to `nginx-app/html/index.html` and push to `main`
   - GitHub Actions will build a new image and update the manifest
   - ArgoCD will automatically sync the changes

3. **View Blue/Green State**:
   ```bash
   # See both blue (active) and green (preview) revisions
   kubectl argo rollouts get rollout nginx-demo -n nginx-demo
   
   # Get preview service URL
   kubectl get ingress nginx-demo-preview -n nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   
   # Get production service URL
   kubectl get ingress nginx-demo -n nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

4. **Test Preview Environment**:
   - Visit the preview ingress URL to see the green version
   - Verify it's working correctly

5. **Promote Green to Production**:
   ```bash
   kubectl argo rollouts promote nginx-demo -n nginx-demo
   ```

6. **Verify Promotion**:
   - Visit the production ingress URL
   - You should see the new version (previously green, now active)
   - The old blue version will be scaled down after 30 seconds

### Simplifying the Demo

For a simpler demo without health analysis:
- Comment out `prePromotionAnalysis` and `postPromotionAnalysis` in the Rollout spec
- The AnalysisTemplates are optional and can be skipped for basic demonstrations

## Architecture

![GitOpsPipeline](static/GitOpsPIpeline.png "GitOps Pipeline")

### Architecture Flow

1. **Code Push**: Developer pushes code changes to the `nginx-app/` directory in GitHub
2. **CI Trigger**: GitHub Actions workflow automatically triggers on push to `main` branch
3. **Build & Push**: Workflow builds Docker image and pushes to Amazon ECR with SHA-based tags
4. **GitOps Update**: Workflow updates the Kubernetes manifest (`k8s/rollouts/nginx-demo-rollout.yaml`) with the new image tag and commits back to Git
5. **ArgoCD Sync**: ArgoCD detects the Git change and automatically syncs the updated manifest to the cluster
6. **Blue/Green Deployment**: Argo Rollouts creates a new "Green" revision alongside the existing "Blue" revision
7. **Preview Testing**: Green revision is available via preview service/ingress for testing
8. **Manual Promotion**: After validation, the Green revision is manually promoted to Active (Blue service switches traffic)
9. **Auto Rollback**: If deployment fails within 5 minutes, Argo Rollouts automatically rolls back to the previous revision
10. **Traffic Routing**: AWS Application Load Balancer routes production traffic to the Active service

## TODO
- [x] Change EKS cluster name (changed to `app-cluster-us-west-2`)
- [x] Rollback on fail (configured with `progressDeadlineSeconds: 300`)

## Requirements
- [] Rollback on failure
- [] Auto sync on git push

## Assumptions


## Future Improvements
- [ ] Add terraform to github actions pipeline for bootstrap and setup


## Test Scenarios

### Scenario 1: Simulate Deployment Failure and Automatic Rollback

**Objective:** Verify that a failed deployment automatically rolls back to the previous working revision.

**Prerequisites:**
- Application is deployed and running
- You have `kubectl` access to the cluster

**Steps:**

1. **Check Current Status:**
   ```bash
   kubectl argo rollouts get rollout nginx-demo -n nginx-demo
   ```
   Note the current image tag and revision number.

2. **Deploy a Broken Image:**
   ```bash
   # Update the Helm values.yaml with an invalid image tag
   # Or manually set an invalid image
   kubectl set image rollout/nginx-demo nginx=invalid-image:tag -n nginx-demo
   ```
   Alternatively, update `helm-charts/nginx-demo/values.yaml` with an invalid image tag and push to Git.

3. **Monitor Rollout Status:**
   ```bash
   # Watch the rollout status
   kubectl argo rollouts get rollout nginx-demo -n nginx-demo -w
   ```
   You should see:
   - Rollout enters "Progressing" state
   - New ReplicaSet created but pods fail to start
   - Status changes to "Degraded" after health check failures

4. **Wait for Automatic Rollback:**
   The rollout will automatically rollback if:
   - Pods fail health checks (liveness/readiness probes)
   - `progressDeadlineSeconds` (600 seconds) expires
   - Pre-promotion or post-promotion analysis fails

5. **Verify Rollback:**
   ```bash
   # Check rollout phase
   kubectl get rollout nginx-demo -n nginx-demo -o jsonpath='{.status.phase}'
   # Should show "Healthy" after rollback
   
   # Check which revision is active
   kubectl argo rollouts get rollout nginx-demo -n nginx-demo
   # Should show previous working revision as "stable, active"
   
   # Verify pods are running
   kubectl get pods -n nginx-demo -l app=nginx-demo
   # Should show pods from previous working revision
   ```

6. **Check Rollout History:**
   ```bash
   kubectl argo rollouts history nginx-demo -n nginx-demo
   ```
   You should see the failed revision and the rollback to the previous revision.

**Expected Result:**
- ✅ Rollout detects failure within 600 seconds (`progressDeadlineSeconds`)
- ✅ Automatically rolls back to previous working revision
- ✅ Production service remains available throughout (zero downtime)
- ✅ Rollout status returns to "Healthy"

**Rollback Mechanisms Tested:**
1. **Progress Deadline**: Rollout fails if not progressing within deadline
2. **Health Probes**: Liveness/readiness probes detect unhealthy pods
3. **Analysis Templates**: Pre/post-promotion analysis can trigger rollback

**Troubleshooting:**
- If rollback doesn't happen automatically, check `progressDeadlineSeconds` value
- Verify health probes are configured correctly
- Check AnalysisTemplate resources exist: `kubectl get analysistemplate -n nginx-demo`