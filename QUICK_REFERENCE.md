# Quick Reference Guide

## 🚀 Common Commands

### Infrastructure

```bash
# Deploy infrastructure
terraform init
terraform apply

# Update infrastructure
terraform plan
terraform apply

# Destroy infrastructure
./destroy.sh
# or
terraform destroy

# View outputs
terraform output

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name getting-started-gitops
```

### ArgoCD

```bash
# Get password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Port forward to UI
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443

# List applications
kubectl get applications -n argocd

# Sync application
kubectl patch application workloads -n argocd \
  --type merge -p '{"operation":{"sync":{}}}'

# Get sync status
kubectl get application workloads -n argocd \
  -o jsonpath='{.status.sync.status}'
```

### Helm

```bash
# Install application
helm install game-2048 ./helm-charts/game-2048 -n game-2048 --create-namespace

# Upgrade application
helm upgrade game-2048 ./helm-charts/game-2048 -n game-2048

# Rollback
helm rollback game-2048 -n game-2048

# View history
helm history game-2048 -n game-2048

# List releases
helm list -A

# Uninstall
helm uninstall game-2048 -n game-2048
```

### Argo Rollouts

```bash
# List rollouts
kubectl argo rollouts list rollouts -A

# Get rollout status
kubectl argo rollouts get rollout game-2048-rollout -n game-2048-rollouts

# Watch rollout
kubectl argo rollouts get rollout game-2048-rollout -n game-2048-rollouts --watch

# Update image
kubectl argo rollouts set image game-2048-rollout \
  game-2048=public.ecr.aws/l6m2t8p7/docker-2048:v2.0 \
  -n game-2048-rollouts

# Promote (Blue → Green)
kubectl argo rollouts promote game-2048-rollout -n game-2048-rollouts

# Abort rollout
kubectl argo rollouts abort game-2048-rollout -n game-2048-rollouts

# Rollback
kubectl argo rollouts undo game-2048-rollout -n game-2048-rollouts

# Restart rollout
kubectl argo rollouts restart game-2048-rollout -n game-2048-rollouts
```

### Kubernetes

```bash
# Get all resources
kubectl get all -A

# Get pods in namespace
kubectl get pods -n game-2048

# Get deployment status
kubectl get deployment -n game-2048

# Get ingress
kubectl get ingress -n game-2048

# Get ingress URL
kubectl get ingress game-2048 -n game-2048 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Describe resource
kubectl describe pod <pod-name> -n <namespace>

# View logs
kubectl logs <pod-name> -n <namespace>
kubectl logs -f <pod-name> -n <namespace>  # Follow

# Execute command in pod
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Rollout status
kubectl rollout status deployment/game-2048 -n game-2048

# Rollout history
kubectl rollout history deployment/game-2048 -n game-2048

# Rollout undo
kubectl rollout undo deployment/game-2048 -n game-2048

# Scale deployment
kubectl scale deployment game-2048 --replicas=3 -n game-2048

# Update image
kubectl set image deployment/game-2048 \
  game-2048=public.ecr.aws/l6m2t8p7/docker-2048:latest \
  -n game-2048
```

### Monitoring

```bash
# Get nodes
kubectl get nodes

# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -A
kubectl top pods -n game-2048

# Get events
kubectl get events -n game-2048 --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n game-2048 --watch

# Describe node
kubectl describe node <node-name>

# Get cluster info
kubectl cluster-info
```

## 📊 Useful One-Liners

```bash
# Get all pod names in namespace
kubectl get pods -n game-2048 -o jsonpath='{.items[*].metadata.name}'

# Get all container images in namespace
kubectl get pods -n game-2048 -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n'

# Get all unhealthy pods
kubectl get pods -A --field-selector=status.phase!=Running

# Get resource requests and limits
kubectl get pods -n game-2048 -o custom-columns=NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory

# Get pod restart count
kubectl get pods -n game-2048 -o custom-columns=NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount

# Force delete stuck pod
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0

# Get all ingress hosts
kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[0].hostname}{"\n"}{end}'

# Get all service endpoints
kubectl get endpoints -A
```

## 🧪 Testing Commands

```bash
# Run all tests
./tests/scenarios/test-rollback.sh
./tests/scenarios/test-blue-green.sh
./tests/scenarios/test-gitops-sync.sh

# Test application endpoint from pod
kubectl exec -n game-2048 deploy/game-2048 -- \
  wget -S --spider http://localhost:80

# Test ingress endpoint
INGRESS_URL=$(kubectl get ingress game-2048 -n game-2048 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I http://${INGRESS_URL}

# Port forward to test locally
kubectl port-forward -n game-2048 deploy/game-2048 8080:80
curl http://localhost:8080
```

## 🔍 Troubleshooting Commands

```bash
# Check ArgoCD sync status
kubectl get application -n argocd

# Check AWS LB Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check Metrics Server
kubectl get deployment metrics-server -n kube-system
kubectl logs -n kube-system -l k8s-app=metrics-server

# Check Argo Rollouts Controller
kubectl get pods -n argo-rollouts
kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts

# Debug pod
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # Previous container logs

# Get pod YAML
kubectl get pod <pod-name> -n <namespace> -o yaml

# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>

# Verify ingress
kubectl describe ingress <ingress-name> -n <namespace>

# Check node conditions
kubectl describe node <node-name> | grep -A 10 Conditions

# Verify IRSA (IAM Roles for Service Accounts)
kubectl describe sa <service-account> -n <namespace>
```

## 📦 Application URLs

```bash
# Get game-2048 URL (standard deployment)
echo "http://$(kubectl get ingress game-2048 -n game-2048 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

# Get game-2048 rollout URL (blue/green production)
echo "http://$(kubectl get ingress game-2048-rollout -n game-2048-rollouts -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

# Get game-2048 rollout preview URL (blue/green preview)
echo "http://$(kubectl get ingress game-2048-rollout-preview -n game-2048-rollouts -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

# ArgoCD UI
echo "https://localhost:8080 (after port-forward)"
```

## 🔐 Secrets Management

```bash
# Get ArgoCD password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d && echo

# List all secrets
kubectl get secrets -A

# Describe secret (without showing values)
kubectl describe secret <secret-name> -n <namespace>

# Get secret value
kubectl get secret <secret-name> -n <namespace> \
  -o jsonpath='{.data.<key>}' | base64 -d
```

## 💰 Cost Monitoring

```bash
# Get node instance types
kubectl get nodes -o custom-columns=NAME:.metadata.name,INSTANCE:.metadata.labels.node\\.kubernetes\\.io/instance-type

# Count pods per namespace
kubectl get pods -A --no-headers | awk '{print $1}' | sort | uniq -c

# Get LoadBalancers (costs money)
kubectl get svc -A --field-selector spec.type=LoadBalancer

# Get persistent volumes (costs money)
kubectl get pv

# Get EBS volumes count
kubectl get pvc -A
```

## 🔄 Common Workflows

### Deploy New Version

```bash
# Option 1: Update Helm chart
helm upgrade game-2048 ./helm-charts/game-2048 -n game-2048

# Option 2: Update image via kubectl
kubectl set image deployment/game-2048 \
  game-2048=public.ecr.aws/l6m2t8p7/docker-2048:v2.0 \
  -n game-2048

# Option 3: GitOps (update Git, ArgoCD syncs automatically)
# 1. Update k8s/game-2048.yaml
# 2. git commit && git push
# 3. ArgoCD syncs within 3 minutes
```

### Rollback Deployment

```bash
# Helm rollback
helm rollback game-2048 -n game-2048

# Kubernetes rollback
kubectl rollout undo deployment/game-2048 -n game-2048

# Argo Rollouts rollback
kubectl argo rollouts undo game-2048-rollout -n game-2048-rollouts

# ArgoCD rollback
argocd app rollback workloads <history-id>
```

### Scale Application

```bash
# Manual scaling
kubectl scale deployment game-2048 --replicas=5 -n game-2048

# Enable HPA (Horizontal Pod Autoscaler)
# Edit values.yaml:
# autoscaling:
#   enabled: true
#   minReplicas: 2
#   maxReplicas: 10
helm upgrade game-2048 ./helm-charts/game-2048 -n game-2048
```

### Blue/Green Deployment

```bash
# 1. Deploy initial version
kubectl apply -f k8s/rollouts/game-2048-rollout.yaml

# 2. Update to new version
kubectl argo rollouts set image game-2048-rollout \
  game-2048=public.ecr.aws/l6m2t8p7/docker-2048:v2.0 \
  -n game-2048-rollouts

# 3. Test preview environment
PREVIEW_URL=$(kubectl get ingress game-2048-rollout-preview -n game-2048-rollouts -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://${PREVIEW_URL}

# 4. Promote to production
kubectl argo rollouts promote game-2048-rollout -n game-2048-rollouts

# 5. If issues, rollback
kubectl argo rollouts abort game-2048-rollout -n game-2048-rollouts
kubectl argo rollouts undo game-2048-rollout -n game-2048-rollouts
```

## 📚 Documentation Links

- **Complete Documentation**: [ASSIGNMENT.md](ASSIGNMENT.md)
- **Quick Start**: [README_NEW.md](README_NEW.md)
- **Submission Checklist**: [SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md)
- **Helm Chart**: [helm-charts/game-2048/](helm-charts/game-2048/)
- **Test Scenarios**: [tests/scenarios/](tests/scenarios/)

## 🆘 Emergency Procedures

### Application Down

```bash
# 1. Check pods
kubectl get pods -n game-2048

# 2. If CrashLoopBackOff, check logs
kubectl logs <pod-name> -n game-2048

# 3. Rollback immediately
kubectl rollout undo deployment/game-2048 -n game-2048

# 4. Verify rollback
kubectl rollout status deployment/game-2048 -n game-2048
```

### Can't Access Application

```bash
# 1. Check ingress
kubectl get ingress game-2048 -n game-2048

# 2. Check service endpoints
kubectl get endpoints game-2048 -n game-2048

# 3. Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# 4. Recreate ingress
kubectl delete ingress game-2048 -n game-2048
kubectl apply -f k8s/game-2048.yaml
```

### Cluster Issues

```bash
# 1. Check nodes
kubectl get nodes

# 2. Check critical pods
kubectl get pods -n kube-system

# 3. Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# 4. SSH to node (if needed)
aws ssm start-session --target <instance-id>
```

## 💡 Pro Tips

1. **Always use namespaces** for resource isolation
2. **Set resource limits** to prevent resource exhaustion
3. **Use health checks** for automatic recovery
4. **Keep revision history** for easy rollbacks
5. **Monitor costs** with AWS Cost Explorer
6. **Use GitOps** for audit trail and rollback capability
7. **Test in preview** before promoting to production
8. **Automate everything** with scripts and pipelines
9. **Document changes** in Git commit messages
10. **Clean up regularly** to avoid unnecessary costs

## 🎯 Best Practices

- ✅ Use specific image tags, not `latest`
- ✅ Define resource requests and limits
- ✅ Implement liveness and readiness probes
- ✅ Use ConfigMaps for configuration
- ✅ Use Secrets for sensitive data
- ✅ Enable RBAC for security
- ✅ Use namespaces for multi-tenancy
- ✅ Implement network policies
- ✅ Enable pod security policies
- ✅ Regular backups with Velero
- ✅ Monitor with CloudWatch/Prometheus
- ✅ Set up alerts for critical events
- ✅ Use CI/CD for automated testing
- ✅ Implement GitOps for declarative config
- ✅ Regular security scanning

---

**Keep this file handy for quick reference!** 📖

