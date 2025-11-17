# Helm Migration Guide

This guide explains the migration from Kubernetes manifests to Helm charts.

## What Changed

### Before (Kubernetes Manifests)
- All resources in `k8s/rollouts/nginx-demo-rollout.yaml` (multi-document YAML)
- GitHub Actions updated the Rollout image directly in the YAML
- ArgoCD monitored `k8s/rollouts/` directory

### After (Helm Chart)
- All resources templated in `helm-charts/nginx-demo/templates/`
- Configuration in `helm-charts/nginx-demo/values.yaml`
- GitHub Actions updates `values.yaml` (much simpler!)
- ArgoCD monitors `helm-charts/nginx-demo/` directory

## Migration Steps

### 1. Helm Chart Structure

```
helm-charts/nginx-demo/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Configuration values
├── README.md                     # Chart documentation
└── templates/
    ├── _helpers.tpl              # Template helpers
    ├── namespace.yaml            # Namespace
    ├── configmap-blue.yaml       # Blue ConfigMap
    ├── configmap-green.yaml      # Green ConfigMap
    ├── service-active.yaml       # Active service
    ├── service-preview.yaml      # Preview service
    ├── rollout.yaml              # Argo Rollout
    ├── ingress-active.yaml       # Active ingress
    ├── ingress-preview.yaml      # Preview ingress
    └── analysis-template.yaml    # Analysis templates
```

### 2. ArgoCD Application Update

The ArgoCD Application (`argocd-apps/nginx-gitops-demo.yaml`) has been updated:

```yaml
source:
  repoURL: https://github.com/horaceheaven/argo-rollouts-app.git
  targetRevision: main
  path: helm-charts/nginx-demo    # Changed from k8s/rollouts
  helm:
    valueFiles:
      - values.yaml
```

### 3. GitHub Actions Workflow Update

The workflow now updates `values.yaml` instead of the YAML manifest:

```yaml
GITOPS_PATH: helm-charts/nginx-demo/values.yaml  # Changed from k8s/rollouts/nginx-demo-rollout.yaml
```

The update step is much simpler - just updates the image tag in values.yaml.

### 4. Deployment Process

#### Using Helm CLI (Optional)

```bash
# Install
helm install nginx-demo ./helm-charts/nginx-demo

# Upgrade with new image tag
helm upgrade nginx-demo ./helm-charts/nginx-demo \
  --set app.image.tag="new-sha"

# View values
helm get values nginx-demo
```

#### Using ArgoCD (Recommended)

ArgoCD will automatically:
1. Monitor the Helm chart directory
2. Render templates using values.yaml
3. Apply changes when values.yaml is updated
4. Sync the application

## Benefits of Helm Migration

1. **Simpler Updates**: Updating `values.yaml` is much easier than parsing multi-document YAML
2. **Configuration Management**: All config in one place (`values.yaml`)
3. **Template Reusability**: Helm templates reduce duplication
4. **Meets Requirement**: Fulfills the "Develop a helm chart" requirement
5. **Better Organization**: Clear separation of templates and values

## Configuration

### Key Values

- `app.image.repository`: Docker image repository
- `app.image.tag`: Docker image tag (updated by CI/CD)
- `configMap.name`: Which ConfigMap to use (`blue` or `green`)
- `blueGreen.autoPromotionEnabled`: Auto-promotion setting
- `rollout.replicas`: Number of replicas
- `ingress.enabled`: Enable/disable ingress

### Switching Between Blue/Green

To switch ConfigMap for new deployments:

```yaml
# In values.yaml
configMap:
  name: green  # or "blue" for production
```

## Rollback Plan

If you need to rollback to Kubernetes manifests:

1. Revert ArgoCD Application to use `k8s/rollouts/` path
2. Revert GitHub Actions workflow to update YAML manifest
3. The old manifests in `k8s/rollouts/` are still available

## Next Steps

1. **Test the Helm Chart**: 
   ```bash
   helm template nginx-demo ./helm-charts/nginx-demo
   ```

2. **Update ArgoCD Application**:
   ```bash
   kubectl apply -f argocd-apps/nginx-gitops-demo.yaml
   ```

3. **Trigger a Build**: Push changes to trigger GitHub Actions

4. **Verify Deployment**: Check ArgoCD sync status

## Troubleshooting

### ArgoCD Not Syncing

- Check if the path is correct: `helm-charts/nginx-demo`
- Verify `values.yaml` exists in the chart directory
- Check ArgoCD application logs

### Helm Template Errors

```bash
# Validate chart
helm lint ./helm-charts/nginx-demo

# Dry-run render
helm template nginx-demo ./helm-charts/nginx-demo
```

### Image Tag Not Updating

- Verify GitHub Actions workflow updated `values.yaml`
- Check ArgoCD is monitoring the correct path
- Ensure ArgoCD auto-sync is enabled

## Notes

- The old `k8s/rollouts/` directory is kept for reference
- Analysis templates are now part of the Helm chart
- ConfigMap HTML is generated from templates (easier to maintain)
- Git hash is displayed using `{{ .Values.app.image.tag }}` in templates

