# Nginx Demo Helm Chart

A Helm chart for deploying the Nginx demo application with Argo Rollouts blue/green deployment strategy.

## Prerequisites

- Kubernetes cluster with Argo Rollouts installed
- Helm 3.x
- ArgoCD (for GitOps deployment)

## Installation

### Using Helm CLI

```bash
# Install with default values
helm install nginx-demo ./helm-charts/nginx-demo

# Install with custom values
helm install nginx-demo ./helm-charts/nginx-demo -f my-values.yaml

# Upgrade existing release
helm upgrade nginx-demo ./helm-charts/nginx-demo
```

### Using ArgoCD

The ArgoCD Application should be configured to use Helm:

```yaml
source:
  repoURL: https://github.com/your-org/argo-rollouts-app.git
  targetRevision: main
  path: helm-charts/nginx-demo
  helm:
    valueFiles:
      - values.yaml
```

## Configuration

The chart supports the following values (see `values.yaml` for defaults):

### Application Configuration

- `app.name`: Application name (default: `nginx-demo`)
- `app.image.repository`: Docker image repository
- `app.image.tag`: Docker image tag (set by CI/CD)
- `app.image.pullPolicy`: Image pull policy

### Blue/Green Deployment

- `configMap.name`: ConfigMap to use (`blue` for production, `green` for preview)
- `blueGreen.activeService`: Name of the active service
- `blueGreen.previewService`: Name of the preview service
- `blueGreen.autoPromotionEnabled`: Enable automatic promotion (default: `false`)
- `blueGreen.autoPromotionSeconds`: Seconds before auto-promotion
- `blueGreen.scaleDownDelaySeconds`: Delay before scaling down old replicas

### Rollout Configuration

- `rollout.replicas`: Number of replicas
- `rollout.revisionHistoryLimit`: Number of revisions to keep
- `rollout.progressDeadlineSeconds`: Deadline for rollout progress

### Health Checks

- `healthChecks.livenessProbe.enabled`: Enable liveness probe
- `healthChecks.readinessProbe.enabled`: Enable readiness probe

### Analysis

- `analysis.prePromotion.enabled`: Enable pre-promotion analysis
- `analysis.postPromotion.enabled`: Enable post-promotion analysis

### Ingress

- `ingress.enabled`: Enable ingress for active service
- `ingress.preview.enabled`: Enable ingress for preview service
- `ingress.className`: Ingress class name
- `ingress.annotations`: Ingress annotations

## Values Examples

### Production Deployment

```yaml
configMap:
  name: blue

app:
  image:
    tag: "production-tag"

blueGreen:
  autoPromotionEnabled: false
```

### Preview Deployment

```yaml
configMap:
  name: green

app:
  image:
    tag: "preview-tag"

blueGreen:
  autoPromotionEnabled: false
```

## Updating Image Tag

The image tag is typically updated by the CI/CD pipeline. For manual updates:

```bash
helm upgrade nginx-demo ./helm-charts/nginx-demo \
  --set app.image.tag="new-tag"
```

## Troubleshooting

### Check Rollout Status

```bash
kubectl argo rollouts get rollout nginx-demo -n nginx-demo
```

### Promote Preview to Production

```bash
kubectl argo rollouts promote nginx-demo -n nginx-demo
```

### View Helm Release

```bash
helm list -n nginx-demo
helm get values nginx-demo -n nginx-demo
```

## Chart Structure

```
helm-charts/nginx-demo/
├── Chart.yaml              # Chart metadata
├── values.yaml             # Default values
├── README.md               # This file
└── templates/
    ├── _helpers.tpl        # Template helpers
    ├── namespace.yaml      # Namespace
    ├── configmap-blue.yaml # Blue ConfigMap
    ├── configmap-green.yaml# Green ConfigMap
    ├── service-active.yaml # Active service
    ├── service-preview.yaml# Preview service
    ├── rollout.yaml        # Argo Rollout
    ├── ingress-active.yaml # Active ingress
    ├── ingress-preview.yaml# Preview ingress
    └── analysis-template.yaml # Analysis templates
```

