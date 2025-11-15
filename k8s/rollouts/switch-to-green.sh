#!/bin/bash

##############################################################################
# Script to Switch Nginx Demo from Blue to Green
##############################################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "  Blue → Green Deployment Demo"
echo -e "==========================================${NC}"
echo ""

# Update the rollout to use Green version
echo -e "${YELLOW}→ Updating rollout to GREEN version...${NC}"
kubectl patch rollout nginx-demo -n nginx-demo \
  --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/template/spec/volumes/0/configMap/name", "value":"nginx-green"},
    {"op": "replace", "path": "/spec/template/metadata/labels/version", "value":"green"}
  ]'

echo ""
echo -e "${GREEN}✓ Green version deployed to PREVIEW environment!${NC}"
echo ""
echo -e "${YELLOW}→ Waiting 10 seconds for rollout to progress...${NC}"
sleep 10

# Show current status
echo ""
echo -e "${BLUE}Current Rollout Status:${NC}"
kubectl argo rollouts get rollout nginx-demo -n nginx-demo

echo ""
echo -e "${YELLOW}=========================================="
echo "  Next Steps:"
echo -e "==========================================${NC}"
echo ""
echo "1. Check PRODUCTION URL (still showing BLUE):"
echo "   Production: http://$(kubectl get ingress nginx-demo -n nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo ""
echo "2. Check PREVIEW URL (now showing GREEN):"
echo "   Preview: http://$(kubectl get ingress nginx-demo-preview -n nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo ""
echo "3. To promote GREEN to production:"
echo "   kubectl argo rollouts promote nginx-demo -n nginx-demo"
echo ""
echo "4. To abort and rollback to BLUE:"
echo "   kubectl argo rollouts abort nginx-demo -n nginx-demo"
echo ""

