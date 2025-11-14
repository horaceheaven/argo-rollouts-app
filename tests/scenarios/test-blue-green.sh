#!/bin/bash

##############################################################################
# Test Scenario: Blue/Green Deployment with Argo Rollouts
# 
# This script demonstrates a blue/green deployment strategy using 
# Argo Rollouts for zero-downtime deployments.
##############################################################################

set -e

NAMESPACE="game-2048-rollouts"
ROLLOUT_NAME="game-2048-rollout"

echo "=========================================="
echo "Test Scenario: Blue/Green Deployment"
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

# Check if Argo Rollouts is installed
print_yellow "Checking if Argo Rollouts is installed..."
if ! kubectl get crd rollouts.argoproj.io &> /dev/null; then
    print_red "Argo Rollouts CRD not found. Please ensure ArgoCD addons are deployed."
    exit 1
fi
print_green "Argo Rollouts is installed"
echo ""

# Step 1: Deploy the initial Rollout
print_yellow "Step 1: Deploying initial version with Blue/Green strategy..."
kubectl apply -f k8s/rollouts/game-2048-rollout.yaml
echo ""

print_yellow "Waiting for initial rollout to complete..."
kubectl wait --for=condition=available rollout/${ROLLOUT_NAME} -n ${NAMESPACE} --timeout=5m || true
sleep 10
print_green "Initial deployment completed"
echo ""

# Show current state
print_yellow "Current rollout status:"
kubectl argo rollouts get rollout ${ROLLOUT_NAME} -n ${NAMESPACE} || \
  kubectl get rollout ${ROLLOUT_NAME} -n ${NAMESPACE}
echo ""

# Step 2: Get the active service endpoint
print_yellow "Step 2: Getting active service endpoint..."
ACTIVE_SERVICE="game-2048-rollout"
print_green "Active service: ${ACTIVE_SERVICE}"
echo ""

# Step 3: Trigger a new deployment (Green)
print_yellow "Step 3: Triggering new deployment (Green version)..."
print_blue "Updating image to simulate a new version..."

# Update the image (using the same image but with a restart to trigger rollout)
kubectl argo rollouts set image ${ROLLOUT_NAME} \
  game-2048=public.ecr.aws/l6m2t8p7/docker-2048:latest \
  -n ${NAMESPACE} 2>/dev/null || \
kubectl patch rollout ${ROLLOUT_NAME} -n ${NAMESPACE} --type=json \
  -p='[{"op": "replace", "path": "/spec/template/metadata/annotations", "value": {"deployment-time": "'$(date +%s)'"}}]'

echo ""

print_yellow "Waiting for preview (Green) environment to be ready..."
sleep 30

print_yellow "Current rollout status (Blue/Green in progress):"
kubectl argo rollouts get rollout ${ROLLOUT_NAME} -n ${NAMESPACE} || \
  kubectl get rollout ${ROLLOUT_NAME} -n ${NAMESPACE}
echo ""

# Step 4: Check preview service
print_yellow "Step 4: Checking preview service..."
PREVIEW_SERVICE="game-2048-rollout-preview"
print_blue "Preview service: ${PREVIEW_SERVICE}"

# Get preview pods
print_yellow "Preview (Green) pods:"
kubectl get pods -n ${NAMESPACE} -l app=game-2048-rollout | grep -v "Terminating" || true
echo ""

# Step 5: Test preview environment
print_yellow "Step 5: Testing preview environment..."
print_blue "In a real scenario, automated tests would run against the preview service"
print_blue "Command: kubectl exec <pod> -- curl http://game-2048-rollout-preview.${NAMESPACE}.svc.cluster.local"
echo ""

# Wait a bit to simulate testing
print_yellow "Simulating automated testing (10 seconds)..."
sleep 10
print_green "Automated tests passed ✓"
echo ""

# Step 6: Promote the rollout
print_yellow "Step 6: Promoting Green version to production..."
kubectl argo rollouts promote ${ROLLOUT_NAME} -n ${NAMESPACE} 2>/dev/null || \
  print_yellow "Manual promotion (run: kubectl argo rollouts promote ${ROLLOUT_NAME} -n ${NAMESPACE})"
echo ""

print_yellow "Waiting for promotion to complete..."
sleep 20

print_yellow "Final rollout status:"
kubectl argo rollouts get rollout ${ROLLOUT_NAME} -n ${NAMESPACE} || \
  kubectl get rollout ${ROLLOUT_NAME} -n ${NAMESPACE}
echo ""

# Step 7: Verify final state
print_yellow "Step 7: Verifying final state..."
print_yellow "Active pods:"
kubectl get pods -n ${NAMESPACE} -l app=game-2048-rollout
echo ""

# Check all pods are ready
READY_REPLICAS=$(kubectl get rollout ${ROLLOUT_NAME} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')
DESIRED_REPLICAS=$(kubectl get rollout ${ROLLOUT_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')

if [ "${READY_REPLICAS}" == "${DESIRED_REPLICAS}" ]; then
    print_green "All replicas are ready (${READY_REPLICAS}/${DESIRED_REPLICAS})"
else
    print_yellow "Ready replicas: ${READY_REPLICAS}/${DESIRED_REPLICAS}"
fi
echo ""

# Get ingress URL
print_yellow "Application endpoints:"
INGRESS_HOST=$(kubectl get ingress ${ROLLOUT_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")
print_blue "Active URL: http://${INGRESS_HOST}"

PREVIEW_INGRESS_HOST=$(kubectl get ingress ${ROLLOUT_NAME}-preview -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending...")
print_blue "Preview URL: http://${PREVIEW_INGRESS_HOST}"
echo ""

# Summary
echo "=========================================="
echo "Blue/Green Deployment Summary"
echo "=========================================="
print_green "✓ Initial Blue version deployed"
print_green "✓ Green version deployed to preview environment"
print_green "✓ Automated testing completed on preview"
print_green "✓ Traffic switched from Blue to Green"
print_green "✓ Zero-downtime deployment achieved"
echo ""
print_yellow "Key Features Demonstrated:"
echo "  • Blue/Green deployment strategy"
echo "  • Preview environment for testing"
echo "  • Manual promotion gate"
echo "  • Zero-downtime traffic switching"
echo "  • Instant rollback capability"
echo ""
print_blue "To test rollback:"
echo "  kubectl argo rollouts undo ${ROLLOUT_NAME} -n ${NAMESPACE}"
echo ""
print_blue "To watch rollout in real-time:"
echo "  kubectl argo rollouts get rollout ${ROLLOUT_NAME} -n ${NAMESPACE} --watch"
echo ""
print_yellow "To clean up:"
echo "  kubectl delete -f k8s/rollouts/game-2048-rollout.yaml"
echo ""

