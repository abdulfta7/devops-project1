# Kubernetes Deployment Guide

## Local Kubernetes Setup (5 minutes)

### Option 1: Docker Desktop Kubernetes
```bash
# Enable Kubernetes in Docker Desktop
# Docker → Preferences → Kubernetes → Enable Kubernetes

# Verify
kubectl cluster-info
kubectl get nodes
```

### Option 2: Minikube
```bash
# Install and start
minikube start --cpus 4 --memory 4096

# Verify
kubectl cluster-info
kubectl get nodes
```

### Option 3: k3s (Lightweight)
```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -

# Verify
kubectl cluster-info
kubectl get nodes
```

---

## Deploy Application

### 1. Verify Kubernetes Access
```bash
kubectl cluster-info
# Should show cluster URL and API server running

kubectl get nodes
# Should list all cluster nodes
```

### 2. Deploy Application
```bash
# Deploy multi-namespace architecture
kubectl apply -k k8s/base/

# Verify deployment
kubectl get namespaces | grep bookstore
kubectl get pods -A -l app.kubernetes.io/name=bookstore
kubectl get svc -A -l app.kubernetes.io/name=bookstore
```

### 3. (Optional) Apply Security Overlay
```bash
# Production-grade security policies
kubectl apply -k k8s/overlays/security/

# Verify
kubectl get networkpolicies -A | grep bookstore
kubectl get roles -A | grep bookstore
```

### 4. (Optional) Apply Autoscaling
```bash
# Enable HPA and PDB
kubectl apply -k k8s/overlays/autoscaling/

# Verify
kubectl get hpa -A
kubectl get pdb -A
```

---

## Access Services

### Port Forward to Frontend
```bash
kubectl port-forward -n bookstore-frontend svc/frontend 8080:80

# Open browser
http://localhost:8080
```

### Port Forward to Backend
```bash
kubectl port-forward -n bookstore-backend svc/backend 3000:3000

# Test API
curl http://localhost:3000/api/health
curl http://localhost:3000/api/books
```

### Port Forward to Database
```bash
# MySQL
kubectl port-forward -n bookstore-database svc/mysql 3306:3306
mysql -h localhost -u bookstore -pbookstore123

# Redis
kubectl port-forward -n bookstore-database svc/redis 6379:6379
redis-cli
```

---

## Ingress Setup (For Cluster Access)

### Install Nginx Ingress Controller (if not present)
```bash
# For Kubernetes on cloud (EKS, GKE, AKS)
# Usually already installed

# For local Kubernetes (Minikube, k3s, Docker Desktop)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.0/deploy/static/provider/cloud/deploy.yaml

# Verify
kubectl get pods -n ingress-nginx
```

### Access via Ingress

**Update your /etc/hosts** (or C:\Windows\System32\drivers\etc\hosts on Windows):
```
127.0.0.1  bookstore-frontend.example.com
127.0.0.1  bookstore-backend.example.com
```

**Access services**:
```bash
# Frontend
http://bookstore-frontend.example.com

# Backend API
http://bookstore-backend.example.com/api/health
```

---

## Cloud Provider Deployment

### AWS EKS
```bash
# Create cluster
eksctl create cluster --name bookstore --region us-east-1

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name bookstore

# Deploy
kubectl apply -k k8s/overlays/production/
```

### Google GKE
```bash
# Create cluster
gcloud container clusters create bookstore --zone us-central1-a

# Update kubeconfig
gcloud container clusters get-credentials bookstore --zone us-central1-a

# Deploy
kubectl apply -k k8s/overlays/production/
```

### Azure AKS
```bash
# Create cluster
az aks create --resource-group myRG --name bookstore

# Update kubeconfig
az aks get-credentials --resource-group myRG --name bookstore

# Deploy
kubectl apply -k k8s/overlays/production/
```

---

## Monitoring Commands

### Check Deployment Status
```bash
# All namespaces
kubectl get namespaces | grep bookstore

# All pods
kubectl get pods -A -l app.kubernetes.io/name=bookstore

# Pod details
kubectl describe pod <POD_NAME> -n <NAMESPACE>

# Pod logs
kubectl logs -f <POD_NAME> -n <NAMESPACE>
```

### Check Services
```bash
# All services
kubectl get svc -A -l app.kubernetes.io/name=bookstore

# Service details
kubectl describe svc backend -n bookstore-backend
```

### Check Autoscaling
```bash
# HPA status
kubectl get hpa -A

# Watch HPA scaling
kubectl get hpa -n bookstore-backend --watch

# View events
kubectl get events -n bookstore-backend --sort-by='.lastTimestamp'
```

### Check Database
```bash
# MySQL StatefulSet
kubectl get statefulset -n bookstore-database
kubectl logs -f statefulset/mysql -n bookstore-database

# Redis Deployment
kubectl get deployment -n bookstore-database
kubectl logs -f deployment/redis -n bookstore-database
```

---

## Troubleshooting

### Pods Not Starting
```bash
# Check pod status
kubectl describe pod <POD_NAME> -n <NAMESPACE>

# Check logs
kubectl logs <POD_NAME> -n <NAMESPACE> --previous  # If crashed

# Check events
kubectl get events -n <NAMESPACE> --sort-by='.lastTimestamp'
```

### Can't Connect to Service
```bash
# Check service exists
kubectl get svc -n <NAMESPACE>

# Test DNS from pod
kubectl exec -it <POD_NAME> -n <NAMESPACE> -- \
  nslookup backend.bookstore-backend.svc.cluster.local

# Test connectivity
kubectl exec -it <POD_NAME> -n <NAMESPACE> -- \
  curl http://backend.bookstore-backend.svc.cluster.local:3000
```

### HPA Not Scaling
```bash
# Check metrics server
kubectl get deployment metrics-server -n kube-system

# Check HPA status
kubectl describe hpa backend-hpa -n bookstore-backend

# Check resource requests
kubectl describe pod <POD_NAME> -n bookstore-backend | grep -A 5 "Requests"
```

### High Memory/CPU Usage
```bash
# Check resource usage
kubectl top pods -n bookstore-backend
kubectl top nodes

# Check resource limits
kubectl describe quota -n bookstore-backend
```

---

## Cleanup

### Remove Application
```bash
# Remove all deployed resources
kubectl delete -k k8s/base/

# Remove overlays (if applied)
kubectl delete -k k8s/overlays/security/
kubectl delete -k k8s/overlays/autoscaling/

# Verify
kubectl get namespaces | grep bookstore  # Should be empty
```

### Remove Local Cluster
```bash
# Minikube
minikube delete

# k3s
/usr/local/bin/k3s-uninstall.sh
```

---

## GitHub Actions CI/CD Integration

### Add kubeconfig Secret
```bash
# Get base64 encoded kubeconfig
cat ~/.kube/config | base64 | tr -d '\n'

# Add to GitHub
gh secret set KUBECONFIG --body "$(cat ~/.kube/config | base64 | tr -d '\n')"

# Verify
gh secret list | grep KUBECONFIG
```

### Push to Trigger Pipeline
```bash
git push origin main
# Pipeline runs and deploys to cluster automatically
```

### Monitor Deployment
```
Repository → Actions → Latest run
```

---

## Best Practices

✅ **DO**
- Use namespaces to isolate components
- Apply resource limits (requests/limits)
- Use network policies for security
- Monitor pod metrics and events
- Backup important data (MySQL, Redis)
- Use Ingress for external access

❌ **DON'T**
- Run containers as root
- Skip security policies
- Use latest image tags in production
- Store secrets in environment variables
- Skip resource quotas
- Run single pod (use 2+ replicas for HA)

---

## Next Steps

1. ✅ Deploy to local Kubernetes
2. ✅ Verify all services running
3. ✅ Test API endpoints
4. ✅ Monitor HPA scaling
5. ✅ Set up GitHub Actions deployment
6. ✅ Deploy to production cluster

---

## Useful Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kustomize](https://kustomize.io/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
