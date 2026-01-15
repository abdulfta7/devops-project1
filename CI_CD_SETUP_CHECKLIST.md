# ✅ CI/CD Setup Checklist

## Pre-Deployment

- [ ] Repository pushed to GitHub
- [ ] `main` branch created and protected
- [ ] GitHub Actions enabled in repository
- [ ] OpenShift/Kubernetes cluster available
- [ ] `oc` CLI installed and configured locally

---

## GitHub Configuration

### Step 1: Add kubeconfig Secret
```bash
# Get your kubeconfig (local Kubernetes config)
cat ~/.kube/config | base64 | tr -d '\n'

# Add to GitHub via CLI
gh secret set KUBECONFIG --body "$(cat ~/.kube/config | base64 | tr -d '\n')"
```

**For different cloud providers**:

**AWS EKS**:
```bash
aws eks update-kubeconfig --region us-east-1 --name my-cluster
cat ~/.kube/config | base64 | tr -d '\n' | gh secret set KUBECONFIG
```

**Google GKE**:
```bash
gcloud container clusters get-credentials my-cluster --zone us-central1-a
cat ~/.kube/config | base64 | tr -d '\n' | gh secret set KUBECONFIG
```

**Azure AKS**:
```bash
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
cat ~/.kube/config | base64 | tr -d '\n' | gh secret set KUBECONFIG
```

**Verify**:
```bash
gh secret list | grep KUBECONFIG
# KUBECONFIG
```

- [ ] `KUBECONFIG` secret set

### Step 2: Enable GitHub Actions

1. Go to repository → **Settings**
2. **Code and automation** → **Actions**
3. Select: **"Allow all actions and reusable workflows"**
4. Click **Save**

- [ ] GitHub Actions enabled

### Step 3: Create Branch Protection (Recommended)

1. Go to repository → **Settings**
2. **Branches** → **Add branch protection rule**
3. Apply to branch: `main`
4. Check: **"Require status checks to pass before merging"**
5. Select:
   - `build`
   - `scan`
   - `test`
6. Click **Create**

- [ ] Branch protection configured

---

## Local Testing (Before Pushing)

### Test Docker Build
```bash
cd backend
docker build -t backend:test -f Dockerfile .
cd ../frontend
docker build -t frontend:test -f Dockerfile .
```

- [ ] Backend builds successfully
- [ ] Frontend builds successfully

### Test Backend Locally
```bash
cd backend
npm install
npm start
# Open new terminal
curl http://localhost:3000/api/health
```

**Expected Response**:
```json
{"status":"ok","timestamp":"...","uptime":...}
```

- [ ] Backend starts without errors
- [ ] Health endpoint responds

### Test Docker Compose
```bash
docker-compose up -d
sleep 10
curl http://localhost:8080/api/health
curl http://localhost:8080
```

**Expected**:
- Backend health: `{"status":"ok",...}`
- Frontend: HTML page loads

- [ ] Docker Compose works locally

---

## Kubernetes Preparation

### Verify Cluster Access
```bash
kubectl cluster-info
# Expected: Shows cluster URL and API server running

kubectl get nodes
# Expected: Lists all cluster nodes

kubectl whoami  # (if using OIDC/RBAC)
# Or simply:
kubectl auth can-i create namespaces
# Expected: yes
```

- [ ] Can connect to cluster
- [ ] Can list nodes
- [ ] Can create namespaces

### Verify Permissions
```bash
# Check if you can create namespaces
kubectl auth can-i create namespaces

# Check if you can deploy
kubectl auth can-i create deployments --all-namespaces

# Check if you can manage network policies
kubectl auth can-i create networkpolicies --all-namespaces
```

- [ ] Can create namespaces
- [ ] Can create deployments
- [ ] Can create network policies

### Verify Storage Availability (For Database)
```bash
# Check default storage class
kubectl get storageclass

# Should see something like:
# NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# standard (default)   kubernetes.io/host-path Delete          Immediate
```

- [ ] Storage class available

---

## First Deployment

### Step 1: Trigger Workflow
```bash
git add .
git commit -m "Initial CI/CD setup"
git push origin main
```

### Step 2: Monitor Build
```
Go to Repository → Actions → Latest run
Watch jobs complete in real-time
```

**Expected Sequence**:
1. BUILD starts (5-10 min)
2. SCAN starts after BUILD (3-5 min)
3. TEST starts after BUILD (5-10 min)
4. DEPLOY starts after all complete (10-15 min)
5. SECURITY-REPORT starts (2-3 min)

- [ ] BUILD completed successfully
- [ ] SCAN completed successfully
- [ ] TEST completed successfully
- [ ] DEPLOY completed successfully
- [ ] SECURITY-REPORT completed successfully

### Step 3: Verify Deployment on Cluster
```bash
# Check namespaces
kubectl get namespaces | grep bookstore

# Check pods
kubectl get pods -A -l app.kubernetes.io/name=bookstore

# Check services
kubectl get svc -A -l app.kubernetes.io/name=bookstore
```

**Expected**:
```
bookstore-database    Active
bookstore-backend     Active
bookstore-frontend    Active

Pods: mysql-0, redis-0, backend-*, frontend-*
Services: mysql, redis, backend, frontend
```

- [ ] Namespaces created
- [ ] Pods running
- [ ] Services created

### Step 4: Verify Scaling
```bash
# Check HPA
kubectl get hpa -n bookstore-backend
kubectl get hpa -n bookstore-frontend

# Check current replicas
kubectl get deployment -n bookstore-backend -o wide
kubectl get deployment -n bookstore-frontend -o wide
```

- [ ] HPA created for backend
- [ ] HPA created for frontend
- [ ] Initial replicas: 2 each

### Step 5: Verify Connectivity
```bash
# Test frontend → backend
kubectl exec -n bookstore-frontend deployment/frontend -- \
  curl http://backend.bookstore-backend.svc.cluster.local:3000/api/health

# Test backend → database
kubectl exec -n bookstore-backend deployment/backend -- \
  mysql -h mysql.bookstore-database.svc.cluster.local -u bookstore -pbookstore123 -e "SELECT COUNT(*) FROM bookstore.books;"
```

**Expected**:
- Frontend can reach backend ✅
- Backend can reach database ✅
- Books table has 8 records ✅

- [ ] Frontend → Backend connectivity works
- [ ] Backend → Database connectivity works

---

## Post-Deployment

### Monitor Application
```bash
# Watch pods
kubectl get pods -A --watch

# Watch logs
kubectl logs -f deployment/backend -n bookstore-backend

# Monitor HPA
kubectl get hpa -n bookstore-backend --watch
```

- [ ] All pods healthy
- [ ] No error logs
- [ ] HPA responding to metrics

### Test API Endpoints
```bash
# Get backend service endpoint
kubectl get svc backend -n bookstore-backend

# Port-forward for local testing
kubectl port-forward -n bookstore-backend svc/backend 3000:3000

# Test endpoints in new terminal
curl http://localhost:3000/api/health
curl http://localhost:3000/api/ready
curl http://localhost:3000/api/books
```

- [ ] `/api/health` returns OK
- [ ] `/api/ready` returns OK
- [ ] `/api/books` returns book list

### Check Security Policies
```bash
# Network policies applied
kubectl get networkpolicies -A | grep bookstore

# RBAC applied
kubectl get roles -A -l app=bookstore

# Resource quotas applied
kubectl describe quota -n bookstore-backend
```

- [ ] Network policies deployed
- [ ] RBAC configured
- [ ] Resource quotas enforced

### Review Security Scan
```
Repository → Security → Code scanning
```

Look for:
- Critical vulnerabilities: Fix before next deployment
- High vulnerabilities: Address in current sprint
- Medium/Low: Track in backlog

- [ ] Scanned for vulnerabilities
- [ ] Critical issues addressed (if any)

---

## Ongoing Maintenance

### Weekly
- [ ] Review security scan results
- [ ] Check HPA scaling activity
- [ ] Monitor deployment logs

### Monthly
- [ ] Update base images (MySQL, Redis, Node)
- [ ] Audit RBAC permissions
- [ ] Review network policies

### Quarterly
- [ ] Load test autoscaling
- [ ] Disaster recovery drill
- [ ] Security audit

---

## Deployment Verification

### Quick Check
```bash
# One-liner to verify everything
kubectl get ns -l app=bookstore && \
kubectl get pods -A -l app.kubernetes.io/name=bookstore && \
kubectl get svc -A -l app.kubernetes.io/name=bookstore && \
kubectl get hpa -A
```

### Detailed Health Check
```bash
# Run this script
#!/bin/bash
echo "=== Namespaces ==="
kubectl get ns | grep bookstore

echo -e "\n=== Pods Status ==="
kubectl get pods -A -l app.kubernetes.io/name=bookstore

echo -e "\n=== Services ==="
kubectl get svc -A -l app.kubernetes.io/name=bookstore

echo -e "\n=== StatefulSets ==="
kubectl get statefulsets -A -l app.kubernetes.io/name=bookstore

echo -e "\n=== Deployments ==="
kubectl get deployments -A -l app.kubernetes.io/name=bookstore

echo -e "\n=== HPA ==="
kubectl get hpa -A

echo -e "\n=== PDB ==="
kubectl get pdb -A

echo -e "\n=== Network Policies ==="
kubectl get networkpolicies -A | grep bookstore

echo -e "\n=== Resource Quotas ==="
kubectl describe quota -n bookstore-backend
```

- [ ] All namespaces created
- [ ] All pods running
- [ ] All services created
- [ ] HPA configured
- [ ] PDB configured
- [ ] Network policies applied
- [ ] Resource quotas applied

---

## Troubleshooting Checklist

### If DEPLOY Job Fails

- [ ] Check `KUBECONFIG` secret is base64 encoded correctly
- [ ] Verify cluster is accessible: `kubectl cluster-info`
- [ ] Check permissions: `kubectl auth can-i create namespaces`
- [ ] Review DEPLOY job logs for specific error
- [ ] Verify kubeconfig context: `kubectl config get-contexts`

**Re-encode kubeconfig if needed**:
```bash
cat ~/.kube/config | base64 | tr -d '\n' | gh secret set KUBECONFIG
```

### If Pods Don't Start

- [ ] Check pod events: `kubectl describe pod <POD_NAME> -n <NAMESPACE>`
- [ ] Check pod logs: `kubectl logs <POD_NAME> -n <NAMESPACE>`
- [ ] Verify image exists: `docker pull ghcr.io/your-org/bookstore/backend:main`
- [ ] Check resource limits: `kubectl describe quota -n bookstore-backend`
- [ ] Check network policies: `kubectl get networkpolicies -n bookstore-backend`

### If HPA Not Scaling

- [ ] Check metrics server: `kubectl get deployment metrics-server -n kube-system`
- [ ] Check HPA status: `kubectl describe hpa backend-hpa -n bookstore-backend`
- [ ] Check metrics: `kubectl top pods -n bookstore-backend`
- [ ] Verify resource requests are set: `kubectl describe pod <POD_NAME> -n bookstore-backend`

### If Services Can't Communicate

- [ ] Check DNS: `kubectl exec pod -c sh -- nslookup mysql.bookstore-database.svc.cluster.local`
- [ ] Check network policies: `kubectl get networkpolicies -A`
- [ ] Test connectivity: `kubectl exec pod -c sh -- curl http://backend:3000`
- [ ] Check firewall rules on cluster network

---

## Success Indicators

### ✅ Everything Working When:

1. **All jobs pass in Actions**
   - BUILD ✅
   - SCAN ✅
   - TEST ✅
   - DEPLOY ✅
   - SECURITY-REPORT ✅

2. **All pods running**
   ```bash
   kubectl get pods -A | grep bookstore
   # All show "Running" status and "1/1" ready
   ```

3. **Services accessible**
   ```bash
   kubectl get svc -A -l app.kubernetes.io/name=bookstore
   # All services have ClusterIP assigned
   ```

4. **HPA active**
   ```bash
   kubectl get hpa -A
   # Shows current replicas (should be 2 each initially)
   ```

5. **Cross-namespace communication**
   ```bash
   kubectl exec -n bookstore-backend deployment/backend -- \
     curl http://backend.bookstore-backend.svc.cluster.local:3000/api/health
   # Returns 200 OK
   ```

6. **Security scan complete**
   ```
   Repository → Security → Code scanning
   # Shows vulnerability scan results
   ```

---

## Ready for Production? ✅

When all checkboxes are complete:

- [ ] CI/CD pipeline configured
- [ ] First deployment successful
- [ ] All services running
- [ ] Autoscaling active
- [ ] Security policies enforced
- [ ] Monitoring in place
- [ ] Backups configured
- [ ] Team trained on process

**You're ready to deploy! 🚀**

---

## Next Steps

1. **Set up monitoring** (Prometheus, Grafana)
2. **Configure logging** (ELK, Loki)
3. **Set up alerts** (Alertmanager)
4. **Test disaster recovery** (backup/restore)
5. **Document runbooks** (troubleshooting guides)
6. **Train team** (deployment process)

**Questions?** Check documentation files:
- `.github/GITHUB_ACTIONS_SETUP.md`
- `CI_CD_QUICK_REFERENCE.md`
- `k8s/OVERLAYS.md`
- `MULTI_NAMESPACE_DEPLOYMENT.md`
