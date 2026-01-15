# Kubernetes Deployment Quick Reference

## 📁 Created Files

```
k8s/
├── base/
│   ├── kustomization.yaml              ← Main configuration file
│   ├── namespace.yaml                  ← Bookstore namespace
│   ├── configmap.yaml                  ← App configuration
│   ├── secret.yaml                     ← Database credentials
│   ├── pvc.yaml                        ← Persistent volumes
│   ├── mysql-init-configmap.yaml       ← Database init script
│   ├── mysql-deployment.yaml           ← MySQL StatefulSet (1 replica)
│   ├── redis-deployment.yaml           ← Redis cache (1 replica)
│   ├── backend-deployment.yaml         ← Backend API (2 replicas)
│   ├── frontend-deployment.yaml        ← Frontend Nginx (2 replicas)
│   └── route.yaml                      ← OpenShift Routes
├── deploy.sh                           ← Automated deployment script
└── README.md                           ← Full deployment guide
```

## 🚀 Quick Deployment

### Option 1: Automated Script (Recommended)
```bash
cd k8s
./deploy.sh
```

### Option 2: Manual Deployment
```bash
# OpenShift
oc apply -k k8s/base/

# Kubernetes
kubectl apply -k k8s/base/
```

## ✅ Verification

```bash
# Check all resources
kubectl get all -n bookstore

# Check specific services
kubectl get svc -n bookstore
kubectl get pods -n bookstore

# View logs
kubectl logs -n bookstore -l app=backend -f
```

## 🔧 Configuration

### Update Container Images
Edit `k8s/base/kustomization.yaml`:
```yaml
images:
  - name: ghcr.io/your-org/bookstore/backend
    newTag: v1.0
  - name: ghcr.io/your-org/bookstore/frontend
    newTag: v1.0
```

### Update Route Hosts (OpenShift)
Edit `k8s/base/route.yaml`:
```yaml
host: bookstore.apps.your-domain.com
```

### Change Database Credentials
Edit `k8s/base/secret.yaml`:
```yaml
stringData:
  DB_USER: your_user
  DB_PASSWORD: your_password
```

## 📊 Architecture

```
┌─────────────────────────────────────────────────────┐
│                  OpenShift/Kubernetes                │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐      ┌──────────────┐            │
│  │  Frontend    │      │  Frontend    │            │
│  │  (Nginx)     │      │  (Nginx)     │            │
│  │  2 replicas  │      │  2 replicas  │            │
│  └────────┬─────┘      └────────┬─────┘            │
│           │                     │                  │
│           └──────────┬──────────┘                  │
│                      │                            │
│              ┌───────▼────────┐                   │
│              │  LoadBalancer/ │                   │
│              │  OpenShift     │                   │
│              │  Route         │                   │
│              └────────────────┘                   │
│                                                   │
│  ┌──────────────┐      ┌──────────────┐          │
│  │   Backend    │      │   Backend    │          │
│  │   API        │      │   API        │          │
│  │  2 replicas  │      │  2 replicas  │          │
│  └────────┬─────┘      └────────┬─────┘          │
│           │                     │                │
│           └──────────┬──────────┘                │
│                      │                          │
│  ┌───────────────────▼───────────────────┐      │
│  │                                       │      │
│  │  ┌─────────────┐  ┌─────────────┐   │      │
│  │  │   MySQL     │  │   Redis     │   │      │
│  │  │  StatefulSet│  │  Deployment │   │      │
│  │  │   1 replica │  │  1 replica  │   │      │
│  │  └─────────────┘  └─────────────┘   │      │
│  │                                       │      │
│  └───────────────────────────────────────┘      │
│              Persistent Storage                 │
└─────────────────────────────────────────────────┘
```

## 🔒 Security Features

- ✅ Non-root containers
- ✅ Resource limits and requests
- ✅ Pod anti-affinity for high availability
- ✅ Secrets management for credentials
- ✅ Health checks (liveness and readiness probes)
- ✅ Network isolation with namespace

## 📈 Scaling

### Horizontal Scaling
```bash
# Scale backend to 5 replicas
kubectl scale deployment backend -n bookstore --replicas=5

# Scale frontend to 5 replicas
kubectl scale deployment frontend -n bookstore --replicas=5
```

### Update kustomization.yaml for permanent scaling
```yaml
replicas:
  - name: backend
    count: 5
  - name: frontend
    count: 5
```

## 🧹 Cleanup

```bash
# Delete all resources
kubectl delete -k k8s/base/

# Or with oc
oc delete -k k8s/base/
```

## 📋 Next Steps

1. **Update container images** in `k8s/base/kustomization.yaml`
2. **Run deployment script**: `./k8s/deploy.sh`
3. **Verify all pods** are running: `kubectl get pods -n bookstore`
4. **Check application** is accessible
5. **Monitor logs** if issues occur

## 🆘 Troubleshooting

### Pods not starting?
```bash
kubectl describe pod <pod-name> -n bookstore
kubectl logs <pod-name> -n bookstore
```

### Database connection issues?
```bash
kubectl exec -it mysql-0 -n bookstore -- mysql -u root -proot123
```

### Frontend can't reach backend?
```bash
kubectl exec -it deployment/frontend -n bookstore -- \
  curl http://backend:3000/api/health
```

## 📚 Resources

- [Kubernetes Docs](https://kubernetes.io/docs/)
- [Kustomize Guide](https://kustomize.io/)
- [OpenShift Docs](https://docs.openshift.com/)
- [Deployment README](./README.md)

---

**Ready to deploy to Kubernetes!** 🎉

Run: `./k8s/deploy.sh`
