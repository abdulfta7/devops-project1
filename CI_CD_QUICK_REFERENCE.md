# CI/CD Quick Reference

## 5-Minute Setup

### 1. Add GitHub Secret
```bash
# Get your kubeconfig
cat ~/.kube/config | base64 | tr -d '\n'

# Add secret via GitHub CLI
gh secret set KUBECONFIG --body "$(cat ~/.kube/config | base64 | tr -d '\n')"
```

### 2. Enable GitHub Actions
Settings → Code and automation → Actions → "Allow all actions"

### 3. Trigger Pipeline
```bash
git push origin main
# Pipeline starts automatically!
```

---

## Pipeline Status

### View Real-Time Status
```
Repository → Actions → Latest workflow run
```

### Check Specific Job
```
Click job name to view logs
```

### Download Artifacts
```
Artifacts section → Click to download
- backend-image.tar
- frontend-image.tar
- security-report.md
```

---

## Common Commands

### Trigger Manual Build
```bash
gh workflow run ci-cd.yml -r main
```

### View Workflow Status
```bash
gh run list --workflow ci-cd.yml
```

### View Job Logs
```bash
gh run view <RUN_ID> --log --job build
gh run view <RUN_ID> --log --job scan
gh run view <RUN_ID> --log --job test
gh run view <RUN_ID> --log --job deploy
```

### Get Latest Run ID
```bash
gh run list --workflow ci-cd.yml --limit 1 --json databaseId --jq '.[0].databaseId'
```

---

## What Gets Deployed

### Namespaces Created
```
bookstore-database    (MySQL 8.0 + Redis 7)
bookstore-backend     (Node.js API, 2-8 replicas)
bookstore-frontend    (Nginx frontend, 2-5 replicas)
```

### Services Exposed
```
Frontend  → bookstore-frontend.example.com
Backend   → bookstore-backend.example.com
Database  → Internal DNS only (not exposed)
```

### Automatic Scaling
```
Frontend HPA:  2 → 5 replicas (70% CPU threshold)
Backend HPA:   2 → 8 replicas (75% CPU threshold)
```

---

## Security Checks

### View Scan Results
```
Repository → Security → Code scanning
```

### Filter by Severity
```
- Critical: Must fix before merge
- High: Should fix before production
- Medium: Can fix in next iteration
- Low: Consider fixing
```

### Interpret SARIF Report
```
Each finding includes:
- Location (file, line)
- Severity (Critical/High/Medium/Low)
- Description
- Recommended fix
- External links to CVE database
```

---

## Troubleshooting

### Deploy Failed
```bash
# View deploy logs
gh run view <RUN_ID> --log --job deploy

# Check cluster status
kubectl get pods -A | grep bookstore
```

### Tests Failed
```bash
# View test logs
gh run view <RUN_ID> --log --job test

# Test locally
cd backend
npm install
npm start
```

### Build Failed
```bash
# View build logs
gh run view <RUN_ID> --log --job build

# Rebuild Docker locally
docker build -f backend/Dockerfile -t backend:test ./backend
docker build -f frontend/Dockerfile -t frontend:test ./frontend
```

---

## Environment Variables

### Available in Workflows
```yaml
REGISTRY: ghcr.io
IMAGE_NAME: github.repository (your-org/bookstore)
GITHUB_SHA: Commit hash
GITHUB_REF: Branch name (refs/heads/main)
GITHUB_ACTOR: Username
```

### Test Service Credentials
```yaml
MySQL:  localhost:3306  user:bookstore  pass:bookstore123
Redis:  localhost:6379
```

### Backend Test Env
```yaml
DB_HOST: localhost
DB_USER: bookstore
DB_PASSWORD: bookstore123
REDIS_HOST: localhost
PORT: 3000
```

---

## Performance

### Typical Timings
```
BUILD:  5-10 minutes
SCAN:   3-5 minutes
TEST:   5-10 minutes
DEPLOY: 10-15 minutes
---
Total:  20-30 minutes
```

### Optimization Tips
```
1. Use Docker layer caching (automatic)
2. Parallel jobs (BUILD, SCAN, TEST run together)
3. Pre-built images (faster scanning)
4. GitHub Actions cache (reduces dependencies install)
```

---

## Deployment Options

### Development Only (Disable Deploy)
```bash
# Comment out deploy job condition or
# Push to develop branch (won't deploy)
```

### Production with Approval
```
Requires approval before deploy step
Set in environment: production (GitHub UI)
```

### Skip Tests
```bash
# Not recommended, but:
# Manually trigger workflow from Actions tab
# Modify workflow to skip test job
```

---

## Images

### Image Tags
```
main branch push:
  ghcr.io/your-org/bookstore/backend:main
  ghcr.io/your-org/bookstore/backend:main-sha-abc123
  ghcr.io/your-org/bookstore/frontend:main
  ghcr.io/your-org/bookstore/frontend:main-sha-abc123

develop branch push:
  ghcr.io/your-org/bookstore/backend:develop
  ghcr.io/your-org/bookstore/frontend:develop

Release tag (v1.0.0):
  ghcr.io/your-org/bookstore/backend:v1.0.0
  ghcr.io/your-org/bookstore/frontend:v1.0.0
```

### Image Pull Policy
```
main:     imagePullPolicy: IfNotPresent
develop:  imagePullPolicy: Always
```

---

## Logs & Debugging

### Backend Container Logs
```bash
kubectl logs -f deployment/backend -n bookstore-backend
```

### Frontend Container Logs
```bash
kubectl logs -f deployment/frontend -n bookstore-frontend
```

### MySQL Logs
```bash
kubectl logs -f statefulset/mysql -n bookstore-database
```

### Redis Logs
```bash
kubectl logs -f deployment/redis -n bookstore-database
```

### All Events
```bash
kubectl get events -A --sort-by='.lastTimestamp'
```

---

## Success Indicators

### ✅ All Jobs Complete
```
BUILD    ✅ Complete
SCAN     ✅ Complete
TEST     ✅ Complete
DEPLOY   ✅ Complete
SEC-RPT  ✅ Complete
```

### ✅ Pods Running
```bash
kubectl get pods -n bookstore-database     # mysql-0, redis-0
kubectl get pods -n bookstore-backend      # backend-*
kubectl get pods -n bookstore-frontend     # frontend-*
```

### ✅ Services Accessible
```bash
# Frontend
kubectl port-forward -n bookstore-frontend service/frontend 8080:80

# Backend
kubectl port-forward -n bookstore-backend service/backend 3000:3000
```

### ✅ HPA Active
```bash
kubectl get hpa -n bookstore-frontend  # Should show current replicas
kubectl get hpa -n bookstore-backend
```

---

## Next Steps

1. ✅ Push code to main branch
2. ✅ Monitor workflow in Actions tab
3. ✅ Review security scan results
4. ✅ Check deployment in Kubernetes
5. ✅ Verify application is running
6. ✅ Monitor HPA scaling activity

---

## Support

### Check Logs
```
Actions → Run name → Job name → View logs
```

### Verify Secrets
```bash
gh secret list
```

### Test Connection
```bash
# Local test (before committing)
docker-compose up -d
curl http://localhost:3000/api/health
```

### Report Issue
```
GitHub Issues → Create new issue
Include: workflow run ID, error logs, steps to reproduce
```
