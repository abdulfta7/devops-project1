# Kubernetes Overlays Documentation

## Overview

Kustomize overlays provide environment-specific customizations on top of the base deployment. This project includes security, autoscaling, and environment-specific overlays.

## Directory Structure

```
k8s/
├── base/                      # Base deployment (3 namespaces)
│
├── overlays/
│   ├── security/             # Security hardening
│   │   ├── network-policies.yaml
│   │   ├── pod-security.yaml
│   │   ├── resource-quotas.yaml
│   │   └── kustomization.yaml
│   │
│   ├── autoscaling/          # HPA and PDB
│   │   ├── hpa.yaml
│   │   ├── pdb.yaml
│   │   └── kustomization.yaml
│   │
│   ├── production/           # Production (base + security + autoscaling)
│   │   └── kustomization.yaml
│   │
│   └── development/          # Development (base + autoscaling only)
│       └── kustomization.yaml
```

## Overlay Descriptions

### Base (`k8s/base/`)
- Three separate namespaces: frontend, backend, database
- MySQL StatefulSet, Redis Deployment
- Frontend and Backend Deployments (2 replicas each)
- ConfigMaps and Secrets
- Basic health checks and resource requests

**Use when**: Testing individual components

---

### Security Overlay (`k8s/overlays/security/`)

#### Network Policies (`network-policies.yaml`)
- **Default deny all ingress**: Only explicitly allowed traffic enters
- **Frontend → Backend**: Frontend can access backend API on port 3000
- **Backend → Database**: Backend can access MySQL (3306) and Redis (6379)
- **DNS access**: All pods can query DNS (port 53)
- **Ingress controller access**: Allows external ingress to frontend/backend

#### Pod Security (`pod-security.yaml`)
- **Pod Security Standards**: Restricted profiles for frontend/backend, baseline for database
- **RBAC**: ServiceAccounts and Roles for each component
- **Least privilege**: Only read access to ConfigMaps/Secrets

#### Resource Quotas (`resource-quotas.yaml`)
- **Per-namespace limits**: CPU, memory, pod count restrictions
- **LimitRanges**: Default requests/limits for containers
- **Storage quotas**: PVC size limits for database namespace

---

### Autoscaling Overlay (`k8s/overlays/autoscaling/`)

#### Horizontal Pod Autoscaler (`hpa.yaml`)
- **Frontend HPA**
  - Min replicas: 2
  - Max replicas: 5
  - Targets: 70% CPU, 80% memory utilization
  
- **Backend HPA**
  - Min replicas: 2
  - Max replicas: 8
  - Targets: 75% CPU, 85% memory utilization

#### Pod Disruption Budget (`pdb.yaml`)
- Ensures minimum availability during node drains/maintenance
- Frontend: At least 1 pod available
- Backend: At least 1 pod available
- MySQL: 1 pod available (StatefulSet stability)
- Redis: 1 pod available (cache consistency)

---

### Production Overlay (`k8s/overlays/production/`)

Combines:
- ✅ Base deployment
- ✅ Security hardening (network policies, RBAC, pod security)
- ✅ Autoscaling (HPA, PDB)
- ✅ Resource quotas and limits

**Environment**: production
**Security**: Restricted
**Scaling**: Enabled

```bash
kubectl apply -k k8s/overlays/production/
```

---

### Development Overlay (`k8s/overlays/development/`)

Combines:
- ✅ Base deployment
- ✅ Autoscaling (HPA, PDB)
- ❌ Security restrictions removed
- ✅ Dev image tags (`dev` instead of `latest`)

**Environment**: development
**Security**: Basic
**Scaling**: Enabled (allows rapid iteration)

```bash
kubectl apply -k k8s/overlays/development/
```

---

## Deployment Scenarios

### Scenario 1: Test Basic Setup
```bash
# Deploy just base (no security, no autoscaling)
kubectl apply -k k8s/base/
```

### Scenario 2: Development Environment
```bash
# Deploy with autoscaling but no security restrictions
kubectl apply -k k8s/overlays/development/
```

### Scenario 3: Production Deployment
```bash
# Deploy with security hardening and autoscaling
kubectl apply -k k8s/overlays/production/
```

### Scenario 4: Security Only (Manual Scaling)
```bash
# Deploy base + security overlay only
kubectl apply -k k8s/base/
kubectl apply -k k8s/overlays/security/
```

### Scenario 5: Autoscaling Only (Open Network)
```bash
# Deploy base + autoscaling overlay only
kubectl apply -k k8s/base/
kubectl apply -k k8s/overlays/autoscaling/
```

---

## Feature Comparison

| Feature | Base | Security | Autoscaling | Dev Overlay | Prod Overlay |
|---------|------|----------|-------------|-------------|--------------|
| 3 Namespaces | ✅ | ✅ | ✅ | ✅ | ✅ |
| Network Policies | ❌ | ✅ | ❌ | ❌ | ✅ |
| RBAC/Pod Security | ❌ | ✅ | ❌ | ❌ | ✅ |
| Resource Quotas | ❌ | ✅ | ❌ | ❌ | ✅ |
| HPA | ❌ | ❌ | ✅ | ✅ | ✅ |
| Pod Disruption Budget | ❌ | ❌ | ✅ | ✅ | ✅ |
| Security Focus | ❌ | ✅ | ❌ | ❌ | ✅ |
| For Production | ⚠️ | ⚠️ | ⚠️ | ❌ | ✅ |

---

## Network Policy Details

### Frontend Namespace
- ✅ Accept: Ingress controller traffic on port 80
- ❌ Deny: All other ingress
- ✅ Allow: Egress to backend (DNS + port 3000)

### Backend Namespace
- ✅ Accept: Frontend traffic on port 3000
- ✅ Accept: Ingress controller on port 3000
- ✅ Allow: Egress to database (MySQL 3306, Redis 6379)
- ✅ Allow: DNS queries

### Database Namespace
- ✅ Accept: Backend traffic on MySQL (3306) and Redis (6379)
- ❌ Deny: All other ingress
- ✅ Allow: DNS queries
- ✅ Allow: Internal pod-to-pod communication

---

## Resource Quotas

### Frontend Namespace
- CPU requests: 2
- Memory requests: 2Gi
- CPU limits: 4
- Memory limits: 4Gi
- Max pods: 10
- PVCs: 0 (no persistent storage)

### Backend Namespace
- CPU requests: 2
- Memory requests: 2Gi
- CPU limits: 4
- Memory limits: 4Gi
- Max pods: 10
- PVCs: 0 (no persistent storage)

### Database Namespace
- CPU requests: 2
- Memory requests: 2Gi
- CPU limits: 4
- Memory limits: 4Gi
- Max pods: 5
- PVCs: 2 (MySQL + Redis)
- Storage: 20Gi

---

## HPA Behavior

### Frontend Autoscaler
**Scale Up** (Fast):
- Every 30s: increase 100% (double) or 1 pod
- Target: 70% CPU or 80% memory

**Scale Down** (Conservative):
- Every 60s after 5min stable: decrease 50%
- Prevents thrashing

**Replicas**: 2 → 5

### Backend Autoscaler
**Scale Up** (Moderate):
- Every 30s: increase 50% or 2 pods
- Target: 75% CPU or 85% memory

**Scale Down** (Conservative):
- Every 60s after 5min stable: decrease 25%

**Replicas**: 2 → 8

---

## Verification Commands

### Check Overlay Contents
```bash
# View what will be deployed
kubectl kustomize k8s/overlays/production/

# Count resources
kubectl kustomize k8s/overlays/production/ | grep "kind:" | sort | uniq -c
```

### Check Network Policies
```bash
kubectl get networkpolicies -A
kubectl describe networkpolicy allow-frontend-to-backend -n bookstore-backend
```

### Check RBAC
```bash
kubectl get roles -A -l app=bookstore
kubectl get rolebindings -A -l app=bookstore
kubectl get serviceaccounts -A -l app=bookstore
```

### Check Autoscaling
```bash
# View HPA status
kubectl get hpa -n bookstore-frontend
kubectl get hpa -n bookstore-backend
kubectl describe hpa frontend-hpa -n bookstore-frontend

# View current replicas
kubectl get deployments -n bookstore-frontend
kubectl get deployments -n bookstore-backend
```

### Check Resource Quotas
```bash
kubectl describe quota -n bookstore-frontend
kubectl describe quota -n bookstore-backend
kubectl describe quota -n bookstore-database
```

### Monitor Scaling Activity
```bash
# Watch HPA in real-time
kubectl get hpa -n bookstore-frontend --watch

# View events
kubectl get events -n bookstore-frontend --sort-by='.lastTimestamp'
```

---

## Troubleshooting

### Network Policy Too Restrictive
**Symptom**: Pods can't communicate
**Solution**: 
```bash
# Temporarily remove network policies
kubectl delete networkpolicies -A -l app=bookstore

# Or check which policies are blocking traffic
kubectl logs -f deployment/calico-typha -n calico-system
```

### HPA Not Scaling
**Symptom**: Replicas stay at minReplicas despite high load
**Check metrics server**:
```bash
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
kubectl top pods -n bookstore-backend
```

**Check HPA status**:
```bash
kubectl describe hpa backend-hpa -n bookstore-backend
# Look for "Current CPU/memory utilization"
```

### Resource Quota Exceeded
**Symptom**: New pods fail to schedule
**Check usage**:
```bash
kubectl describe quota -n bookstore-backend
# Look for "Used" vs "Hard" limits
```

### RBAC Permission Denied
**Symptom**: Pods can't read ConfigMaps/Secrets
**Check**:
```bash
kubectl auth can-i get configmaps --as=system:serviceaccount:bookstore-backend:backend -n bookstore-backend
kubectl get rolebinding -n bookstore-backend
```

---

## Migration Path

### From Base to Production
```bash
# 1. Start with base
kubectl apply -k k8s/base/

# 2. Wait for everything to be stable
kubectl rollout status deployment/frontend -n bookstore-frontend
kubectl rollout status deployment/backend -n bookstore-backend

# 3. Apply security overlay
kubectl apply -k k8s/overlays/security/

# 4. Apply autoscaling overlay
kubectl apply -k k8s/overlays/autoscaling/

# 5. Or directly apply production overlay
kubectl apply -k k8s/overlays/production/
```

### Rollback from Production
```bash
# Remove production overlay
kubectl delete -k k8s/overlays/production/

# Redeploy base
kubectl apply -k k8s/base/
```

---

## Best Practices

### ✅ DO
- Use **production overlay** for production clusters
- Use **development overlay** for dev/test clusters
- Review network policies before applying to existing clusters
- Monitor HPA metrics after enabling autoscaling
- Test overlays in dev before applying to production

### ❌ DON'T
- Skip resource quotas in shared clusters
- Use production overlay in development (too restrictive)
- Disable network policies in production
- Set HPA min/max replicas without load testing
- Ignore PDB violations during scaling

---

## References

- [Kustomize Documentation](https://kustomize.io/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Pod Disruption Budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
