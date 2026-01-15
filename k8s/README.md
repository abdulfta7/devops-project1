# Kubernetes Deployment Guide

This directory contains Kubernetes manifests for deploying the Bookstore application to OpenShift/Kubernetes using Kustomize.

## Project Structure

```
k8s/
├── base/                              # Base configurations
│   ├── kustomization.yaml             # Main kustomization file
│   ├── namespace.yaml                 # Bookstore namespace
│   ├── configmap.yaml                 # Application configuration
│   ├── secret.yaml                    # Database credentials
│   ├── pvc.yaml                       # Persistent volumes
│   ├── mysql-init-configmap.yaml      # Database initialization
│   ├── mysql-deployment.yaml          # MySQL StatefulSet
│   ├── redis-deployment.yaml          # Redis Deployment
│   ├── backend-deployment.yaml        # Backend application
│   ├── frontend-deployment.yaml       # Frontend (Nginx)
│   └── route.yaml                     # OpenShift Routes
└── README.md                          # This file
```

## Prerequisites

- OpenShift cluster (4.x or later) or Kubernetes 1.20+
- `oc` CLI or `kubectl` CLI
- `kustomize` CLI (optional, `oc apply -k` works without it)
- Access to container images (GitHub Container Registry)

## Quick Start

### 1. Login to OpenShift/Kubernetes

```bash
# OpenShift
oc login <cluster-url>

# Or Kubernetes
kubectl config use-context <context-name>
```

### 2. Deploy Using Kustomize

**Option A: Using oc (OpenShift)**
```bash
oc apply -k k8s/base/
```

**Option B: Using kubectl**
```bash
kubectl apply -k k8s/base/
```

**Option C: Using kustomize CLI**
```bash
kustomize build k8s/base/ | kubectl apply -f -
```

### 3. Verify Deployment

```bash
# Check namespace
kubectl get namespace bookstore

# Check all resources
kubectl get all -n bookstore

# Check pods
kubectl get pods -n bookstore -w

# Check services
kubectl get svc -n bookstore

# Check routes (OpenShift only)
oc get routes -n bookstore
```

### 4. Wait for All Pods to be Ready

```bash
# MySQL (StatefulSet)
kubectl rollout status statefulset/mysql -n bookstore

# Backend
kubectl rollout status deployment/backend -n bookstore

# Frontend
kubectl rollout status deployment/frontend -n bookstore
```

### 5. Access the Application

**OpenShift (via Routes):**
```bash
# Get frontend URL
oc get route bookstore -n bookstore -o jsonpath='{.spec.host}'

# Get API URL
oc get route bookstore-api -n bookstore -o jsonpath='{.spec.host}'
```

**Kubernetes (via Port Forward):**
```bash
# Forward frontend
kubectl port-forward -n bookstore svc/frontend 8080:80

# Forward backend
kubectl port-forward -n bookstore svc/backend 3000:3000

# Access: http://localhost:8080
```

## Configuration

### Update Container Images

Edit `k8s/base/kustomization.yaml`:

```yaml
images:
  - name: ghcr.io/your-org/bookstore/backend
    newName: ghcr.io/your-username/bookstore/backend
    newTag: v1.0
  - name: ghcr.io/your-org/bookstore/frontend
    newName: ghcr.io/your-username/bookstore/frontend
    newTag: v1.0
```

### Update Route Hosts

Edit `k8s/base/route.yaml`:

```yaml
spec:
  host: bookstore.apps.your-domain.com
```

### Change Replicas

Edit `k8s/base/kustomization.yaml`:

```yaml
replicas:
  - name: backend
    count: 3  # Increase to 3
  - name: frontend
    count: 3  # Increase to 3
```

### Update Database Credentials

Edit `k8s/base/secret.yaml`:

```yaml
stringData:
  DB_USER: your_user
  DB_PASSWORD: your_secure_password
  MYSQL_ROOT_PASSWORD: your_root_password
  MYSQL_USER: your_user
  MYSQL_PASSWORD: your_secure_password
```

## Troubleshooting

### Check Pod Logs

```bash
# Backend logs
kubectl logs -n bookstore -l app=backend -f

# Frontend logs
kubectl logs -n bookstore -l app=frontend -f

# MySQL logs
kubectl logs -n bookstore -l app=mysql -f

# Redis logs
kubectl logs -n bookstore -l app=redis -f
```

### Describe Resources

```bash
# Get pod details
kubectl describe pod <pod-name> -n bookstore

# Get deployment details
kubectl describe deployment backend -n bookstore
```

### Check Events

```bash
# Get cluster events
kubectl get events -n bookstore --sort-by='.lastTimestamp'
```

### MySQL Connection Issues

```bash
# Test MySQL connection
kubectl exec -it mysql-0 -n bookstore -- \
  mysql -u bookstore -pbookstore123 -e "SELECT 1"

# Check MySQL status
kubectl exec -it mysql-0 -n bookstore -- \
  mysql -u root -proot123 -e "SHOW DATABASES;"
```

### Backend Connection Issues

```bash
# Test backend health
kubectl port-forward -n bookstore svc/backend 3000:3000 &
curl http://localhost:3000/api/health

# Test from inside pod
kubectl exec -it deployment/backend -n bookstore -- \
  curl http://mysql:3306 || echo "MySQL accessible"
```

## Scaling

### Manual Scaling

```bash
# Scale backend to 3 replicas
kubectl scale deployment backend -n bookstore --replicas=3

# Scale frontend to 3 replicas
kubectl scale deployment frontend -n bookstore --replicas=3
```

### Horizontal Pod Autoscaling

Create `k8s/base/hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: bookstore
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

Then apply: `kubectl apply -k k8s/base/`

## Persistence

### Database Persistence

- MySQL uses StatefulSet with persistent storage
- Data stored in `/var/lib/mysql` on 10Gi volume
- Automatic cleanup on pod restart

### Redis Persistence

- Redis configured with AOF (Append Only File)
- Data stored in `/data` on 5Gi volume
- Survives pod restarts

## Security

### Network Policies (Optional)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: bookstore-network-policy
  namespace: bookstore
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    - podSelector:
        matchLabels:
          app: mysql
```

### Resource Limits

All containers have defined resource requests and limits to prevent resource exhaustion.

### Security Context

Containers run as non-root users with limited capabilities.

## Cleanup

### Delete All Resources

```bash
# Using kustomize
oc delete -k k8s/base/

# Or kubectl
kubectl delete -k k8s/base/
```

### Delete Only Application (Keep Data)

```bash
kubectl delete deployment,service -l app=bookstore -n bookstore
```

## Advanced Usage

### Custom Overlays (Development, Staging, Production)

Create separate overlay directories:

```bash
k8s/
├── base/              # Common configuration
├── overlays/
│   ├── dev/           # Development overrides
│   ├── staging/       # Staging overrides
│   └── prod/          # Production overrides
```

Example `k8s/overlays/prod/kustomization.yaml`:

```yaml
bases:
  - ../../base

namePrefix: prod-

replicas:
  - name: backend
    count: 3
  - name: frontend
    count: 3

images:
  - name: ghcr.io/your-org/bookstore/backend
    newTag: v1.0.0
```

Deploy to production:
```bash
kubectl apply -k k8s/overlays/prod/
```

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Docker Image Reference](https://hub.docker.com/)

## Support

For issues:
1. Check pod logs: `kubectl logs <pod> -n bookstore`
2. Describe pod: `kubectl describe pod <pod> -n bookstore`
3. Check events: `kubectl get events -n bookstore`
4. Review resource manifests for configuration errors
