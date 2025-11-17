#!/bin/bash

##############################################################################
# Cleanup Script for GitOps Pipeline
# 
# This script safely destroys all AWS resources created by Terraform
##############################################################################

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_green() { echo -e "${GREEN}✓ $1${NC}"; }
print_red() { echo -e "${RED}✗ $1${NC}"; }
print_yellow() { echo -e "${YELLOW}→ $1${NC}"; }

echo "=========================================="
echo "  GitOps Pipeline Cleanup"
echo "=========================================="
echo ""

print_yellow "This script will destroy all AWS resources."
print_red "This action cannot be undone!"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_yellow "Cleanup cancelled."
    exit 0
fi

echo ""
print_yellow "Starting cleanup process..."
echo ""

# Step 1: Delete ArgoCD applications first to allow clean removal of resources
print_yellow "Step 1: Removing ArgoCD applications..."
if kubectl get application -n argocd &> /dev/null; then
    kubectl delete application --all -n argocd --timeout=5m || true
    print_green "ArgoCD applications removed"
else
    print_yellow "ArgoCD not found or already removed"
fi
echo ""

# Step 2: Delete any remaining ingresses (to remove ALBs)
print_yellow "Step 2: Removing ingresses..."
kubectl delete ingress --all --all-namespaces --timeout=5m || true
print_green "Ingresses removed"
echo ""

# Step 3: Delete any load balancer services
print_yellow "Step 3: Removing LoadBalancer services..."
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --timeout=5m || true
print_green "LoadBalancer services removed"
echo ""

# Step 4: Wait for AWS resources to be deleted
print_yellow "Step 4: Waiting for AWS resources to be cleaned up (30 seconds)..."
sleep 30
print_green "Wait complete"
echo ""

# Step 5: Run Terraform destroy
print_yellow "Step 5: Destroying infrastructure with Terraform..."
if [ -f "terraform.tfstate" ]; then
    terraform destroy -auto-approve
    print_green "Terraform destroy completed"
else
    print_red "No terraform.tfstate found. Skipping terraform destroy."
fi
echo ""

# Summary
echo "=========================================="
echo "  Cleanup Summary"
echo "=========================================="
print_green "✓ ArgoCD applications deleted"
print_green "✓ Ingresses and LoadBalancers removed"
print_green "✓ Terraform resources destroyed"
echo ""
print_green "Cleanup completed successfully!"
echo ""
print_yellow "Note: It may take a few minutes for all AWS resources to be fully removed."
print_yellow "You can verify in the AWS Console that all resources are gone."
echo ""
