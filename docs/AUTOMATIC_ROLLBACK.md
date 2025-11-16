# Automatic Rollback Implementation Guide

This document explains the automatic rollback mechanisms implemented in this Argo Rollouts setup.

## Overview

Automatic rollback is implemented at multiple levels to ensure deployments fail fast and rollback safely:

1. **Pod-Level Health Checks** - Kubernetes native health probes
2. **Progress Deadline** - Timeout-based rollback
3. **Pre-Promotion Analysis** - Validate green environment before promotion
4. **Post-Promotion Analysis** - Monitor after promotion and rollback if issues

## Rollback Mechanisms

### 1. Pod Health Checks (Liveness & Readiness Probes)

**Location**: `k8s/rollouts/nginx-demo-rollout.yaml` (lines 79-94)

**How it works**:
- **Liveness Probe**: Checks if the container is running. If it fails 3 times, Kubernetes restarts the pod.
- **Readiness Probe**: Checks if the container is ready to serve traffic. If it fails 3 times, the pod is removed from service endpoints.

**Configuration**:
```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3  # Restart pod after 3 failures

readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3  # Mark pod as not ready after 3 failures
```

**What triggers rollback**:
- Pod crashes or becomes unresponsive
- Application returns non-200 HTTP status codes
- Application takes too long to respond

### 2. Progress Deadline Rollback

**Location**: `k8s/rollouts/nginx-demo-rollout.yaml` (line 61)

**How it works**:
- If the rollout doesn't make progress (pods don't become ready) within the deadline, Argo Rollouts automatically rolls back.

**Configuration**:
```yaml
progressDeadlineSeconds: 300  # 5 minutes
```

**What triggers rollback**:
- New pods fail to become ready within 5 minutes
- Deployment gets stuck in a pending state
- Image pull failures or resource constraints

### 3. Pre-Promotion Analysis

**Location**: 
- Template: `k8s/rollouts/analysis-template.yaml` (nginx-simple-health-check)
- Rollout: `k8s/rollouts/nginx-demo-rollout.yaml` (lines 117-124)

**How it works**:
- Before promoting the green (preview) environment to active, Argo Rollouts runs health checks
- Validates that the green pods are healthy and responding correctly
- Only allows promotion if health checks pass

**Configuration**:
```yaml
prePromotionAnalysis:
  templates:
    - templateName: nginx-simple-health-check
  startingDeadlineSeconds: 300  # Run for up to 5 minutes
```

**What triggers rollback**:
- Green environment fails health checks (HTTP 200 response)
- Health check success rate drops below 80%
- 3 consecutive health check failures

**Analysis Template Details**:
- Runs HTTP checks every 30 seconds
- Requires 80% success rate
- Fails after 3 consecutive failures
- Uses curl jobs to check the preview service endpoint

### 4. Post-Promotion Analysis

**Location**:
- Template: `k8s/rollouts/analysis-template.yaml` (nginx-post-promotion-check)
- Rollout: `k8s/rollouts/nginx-demo-rollout.yaml` (lines 126-135)

**How it works**:
- After promoting green to active, continues monitoring the active service
- If health checks fail, automatically rolls back to the previous revision
- Provides a safety net for issues that only appear under production load

**Configuration**:
```yaml
postPromotionAnalysis:
  templates:
    - templateName: nginx-post-promotion-check
  startingDeadlineSeconds: 300  # Monitor for 5 minutes
  failureCondition: result[0] < 0.8  # Rollback if success rate < 80%
```

**What triggers rollback**:
- Active service health checks fail after promotion
- Success rate drops below 90% (stricter than pre-promotion)
- 3 consecutive health check failures

## Rollback Flow Diagram

```
New Deployment
    ↓
Green Pods Created
    ↓
[Health Checks] → Fail? → Rollback (progressDeadlineSeconds)
    ↓ Pass
[Pre-Promotion Analysis] → Fail? → Block Promotion
    ↓ Pass
Manual Promotion
    ↓
[Post-Promotion Analysis] → Fail? → Automatic Rollback
    ↓ Pass
Deployment Successful
```

## Testing Rollback Scenarios

### Test 1: Pod Health Check Failure

1. Deploy a broken image (e.g., one that crashes on startup)
2. **Expected**: Pod fails liveness probe → Kubernetes restarts it → After 3 failures, `progressDeadlineSeconds` triggers rollback

### Test 2: Pre-Promotion Analysis Failure

1. Deploy a version that returns 500 errors
2. **Expected**: Pre-promotion analysis detects failures → Promotion is blocked → Manual intervention required

### Test 3: Post-Promotion Rollback

1. Promote a version that works initially but fails under load
2. **Expected**: Post-promotion analysis detects failures → Automatic rollback to previous revision

### Test 4: Progress Deadline

1. Deploy an image that takes longer than 5 minutes to start
2. **Expected**: `progressDeadlineSeconds` timeout → Automatic rollback

## Monitoring Rollback Events

### Check Rollout Status
```bash
kubectl argo rollouts get rollout nginx-demo -n nginx-demo
```

### View Analysis Runs
```bash
kubectl get analysisruns -n nginx-demo
kubectl describe analysisrun <analysis-run-name> -n nginx-demo
```

### Check Rollout History
```bash
kubectl argo rollouts history nginx-demo -n nginx-demo
```

### View Rollout Events
```bash
kubectl get events -n nginx-demo --field-selector involvedObject.name=nginx-demo
```

## Customizing Rollback Behavior

### Adjust Health Check Sensitivity

**More Aggressive** (faster rollback):
```yaml
failureLimit: 2  # Fail after 2 failures instead of 3
successCondition: result[0] >= 0.95  # Require 95% instead of 80%
```

**Less Aggressive** (more tolerant):
```yaml
failureLimit: 5  # Allow 5 failures before rollback
successCondition: result[0] >= 0.7  # Require only 70% success
interval: 60s  # Check less frequently
```

### Add Custom Metrics

You can extend the AnalysisTemplate to check:
- Response times
- Error rates from logs
- Custom application metrics
- External service dependencies

Example:
```yaml
metrics:
  - name: response-time
    interval: 30s
    count: 10
    successCondition: result[0] <= 500  # Response time < 500ms
    failureLimit: 3
    provider:
      job:
        spec:
          # Custom check logic
```

## Best Practices

1. **Start Conservative**: Begin with lenient thresholds and tighten them as you learn your application's behavior
2. **Monitor Analysis Runs**: Review analysis run results to understand failure patterns
3. **Test Rollback**: Regularly test rollback scenarios to ensure they work as expected
4. **Combine Mechanisms**: Use multiple rollback mechanisms for defense in depth
5. **Document Thresholds**: Document why you chose specific thresholds for your team

## Troubleshooting

### Analysis Runs Not Starting
- Check if AnalysisTemplate exists: `kubectl get analysistemplate -n nginx-demo`
- Verify template name matches in Rollout spec
- Check Argo Rollouts controller logs: `kubectl logs -n argo-rollouts -l app.kubernetes.io/name=argo-rollouts`

### Rollback Not Triggering
- Verify `progressDeadlineSeconds` is set
- Check if pods are actually failing (not just slow)
- Review analysis run results for failure conditions

### False Positives
- Adjust `successCondition` thresholds
- Increase `failureLimit` to allow more failures
- Extend `interval` to check less frequently

## References

- [Argo Rollouts Documentation](https://argoproj.github.io/argo-rollouts/)
- [Analysis Templates](https://argoproj.github.io/argo-rollouts/features/analysis/)
- [Blue/Green Strategy](https://argoproj.github.io/argo-rollouts/features/bluegreen/)

