#!/bin/bash
# Kubernetes Deployment Script for Bookstore Application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_info() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check prerequisites
print_header "Checking Prerequisites"

# Check for kubectl or oc
if command -v oc &> /dev/null; then
    CLI="oc"
    print_info "Using OpenShift CLI (oc)"
elif command -v kubectl &> /dev/null; then
    CLI="kubectl"
    print_info "Using Kubernetes CLI (kubectl)"
else
    print_error "Neither 'oc' nor 'kubectl' found. Please install one."
    exit 1
fi

# Check for kustomize (optional)
if command -v kustomize &> /dev/null; then
    print_info "Kustomize found"
else
    print_warning "Kustomize not found (optional, $CLI supports -k flag)"
fi

# Check cluster connection
print_header "Checking Cluster Connection"

if $CLI cluster-info &> /dev/null; then
    print_info "Connected to cluster"
    $CLI cluster-info
else
    print_error "Not connected to any cluster. Please login first."
    echo "For OpenShift: oc login <cluster-url>"
    echo "For Kubernetes: kubectl config use-context <context-name>"
    exit 1
fi

# Get deployment environment
print_header "Configuration"

read -p "Enter container registry (default: ghcr.io): " REGISTRY
REGISTRY="${REGISTRY:-ghcr.io}"

read -p "Enter repository owner/org (default: your-org): " ORG
ORG="${ORG:-your-org}"

read -p "Enter image tag (default: main): " TAG
TAG="${TAG:-main}"

read -p "Enter number of backend replicas (default: 2): " BACKEND_REPLICAS
BACKEND_REPLICAS="${BACKEND_REPLICAS:-2}"

read -p "Enter number of frontend replicas (default: 2): " FRONTEND_REPLICAS
FRONTEND_REPLICAS="${FRONTEND_REPLICAS:-2}"

if [ "$CLI" = "oc" ]; then
    read -p "Enter OpenShift route host (default: bookstore.apps.example.com): " ROUTE_HOST
    ROUTE_HOST="${ROUTE_HOST:-bookstore.apps.example.com}"
    read -p "Enter API route host (default: api.bookstore.apps.example.com): " API_ROUTE_HOST
    API_ROUTE_HOST="${API_ROUTE_HOST:-api.bookstore.apps.example.com}"
fi

print_info "Registry: $REGISTRY"
print_info "Organization: $ORG"
print_info "Tag: $TAG"
print_info "Backend replicas: $BACKEND_REPLICAS"
print_info "Frontend replicas: $FRONTEND_REPLICAS"

if [ "$CLI" = "oc" ]; then
    print_info "Route host: $ROUTE_HOST"
    print_info "API route host: $API_ROUTE_HOST"
fi

# Confirm deployment
echo ""
read -p "Proceed with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled"
    exit 1
fi

# Deploy
print_header "Deploying to Kubernetes"

# Create temp kustomization with overrides
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy base to temp directory
cp -r k8s/base/* "$TEMP_DIR/"

# Update kustomization.yaml with custom values
cat >> "$TEMP_DIR/kustomization.yaml" <<EOF

# Custom patches for deployment
patches:
  - target:
      kind: Deployment
      name: backend
    patch: |-
      - op: replace
        path: /spec/replicas
        value: $BACKEND_REPLICAS
  - target:
      kind: Deployment
      name: frontend
    patch: |-
      - op: replace
        path: /spec/replicas
        value: $FRONTEND_REPLICAS
  - target:
      kind: Deployment
      name: backend
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: $REGISTRY/$ORG/bookstore/backend:$TAG
  - target:
      kind: Deployment
      name: frontend
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/image
        value: $REGISTRY/$ORG/bookstore/frontend:$TAG
EOF

if [ "$CLI" = "oc" ]; then
    cat >> "$TEMP_DIR/kustomization.yaml" <<EOF
  - target:
      kind: Route
      name: bookstore
    patch: |-
      - op: replace
        path: /spec/host
        value: $ROUTE_HOST
  - target:
      kind: Route
      name: bookstore-api
    patch: |-
      - op: replace
        path: /spec/host
        value: $API_ROUTE_HOST
EOF
fi

# Apply manifests
print_info "Applying manifests..."
$CLI apply -k "$TEMP_DIR"

# Wait for deployments
print_header "Waiting for Deployments"

print_info "Waiting for MySQL..."
$CLI rollout status statefulset/mysql -n bookstore --timeout=5m || true

print_info "Waiting for Redis..."
sleep 10  # Redis deployment takes a bit

print_info "Waiting for Backend..."
$CLI rollout status deployment/backend -n bookstore --timeout=5m || true

print_info "Waiting for Frontend..."
$CLI rollout status deployment/frontend -n bookstore --timeout=5m || true

# Verify deployment
print_header "Deployment Verification"

print_info "Pods status:"
$CLI get pods -n bookstore

print_info "Services status:"
$CLI get svc -n bookstore

if [ "$CLI" = "oc" ]; then
    print_info "Routes:"
    $CLI get routes -n bookstore
    
    FRONTEND_URL=$(oc get route bookstore -n bookstore -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not ready yet")
    API_URL=$(oc get route bookstore-api -n bookstore -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not ready yet")
    
    print_header "Access URLs"
    echo "Frontend: http://$FRONTEND_URL"
    echo "API: http://$API_URL/api/health"
else
    print_warning "Using port-forward to access services (kubectl):"
    echo "Frontend: kubectl port-forward -n bookstore svc/frontend 8080:80"
    echo "API: kubectl port-forward -n bookstore svc/backend 3000:3000"
fi

print_header "Deployment Complete ✓"
echo ""
print_info "To view logs:"
echo "  Backend:  $CLI logs -n bookstore -l app=backend -f"
echo "  Frontend: $CLI logs -n bookstore -l app=frontend -f"
echo "  MySQL:    $CLI logs -n bookstore -l app=mysql -f"
echo "  Redis:    $CLI logs -n bookstore -l app=redis -f"
echo ""
print_info "To delete deployment:"
echo "  $CLI delete -k k8s/base/"
