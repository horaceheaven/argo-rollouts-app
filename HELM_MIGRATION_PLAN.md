# Helm Migration Plan for Blue/Green Deployment

## Current Architecture Issues

### Problem
- Rollout template uses a single ConfigMap (`nginx-blue` or `nginx-green`)
- Both blue and green revisions use the same template
- When ConfigMap is updated, it affects both environments
- Production showed Version 3.0 because it was using `nginx-green` ConfigMap

### Root Cause
Argo Rollouts uses a single pod template for both blue and green revisions. The template references one ConfigMap, so both environments share the same ConfigMap content.

## Helm Solution Benefits

### ✅ Advantages
1. **Meets Requirements**: Fulfills "Develop a helm chart to deploy the application"
2. **Parameterization**: Use `values.yaml` to configure ConfigMap selection
3. **Better Organization**: Separate templates, values, and configuration
4. **Flexibility**: Easy to override values for different environments
5. **Maintainability**: Cleaner structure for complex applications

### ⚠️ Considerations
- Still uses single Rollout template (same architectural constraint)
- Would need strategy for ConfigMap selection
- Adds Helm chart maintenance overhead

## Recommended Helm Architecture

### Structure
```
helm-charts/nginx-demo/
├── Chart.yaml
├── values.yaml
├── values-blue.yaml      # Production values
├── values-green.yaml     # Preview values (optional)
└── templates/
    ├── namespace.yaml
    ├── configmap-blue.yaml
    ├── configmap-green.yaml
    ├── service.yaml
    ├── service-preview.yaml
    ├── rollout.yaml
    └── ingress.yaml
```

### Strategy Options

#### Option A: Single Rollout with ConfigMap Parameter (Current Issue Persists)
- Use `{{ .Values.configMapName }}` in rollout template
- Still has the same problem - both revisions use same ConfigMap

#### Option B: Two Separate Rollouts (Recommended)
- `nginx-demo-blue` Rollout (production)
- `nginx-demo-green` Rollout (preview)
- Each uses its own ConfigMap
- Services switch between them during promotion
- More complex but properly separates blue/green

#### Option C: Dynamic ConfigMap Update (Complex)
- Use Helm hooks or scripts to update ConfigMap reference
- Requires custom logic during promotion

## Implementation Recommendation

### Hybrid Approach (Best of Both Worlds)

1. **Create Helm Chart** for the application
2. **Use Argo Rollouts** for blue/green (keep current approach)
3. **Fix ConfigMap Strategy**:
   - Keep `nginx-blue` for production (Version 2.0.0)
   - Keep `nginx-green` for preview (Version 3.0.0)
   - Update rollout template to use `nginx-blue` by default
   - When creating new preview, temporarily switch template to `nginx-green`
   - After promotion, switch back to `nginx-blue` and update `nginx-blue` content

### Simpler Alternative

Use a **single ConfigMap** that gets updated:
- `nginx-config` ConfigMap
- Update content when promoting
- Simpler but loses visual distinction between environments

## Migration Steps (If Proceeding)

1. Create Helm chart structure
2. Move Kubernetes manifests to `templates/`
3. Extract configuration to `values.yaml`
4. Update ArgoCD Application to use Helm
5. Test deployment
6. Update documentation

## Recommendation

**For this use case**: Keep current approach but fix the ConfigMap strategy.

**Reasons**:
- Current setup is simpler and works well
- Helm adds complexity without solving the core issue
- The ConfigMap problem can be fixed with better strategy
- Argo Rollouts blue/green works fine with current manifests

**However**, if you need to meet the "Helm chart" requirement:
- Create a Helm chart (meets requirement)
- Use it to deploy the same Rollout resource
- Keep the blue/green strategy as-is

