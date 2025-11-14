#!/bin/bash

##############################################################################
# Test Scenario: GitOps Automated Deployment
# 
# This script demonstrates how ArgoCD automatically detects and deploys
# changes from the Git repository.
##############################################################################

set -e

NAMESPACE="game-2048"
APP_NAME="workloads"

echo "=========================================="
echo "Test Scenario: GitOps Auto-Sync"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_green() { echo -e "${GREEN}✓ $1${NC}"; }
print_red() { echo -e "${RED}✗ $1${NC}"; }
print_yellow() { echo -e "${YELLOW}→ $1${NC}"; }
print_blue() { echo -e "${BLUE}ℹ $1${NC}"; }

# Step 1: Check current state
print_yellow "Step 1: Checking current ArgoCD application state..."
kubectl get application ${APP_NAME} -n argocd -o wide
echo ""

# Get sync status
SYNC_STATUS=$(kubectl get application ${APP_NAME} -n argocd -o jsonpath='{.status.sync.status}')
HEALTH_STATUS=$(kubectl get application ${APP_NAME} -n argocd -o jsonpath='{.status.health.status}')

print_blue "Sync Status: ${SYNC_STATUS}"
print_blue "Health Status: ${HEALTH_STATUS}"
echo ""

# Step 2: Show current deployment
print_yellow "Step 2: Current deployment in namespace ${NAMESPACE}..."
kubectl get deployment,service,ingress -n ${NAMESPACE}
echo ""

# Get current replica count
CURRENT_REPLICAS=$(kubectl get deployment game-2048 -n ${NAMESPACE} -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
print_blue "Current replicas: ${CURRENT_REPLICAS}"
echo ""

# Step 3: Demonstrate Git change detection
print_yellow "Step 3: GitOps Change Detection Flow"
print_blue "In a real scenario, the following would happen:"
echo ""
echo "  1. Developer commits changes to Git repository"
echo "     Example: Update image tag in k8s/game-2048.yaml"
echo "     git commit -m 'Update to version 2.0'"
echo "     git push origin main"
echo ""
echo "  2. ArgoCD detects the Git repository change"
echo "     (polling interval: 3 minutes by default)"
echo ""
echo "  3. ArgoCD compares live state vs desired state"
echo "     Application status changes to: OutOfSync"
echo ""
echo "  4. If auto-sync is enabled:"
echo "     ArgoCD automatically applies the changes"
echo "     Application status changes to: Syncing → Synced"
echo ""
echo "  5. Health checks verify the deployment"
echo "     Application health changes to: Progressing → Healthy"
echo ""

# Step 4: Manual sync demonstration
print_yellow "Step 4: Demonstrating manual sync..."
print_blue "To manually trigger a sync:"
echo "  kubectl patch application ${APP_NAME} -n argocd --type merge -p '{\"operation\":{\"sync\":{}}}'"
echo ""

# Step 5: Watch sync status
print_yellow "Step 5: Monitoring application sync..."
print_blue "To watch sync progress in real-time:"
echo "  kubectl get application ${APP_NAME} -n argocd -w"
echo ""
print_blue "To see detailed sync status:"
echo "  kubectl describe application ${APP_NAME} -n argocd"
echo ""

# Step 6: Verify deployment history
print_yellow "Step 6: Checking deployment history..."
if kubectl get deployment game-2048 -n ${NAMESPACE} &> /dev/null; then
    kubectl rollout history deployment/game-2048 -n ${NAMESPACE}
else
    print_yellow "Deployment not found in namespace ${NAMESPACE}"
fi
echo ""

# Step 7: Check sync waves (if applicable)
print_yellow "Step 7: ArgoCD Sync Waves"
print_blue "Sync waves allow ordering of resource deployment:"
echo "  Wave 0: Namespaces, CustomResourceDefinitions"
echo "  Wave 1: ServiceAccounts, Secrets, ConfigMaps"
echo "  Wave 2: Deployments, StatefulSets"
echo "  Wave 3: Services"
echo "  Wave 4: Ingresses"
echo ""

# Summary
echo "=========================================="
echo "GitOps Deployment Summary"
echo "=========================================="
print_green "✓ ArgoCD monitors Git repository"
print_green "✓ Automatic drift detection"
print_green "✓ Declarative configuration"
print_green "✓ Audit trail in Git history"
print_green "✓ Self-healing capabilities"
echo ""
print_yellow "Key GitOps Principles:"
echo "  • Git as single source of truth"
echo "  • Declarative infrastructure"
echo "  • Automated deployment"
echo "  • Continuous reconciliation"
echo ""
print_blue "Useful ArgoCD Commands:"
echo "  # Get application details"
echo "  kubectl get application -n argocd"
echo ""
echo "  # Sync application"
echo "  kubectl patch application ${APP_NAME} -n argocd --type merge -p '{\"operation\":{\"sync\":{}}}'"
echo ""
echo "  # Get sync status"
echo "  kubectl get application ${APP_NAME} -n argocd -o jsonpath='{.status.sync.status}'"
echo ""
echo "  # Access ArgoCD UI"
echo "  kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443"
echo "  # Username: admin"
echo "  # Password: \$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
echo ""

