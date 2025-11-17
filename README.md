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

## Test Scenarios

### Scenario 1: End-to-End CI/CD Pipeline Validation

**Objective:** Verify complete CI/CD pipeline from code push to deployment.

**Steps:**

1. **Trigger Pipeline:**
   ```bash
   # Make a change and push
   echo "<!-- Test $(date) -->" >> nginx-app/html/index.html
   git add nginx-app/html/index.html && git commit -m "test: CI/CD validation" && git push origin main
   ```

2. **Validate Pipeline Stages:**
   ```bash
   # 1. GitHub Actions workflow
   gh run list --workflow=build-and-deploy.yml --limit 1
   # Or check: https://github.com/horaceheaven/argo-rollouts-app/actions
   
   # 2. ECR image exists
   COMMIT=$(git rev-parse HEAD)
   aws ecr describe-images --repository-name nginx-demo-app --image-ids imageTag=$COMMIT --region us-west-2
   
   # 3. Helm values updated
   git pull && yq eval '.app.image.tag' helm-charts/nginx-demo/values.yaml
   # Should match $COMMIT
   
   # 4. ArgoCD synced
   kubectl get application nginx-gitops-demo -n argocd
   kubectl get application nginx-gitops-demo -n argocd -o jsonpath='{.status.sync.status}' # Should be "Synced"
   
   # 5. New preview revision created
   kubectl argo rollouts get rollout nginx-demo -n nginx-demo
   kubectl get pods -n nginx-demo -l app=nginx-demo
   
   # 6. Preview accessible
   PREVIEW_URL=$(kubectl get ingress nginx-demo-preview -n nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   curl -s http://$PREVIEW_URL | grep -q "Version" && echo "✅ Preview accessible"
   ```

**Expected:** GitHub Actions → ECR push → values.yaml update → ArgoCD sync → Preview deployment (production unchanged)

---

### Scenario 2: Deployment Failure and Automatic Rollback

**Objective:** Verify automatic rollback on deployment failure.

**Steps:**

1. **Deploy Broken Image:**
   ```bash
   # Option 1: Invalid image tag in values.yaml, then push
   # Option 2: Direct kubectl (bypasses CI/CD)
   kubectl set image rollout/nginx-demo nginx=invalid-image:tag -n nginx-demo
   ```

2. **Monitor and Verify Rollback:**
   ```bash
   # Watch rollout status
   kubectl argo rollouts get rollout nginx-demo -n nginx-demo -w
   # Should see: Progressing → Degraded → Healthy (rollback)
   
   # Verify rollback completed
   kubectl get rollout nginx-demo -n nginx-demo -o jsonpath='{.status.phase}' # Should be "Healthy"
   kubectl argo rollouts history nginx-demo -n nginx-demo
   
   # Verify production still accessible
   PROD_URL=$(kubectl get ingress nginx-demo -n nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   curl -s http://$PROD_URL | grep -q "Version" && echo "✅ Production accessible"
   ```

**Expected:** Rollout detects failure → Auto-rollback within 600s → Production remains available

**Rollback Triggers:**
- Health probe failures (liveness/readiness)
- `progressDeadlineSeconds` (600s) exceeded
- Analysis template failures

---

### Scenario 3: Blue/Green Promotion

**Objective:** Verify blue/green promotion process.

**Steps:**

1. **Check State:**
   ```bash
   kubectl argo rollouts get rollout nginx-demo -n nginx-demo
   ACTIVE=$(kubectl get rollout nginx-demo -n nginx-demo -o jsonpath='{.status.blueGreen.activeSelector}')
   PREVIEW=$(kubectl get rollout nginx-demo -n nginx-demo -o jsonpath='{.status.blueGreen.previewSelector}')
   ```

2. **Validate Environments:**
   ```bash
   # Preview
   PREVIEW_URL=$(kubectl get ingress nginx-demo-preview -n nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   curl -s http://$PREVIEW_URL
   
   # Production
   PROD_URL=$(kubectl get ingress nginx-demo -n nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   curl -s http://$PROD_URL
   ```

3. **Promote and Verify:**
   ```bash
   kubectl argo rollouts promote nginx-demo -n nginx-demo
   
   # Verify promotion
   NEW_ACTIVE=$(kubectl get rollout nginx-demo -n nginx-demo -o jsonpath='{.status.blueGreen.activeSelector}')
   [ "$NEW_ACTIVE" = "$PREVIEW" ] && echo "✅ Promotion successful"
   kubectl get rollout nginx-demo -n nginx-demo -o jsonpath='{.status.phase}' # Should be "Healthy"
   ```

**Expected:** Preview and production differ → Promotion switches traffic → Zero downtime

## Assumptions

## Future Improvements
- [ ] Add terraform to github actions pipeline for bootstrap and setup