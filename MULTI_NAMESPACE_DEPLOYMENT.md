# Bookstore Multi-Namespace Kubernetes Deployment

## Overview

This deployment uses a **multi-namespace architecture** to separate application components for better isolation, security, and scalability. Each component runs in its own namespace:

- **bookstore-frontend** - Nginx web server serving the frontend
- **bookstore-backend** - Node.js Express API server
- **bookstore-database** - MySQL and Redis data stores

## Architecture

```
┌─────────────────────────────────────────────┐
│        Kubernetes Cluster                   │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────────┐  ┌──────────────────┐│
│  │ bookstore-frontend  │  │ bookstore-backend ││
│  ├──────────────────┤  ├──────────────────┤│
│  │ Namespace        │  │ Namespace        ││
│  │ - Nginx (2 pods) │  │ - Node.js (2)    ││
│  │ - ConfigMap      │  │ - ConfigMap      ││
│  │ - Route/Ingress  │  │ - Secret         ││
│  └──────────────────┘  │ - Route/Ingress  ││
│           ↕                    ↕          │
│           └────┬─────────────┬────┘        │
│                │             │             │
│  ┌─────────────────────────────────────────┐│
│  │   bookstore-database Namespace          ││
│  ├─────────────────────────────────────────┤│
│  │ - MySQL StatefulSet (1 pod)            ││
│  │ - Redis Deployment (1 pod)             ││
│  │ - PersistentVolumeClaims               ││
│  │ - Secrets (credentials)                ││
│  │ - ConfigMap (init scripts)             ││
│  └─────────────────────────────────────────┘│
│                                             │
└─────────────────────────────────────────────┘
```

## Directory Structure

```
k8s/
├── base/
│   ├── kustomization.yaml          # Root kustomization combining all namespaces
│   │
│   ├── frontend/
│   │   ├── namespace.yaml           # bookstore-frontend namespace
│   │   ├── configmap.yaml           # Frontend configuration
│   │   ├── deployment.yaml          # Nginx deployment
│   │   ├── route.yaml               # OpenShift route/Ingress
│   │   └── kustomization.yaml       # Frontend kustomization
│   │
│   ├── backend/
│   │   ├── namespace.yaml           # bookstore-backend namespace
│   │   ├── configmap.yaml           # Backend configuration
│   │   ├── secret.yaml              # Database credentials
│   │   ├── deployment.yaml          # Node.js deployment
│   │   ├── route.yaml               # OpenShift route/Ingress
│   │   └── kustomization.yaml       # Backend kustomization
│   │
│   └── database/
│       ├── namespace.yaml           # bookstore-database namespace
│       ├── secret.yaml              # Database credentials
│       ├── mysql-init-configmap.yaml # MySQL init scripts
│       ├── pvc.yaml                 # PersistentVolumeClaims
│       ├── mysql-deployment.yaml    # MySQL StatefulSet
│       ├── redis-deployment.yaml    # Redis deployment
│       └── kustomization.yaml       # Database kustomization
│
└── deploy.sh                        # Deployment automation script
```

## Service Discovery Between Namespaces

Services in different namespaces use Kubernetes fully-qualified domain names (FQDN):

```
<service-name>.<namespace>.svc.cluster.local
```

### Example Connections

**Frontend → Backend:**
```yaml
API_URL: http://backend.bookstore-backend.svc.cluster.local:3000
```

**Backend → MySQL:**
```yaml
DB_HOST: mysql.bookstore-database.svc.cluster.local
```

**Backend → Redis:**
```yaml
REDIS_HOST: redis.bookstore-database.svc.cluster.local
```

## Deployment

### Prerequisites
- Kubernetes 1.19+
- Kustomize 3.2+
- kubectl configured
- PersistentVolume support (or cloud provider provisioning)
- Container images pushed to registry (ghcr.io/abdulftah/bookstore-*)

### Deploy All Namespaces

```bash
# Deploy using kustomize
kubectl apply -k k8s/base/

# Or deploy individual namespaces
kubectl apply -k k8s/base/database/
kubectl apply -k k8s/base/backend/
kubectl apply -k k8s/base/frontend/
```

### Deploy Using Script

```bash
cd k8s
chmod +x deploy.sh
./deploy.sh
```

## Verification

### Check Namespace Creation
```bash
kubectl get namespaces | grep bookstore
# Output:
# bookstore-database    Active   1m
# bookstore-backend     Active   1m
# bookstore-frontend    Active   1m
```

### Check Pod Status
```bash
# Database namespace
kubectl get pods -n bookstore-database
# Expected: mysql-0 (Running), redis-0 (Running)

# Backend namespace
kubectl get pods -n bookstore-backend
# Expected: backend-* (2 pods, Running)

# Frontend namespace
kubectl get pods -n bookstore-frontend
# Expected: frontend-* (2 pods, Running)
```

### Check Service Connectivity
```bash
# Test from backend pod to database
kubectl exec -it -n bookstore-backend deployment/backend -- \
  curl http://mysql.bookstore-database.svc.cluster.local:3306

# Test from frontend pod to backend
kubectl exec -it -n bookstore-frontend deployment/frontend -- \
  curl http://backend.bookstore-backend.svc.cluster.local:3000/api/health
```

### View Database Initialization
```bash
kubectl logs -n bookstore-database -l app=mysql -f
```

## Database Details

### MySQL
- **Service**: `mysql.bookstore-database.svc.cluster.local:3306`
- **Database**: `bookstore`
- **StatefulSet**: 1 replica
- **Storage**: 10Gi PVC
- **Credentials**: Stored in `database-secret`
- **Init Scripts**: Loaded from `mysql-init-configmap.yaml`

### Redis
- **Service**: `redis.bookstore-database.svc.cluster.local:6379`
- **Deployment**: 1 replica
- **Storage**: 5Gi PVC
- **AOF Persistence**: Enabled

### Sample Data
The MySQL initialization script includes 8 sample books:
1. The Pragmatic Programmer
2. Clean Code
3. Design Patterns
4. Kubernetes in Action
5. Docker Deep Dive
6. OpenShift for Developers
7. Site Reliability Engineering
8. The DevOps Handbook

## Configuration Management

### Updating Configuration

**Frontend Settings:**
```bash
kubectl edit configmap frontend-config -n bookstore-frontend
```

**Backend Settings:**
```bash
kubectl edit configmap backend-config -n bookstore-backend
kubectl edit secret database-secret -n bookstore-backend
```

**Database Credentials:**
```bash
kubectl edit secret database-secret -n bookstore-database
```

### Restarting Services After Configuration Changes

```bash
# Frontend
kubectl rollout restart deployment/frontend -n bookstore-frontend

# Backend
kubectl rollout restart deployment/backend -n bookstore-backend

# Database (if needed)
kubectl rollout restart statefulset/mysql -n bookstore-database
```

## Scaling

### Scale Frontend
```bash
kubectl scale deployment/frontend --replicas=3 -n bookstore-frontend
```

### Scale Backend
```bash
kubectl scale deployment/backend --replicas=4 -n bookstore-backend
```

### Scale Database (if using ReplicaSet instead of StatefulSet)
```bash
# Note: MySQL StatefulSet should have replicas=1 for single-leader setup
# Use multi-master setups for production HA
```

## Network Policies

To enable network policies for namespace isolation:

```bash
# Deny all traffic by default
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: bookstore-database
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-backend
  namespace: bookstore-database
spec:
  podSelector:
    matchLabels:
      app: mysql
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: bookstore-backend
EOF
```

## Troubleshooting

### Database Connection Failed
```bash
# Check MySQL logs
kubectl logs -n bookstore-database -l app=mysql -f

# Test connectivity from backend
kubectl exec -it -n bookstore-backend deployment/backend -- \
  telnet mysql.bookstore-database.svc.cluster.local 3306
```

### Backend API Not Accessible
```bash
# Check backend logs
kubectl logs -n bookstore-backend -l app=backend --all-containers=true -f

# Test health endpoint
kubectl exec -it -n bookstore-frontend deployment/frontend -- \
  curl http://backend.bookstore-backend.svc.cluster.local:3000/api/health
```

### Frontend Not Loading
```bash
# Check Nginx logs
kubectl logs -n bookstore-frontend -l app=frontend -f

# Check routing
kubectl get routes -n bookstore-frontend
```

### PersistentVolume Issues
```bash
# Check PVC status
kubectl get pvc -n bookstore-database

# Describe problematic PVC
kubectl describe pvc mysql-pvc -n bookstore-database
```

## Production Considerations

### High Availability
- Frontend: Scale to 2+ replicas behind load balancer
- Backend: Scale to 2+ replicas behind load balancer
- Database: Use MySQL Galera Cluster or InnoDB ReplicaSet for HA

### Security
- Enable RBAC policies per namespace
- Implement network policies for zero-trust networking
- Rotate credentials regularly
- Use sealed secrets or external secret manager

### Monitoring
- Deploy Prometheus for metrics collection
- Deploy Grafana for visualization
- Deploy ELK/Loki for centralized logging
- Set up alerts for critical issues

### Backups
- MySQL: Schedule automated backups to object storage
- Redis: Ensure AOF persistence enabled
- Use Velero or similar for full cluster backups

## Clean Up

### Delete Entire Multi-Namespace Deployment
```bash
kubectl delete -k k8s/base/
```

### Delete Specific Namespace
```bash
kubectl delete namespace bookstore-frontend
```

## CI/CD Integration

The GitHub Actions workflow (`.github/workflows/ci-cd.yml`) automatically deploys to all three namespaces:

1. Builds container images
2. Scans with Trivy for vulnerabilities
3. Pushes to GitHub Container Registry
4. Deploys to Kubernetes clusters
5. Generates security reports

See `.github/GITHUB_ACTIONS_SETUP.md` for detailed CI/CD configuration.

## References

- [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [Kustomize](https://kustomize.io/)
- [OpenShift Routes](https://docs.openshift.com/container-platform/4.8/networking/routes/route-configuration.html)
- [StatefulSet Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [PersistentVolumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
