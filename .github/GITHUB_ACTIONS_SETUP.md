# GitHub Actions CI/CD Pipeline Setup

## Overview

This project uses GitHub Actions to automatically build, scan, test, and deploy the Bookstore application to Kubernetes/OpenShift with a multi-namespace architecture.

## Pipeline Stages

```
┌─────────────┐
│  On Push    │
└──────┬──────┘
       │
       ├─────────────────────────────────────┐
       │                                     │
   ┌───▼────┐  ┌───────┐  ┌──────┐  ┌──────▼───┐  ┌──────────────┐
   │ BUILD  │──│ SCAN  │──│ TEST │──│ DEPLOY  │──│ SEC. REPORT │
   └────────┘  └───────┘  └──────┘  └─────────┘  └──────────────┘
       │            │          │          │
       ▼            ▼          ▼          ▼
   Docker      Trivy    MySQL +     Kustomize    GitHub Issue
   Images      SARIF     Redis      & kubectl
```

## Workflow File

**Location**: `.github/workflows/ci-cd.yml`

## Setup Instructions

### 1. Prerequisites

- GitHub repository (public or private)
- Docker Hub account or GitHub Container Registry access (automatic with GitHub)
- Kubernetes cluster access (any distribution: EKS, GKE, AKS, k3s, kubeadm, etc.)
- `kubectl` CLI configured locally for testing
- Admin or sufficient permissions to create namespaces and deployments

### 2. Configure GitHub Secrets

Navigate to **Settings → Secrets and variables → Actions** and add:

#### Kubernetes Cluster Access:
```
KUBECONFIG
  Type: Secret
  Value: Your kubeconfig file (base64 encoded)
  How to get:
    cat ~/.kube/config | base64 | tr -d '\n'
    # Copy entire base64 output to secret
```

#### Container Registry (Optional, auto-configured):
```
GITHUB_TOKEN - Already available in workflows
REGISTRY - ghcr.io (default)
```

### 3. Get Your kubeconfig

```bash
# Option 1: Local kubeconfig
cat ~/.kube/config | base64 | tr -d '\n'
# Encode as single line and copy to KUBECONFIG secret

# Option 2: Cloud provider
# AWS EKS
aws eks update-kubeconfig --region us-east-1 --name my-cluster
cat ~/.kube/config | base64 | tr -d '\n'

# Google GKE
gcloud container clusters get-credentials my-cluster --zone us-central1-a
cat ~/.kube/config | base64 | tr -d '\n'

# Azure AKS
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
cat ~/.kube/config | base64 | tr -d '\n'
```

### 4. Enable GitHub Actions

1. Go to repository → **Settings → Code and automation → Actions**
2. Select "Allow all actions and reusable workflows"
3. Click Save

### 5. Set Branch Protection Rules (Optional but Recommended)

1. Go to repository → **Settings → Branches**
2. Add rule for `main` branch
3. Require status checks to pass:
   - ✅ build
   - ✅ scan
   - ✅ test
   - ✅ deploy (only on push)
4. Require approval from code owners

---

## Jobs in Detail

### BUILD Job
**Triggers**: Push to main/develop, PR to main/develop
**Duration**: 5-10 minutes

```yaml
- Checks out code
- Sets up Docker Buildx
- Logs into GHCR
- Builds backend multi-stage Docker image
- Builds frontend multi-stage Docker image
- Pushes to ghcr.io (only on main push)
- Saves images as artifacts for scanning
```

**Output Images**:
```
ghcr.io/your-org/bookstore/backend:main
ghcr.io/your-org/bookstore/frontend:main
ghcr.io/your-org/bookstore/backend:main-sha-abc123def
ghcr.io/your-org/bookstore/frontend:main-sha-abc123def
```

---

### SCAN Job
**Depends on**: BUILD
**Duration**: 3-5 minutes
**Permissions**: security-events:write

```yaml
- Downloads Docker images from BUILD artifacts
- Runs Trivy vulnerability scanner on backend
- Runs Trivy vulnerability scanner on frontend
- Generates SARIF reports
- Uploads results to GitHub Security tab
- Comments on PR with scan status
```

**View Results**:
```
Repository → Security → Code scanning → Trivy
```

---

### TEST Job
**Depends on**: BUILD
**Duration**: 5-10 minutes
**Services**: MySQL 8.0, Redis 7

```yaml
- Starts MySQL 8.0 service
- Starts Redis 7 service
- Checks out code
- Sets up Node.js 18
- Installs backend dependencies
- Starts backend server
- Tests health check endpoints
```

**Test Endpoints**:
```
GET /api/health  → {"status":"ok","timestamp":"...","uptime":...}
GET /api/ready   → {"status":"ok"}
```

---

### DEPLOY Job
**Depends on**: BUILD, SCAN, TEST
**Triggers**: Only on push to main branch
**Duration**: 10-15 minutes
**Environment**: Production (requires approval)

**Deployment Steps**:
```yaml
1. Install Kustomize
2. Login to OpenShift cluster
3. Update image references in kustomization
4. Deploy multi-namespace base (k8s/base/)
5. Apply security overlay (network policies, RBAC, quotas)
6. Apply autoscaling overlay (HPA, PDB)
7. Wait for MySQL StatefulSet ready
8. Wait for Redis Deployment ready
9. Wait for Backend Deployment ready
10. Wait for Frontend Deployment ready
11. Verify cross-namespace connectivity
12. Display deployment summary
13. Collect logs on failure
```

**Deploys to Namespaces**:
- `bookstore-database` (MySQL StatefulSet + Redis)
- `bookstore-backend` (2-8 replicas Node.js API)
- `bookstore-frontend` (2-5 replicas Nginx frontend)

---

### SECURITY-REPORT Job
**Depends on**: SCAN, DEPLOY
**Triggers**: Always (even on failure)
**Duration**: 2-3 minutes

```yaml
- Generates security findings markdown
- Creates GitHub issue with report
- Labels with 'security' and 'automated'
- Uploads report as artifact
```

---

## Workflow Behavior by Trigger

### On Pull Request
```
✅ BUILD → ✅ SCAN → ✅ TEST → ❌ DEPLOY (skipped) → ✅ SECURITY-REPORT
```

**Time**: 15-20 minutes
**Artifacts**: Saved for PR review

### On Push to Develop
```
✅ BUILD → ✅ SCAN → ✅ TEST → ❌ DEPLOY (skipped) → ✅ SECURITY-REPORT
```

**Time**: 15-20 minutes
**Images**: Pushed to GHCR with `develop` tag

### On Push to Main
```
✅ BUILD → ✅ SCAN → ✅ TEST → ✅ DEPLOY → ✅ SECURITY-REPORT
```

**Time**: 20-30 minutes
**Deployment**: Goes live to OpenShift
**Images**: Pushed to GHCR with `main` tag

---

## Monitoring Workflow Runs

### View Workflow Status
1. Go to repository home
2. Click **Actions** tab
3. Select workflow run from list
4. Click run name to view details

### View Live Logs
- Click job name to expand
- Logs update automatically (3 sec refresh)
- Search with Ctrl+F

### View Artifacts
- Scroll to "Artifacts" section
- Download Docker images, security reports, etc.
- Valid for 90 days by default

### View Deployment Status
```
Actions → Latest run → Deploy job output
```

Shows:
- Pod status (running, pending, etc.)
- Service endpoints
- HPA status
- Connectivity test results

---

## Troubleshooting

### BUILD Job Fails

**Problem**: `docker: Error response from daemon`
**Solution**: Increase runner disk space or use self-hosted runner

**Problem**: `denied: permission_denied: User cannot be authenticated`
**Solution**:
```bash
# Verify GitHub token has packages:write scope
gh auth refresh --scopes write:packages
```

---

### SCAN Job Fails

**Problem**: `Error: image not found`
**Solution**: Ensure BUILD job completed successfully

**Problem**: `SARIF upload failed`
**Solution**: Verify workflow has `security-events:write` permission

---

### TEST Job Fails

**Problem**: `Backend health check failed: Connection refused`
**Solution**: 
```bash
# Increase service startup delay
Check: --health-interval=10s --health-retries=5
```

**Problem**: `Cannot find module 'mysql2'`
**Solution**: 
```bash
# Install dependencies
npm ci  # (not npm install)
```

---

### DEPLOY Job Fails

**Problem**: `Unable to login to OpenShift`
**Solution**:
```bash
# Verify secrets exist
gh secret list | grep OPENSHIFT

# Test token locally
oc login -u kubeadmin -p $(gh secret get OPENSHIFT_TOKEN -b $(whoami)) https://cluster:6443
```

**Problem**: `Kustomize: command not found`
**Solution**: Workflow installs it automatically, but verify:
```bash
which kustomize
```

**Problem**: `kubectl: unable to connect to server`
**Solution**: 
```bash
# Verify OPENSHIFT_SERVER secret is correct format
# Should start with https://
```

---

## Performance Tips

### 1. Reduce Build Time
- Docker layer caching saves 60-70% of build time
- Layers are reused across runs
- Ensure Dockerfile uses multi-stage build properly

### 2. Parallel Job Execution
```
BUILD and SCAN run in parallel (SCAN waits for BUILD artifacts)
BUILD and TEST run in parallel (TEST waits for BUILD artifacts)
DEPLOY waits for all three to complete
```

**Total time**: ~25 minutes (not 25+15+15+10+2)

### 3. Reduce Scan Time
- Pre-built images in BUILD artifact mean SCAN doesn't rebuild
- Trivy scans happen fast with pre-loaded images

---

## Best Practices

### ✅ DO
- Review security scan results before merging
- Test locally before pushing to develop/main
- Use semantic versioning for releases
- Keep secrets secure (never commit them)
- Monitor deployment status after merging
- Use branch protection rules
- Require approvals for production deployments

### ❌ DON'T
- Disable security checks to speed up pipeline
- Ignore test failures
- Commit secrets or API keys
- Push to main without tests passing
- Use `latest` tag in production
- Store credentials in repository code
- Skip scanning before deployment

---

## Advanced Configuration

### Manual Workflow Trigger
Add to `ci-cd.yml`:
```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - production
```

Then trigger manually from Actions tab.

### Scheduled Builds
```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
```

### Matrix Builds (Multiple Node Versions)
```yaml
strategy:
  matrix:
    node-version: [16, 18, 20]
```

---

## Integration with GitHub Features

### Branch Protection Rules
Require these checks pass before merge:
- ✅ build
- ✅ scan
- ✅ test

### Environments
```
Production environment requires:
- Approval from code owners
- Only deployable from main branch
```

### Status Badges
Add to README.md:
```markdown
[![CI/CD Pipeline](https://github.com/your-org/bookstore/workflows/CI%2FCD%20Pipeline/badge.svg)](https://github.com/your-org/bookstore/actions)
```

### Notifications
Configure in repository settings:
- PR comments on scan completion
- GitHub issue creation for security reports
- Email notifications on failure

---

## Security Scanning Details

### Trivy Scanner
- **CVE Database**: Updated daily
- **Format**: SARIF (GitHub-native)
- **Exit Code**: 0 (doesn't block deployment)
- **Severity Levels**: CRITICAL, HIGH, MEDIUM, LOW, UNKNOWN

### GitHub Security Dashboard
View at:
```
Repository → Security → Code scanning
```

Shows:
- Vulnerability type
- Severity level
- Location in code
- Recommended fix

### Fixing Vulnerabilities
1. Review scanning results
2. Update base images or dependencies
3. Create PR with fix
4. Rescan with new image
5. Merge when scan passes

---

## Deployment Architecture

The DEPLOY job uses Kustomize to deploy:

```
k8s/base/
├── frontend/ (2 replicas initially)
├── backend/  (2 replicas initially)
└── database/ (MySQL 1 replica, Redis 1 replica)

k8s/overlays/security/
├── Network Policies (zero-trust)
├── Pod Security Standards (RBAC)
└── Resource Quotas (limits)

k8s/overlays/autoscaling/
├── HPA (Frontend: 2-5, Backend: 2-8)
└── PDB (Pod Disruption Budget)
```

---

## Cost Optimization

### GitHub Actions Pricing
- ✅ Free for public repositories (unlimited minutes)
- ✅ Free for private repositories (2000 minutes/month)
- Paid: $0.25 per additional 1000 minutes

### Optimize Usage
```
- Use: matrix to test multiple versions simultaneously
- Skip: unnecessary jobs with 'if:' conditions
- Cache: Docker layers to reduce rebuild time
- Parallel: Jobs that don't depend on each other
```

### Self-Hosted Runners
For cost savings with many builds:
```
- Run actions on your own hardware
- Unlimited minutes
- Faster builds (no GitHub queue)
```

---

## References

- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Trivy Scanner](https://aquasecurity.github.io/trivy/)
- [Kubernetes kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Kustomize](https://kustomize.io/)
- [OpenShift oc CLI](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)


# Get your token
oc whoami -t

# Verify your namespace
oc project
```

### 4. Trigger the Workflow

The workflow automatically runs on:
- ✅ Push to `main` or `develop` branches
- ✅ Pull requests to `main` or `develop` branches

To manually trigger:
1. Go to **Actions**
2. Select **CI/CD Pipeline - Build, Scan & Deploy**
3. Click **Run workflow**

## What Each Job Does

### 🔨 Build
- Checks out code
- Builds backend Docker image
- Builds frontend Docker image
- Pushes to GitHub Container Registry (main branch only)
- Saves images for scanning

### 🔒 Security Scan
- Downloads built images
- Runs Trivy vulnerability scanner
- Uploads results to GitHub Security tab
- Comments on PRs with scan results

### ✅ Test
- Sets up MySQL and Redis services
- Installs Node.js dependencies
- Runs backend health checks
- Verifies API connectivity

### 🚀 Deploy
- Logs into OpenShift cluster
- Creates/updates deployments
- Sets replicas to 2 for high availability
- Verifies deployment rollout
- Only runs on main branch

### 📊 Security Report
- Generates security report
- Creates GitHub issue with findings
- Uploads artifact for download

## Configuration Files

### `.github/workflows/ci-cd.yml`
Main workflow file with all jobs and steps.

## Environment Variables

Set in workflow or as secrets:

```env
REGISTRY=ghcr.io
IMAGE_NAME=username/repo
```

## Viewing Results

### Build Logs
1. Go to **Actions** tab
2. Click on the workflow run
3. Select a job to view logs

### Security Reports
1. Go to **Security** → **Code scanning**
2. View Trivy scan results for each image

### Deployments
1. Check OpenShift console
2. Verify pods are running:
   ```bash
   oc get pods -n <namespace>
   ```

## Troubleshooting

### Images not pushing to registry
- Check `GITHUB_TOKEN` secret is configured
- Verify GitHub Actions has write permissions to packages

### OpenShift deployment failing
- Verify `OPENSHIFT_SERVER`, `OPENSHIFT_TOKEN`, `OPENSHIFT_NAMESPACE` are correct
- Check token hasn't expired: `oc whoami -t`
- Ensure service account has permissions

### Tests failing
- Check MySQL and Redis services are healthy
- Verify database initialization scripts
- Check backend environment variables

### Trivy scan failing
- Ensure images are properly built
- Check Docker daemon is running
- Verify sufficient disk space

## Best Practices

1. **Branch Protection**: Enable branch protection on main requiring status checks to pass
2. **Secrets Management**: Use GitHub encrypted secrets, never commit credentials
3. **Image Retention**: Configure artifact retention in workflow
4. **Notifications**: Set up GitHub Actions notifications for failures
5. **Scheduled Scans**: Add `schedule` trigger for nightly security scans

## Next Steps

1. Commit workflow files to repository:
   ```bash
   git add .github/workflows/
   git commit -m "Add GitHub Actions CI/CD pipeline"
   git push origin main
   ```

2. Configure secrets in GitHub

3. Monitor first workflow run in Actions tab

4. Customize deployment manifests for your OpenShift setup

## Support

For issues:
- Check workflow logs in GitHub Actions
- Review [GitHub Actions documentation](https://docs.github.com/en/actions)
- Check [Trivy documentation](https://aquasecurity.github.io/trivy/)
