#!/bin/bash

# Quick Start Script for Local AI Kubernetes Deployment
# This script automates the initial setup process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
K8S_REPO_URL="${K8S_REPO_URL:=https://github.com/your-username/local-ai-packaged.git}"
KUBECONFIG="${KUBECONFIG:=$HOME/.kube/config}"
NAMESPACE_PREFIX="local-ai"

# Functions
print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    print_success "kubectl is installed"

    # Check kubeseal
    if ! command -v kubeseal &> /dev/null; then
        print_warning "kubeseal not found. You'll need to encrypt secrets manually."
        print_warning "Install from: https://github.com/bitnami-labs/sealed-secrets/releases"
    else
        print_success "kubeseal is installed"
    fi

    # Check argocd
    if ! command -v argocd &> /dev/null; then
        print_warning "argocd CLI not found. You can use ArgoCD web UI instead."
    else
        print_success "argocd CLI is installed"
    fi

    # Check git
    if ! command -v git &> /dev/null; then
        print_error "git not found. Please install git."
        exit 1
    fi
    print_success "git is installed"
}

verify_cluster() {
    print_header "Verifying Kubernetes Cluster"

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Check KUBECONFIG."
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"

    # Check nodes
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    echo -e "  Cluster nodes: ${BLUE}$NODE_COUNT${NC}"

    # Check ArgoCD
    if kubectl get ns argocd &> /dev/null; then
        print_success "ArgoCD namespace found"
    else
        print_error "ArgoCD not installed. Please install ArgoCD first."
        exit 1
    fi

    # Check cert-manager
    if kubectl get ns cert-manager &> /dev/null; then
        print_success "cert-manager namespace found"
    else
        print_warning "cert-manager not found. Certificate provisioning will fail."
    fi

    # Check Nginx Ingress
    if kubectl get ns ingress-nginx &> /dev/null; then
        print_success "Nginx Ingress Controller found"
    else
        print_warning "Nginx Ingress Controller not found. Ingress will not work."
    fi

    # Check Sealed Secrets
    if kubectl get deploy -n kube-system sealed-secrets-controller &> /dev/null; then
        print_success "Sealed Secrets Controller found"
    else
        print_warning "Sealed Secrets not installed. Secrets encryption will fail."
    fi
}

create_namespaces() {
    print_header "Creating Namespaces"

    for ns in local-ai-system local-ai-n8n local-ai-flowise local-ai-data local-ai-search; do
        if kubectl get ns "$ns" &> /dev/null; then
            print_warning "Namespace $ns already exists"
        else
            kubectl create ns "$ns"
            print_success "Created namespace $ns"
        fi
    done
}

deploy_sealed_secrets() {
    print_header "Preparing Sealed Secrets"

    print_warning "Before proceeding, you must encrypt your secrets!"
    print_warning "See: k8s/docs/KEYCLOAK-SETUP.md and k8s/docs/MIGRATION.md"
    echo ""
    read -p "Have you encrypted all secrets? (yes/no) " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Please encrypt secrets first before deploying."
        exit 1
    fi

    print_success "Ready to deploy sealed secrets"
}

deploy_supporting_services() {
    print_header "Deploying Supporting Services"

    # Redis
    print_warning "Deploying Redis..."
    kubectl apply -f k8s/apps/redis/deployment.yaml
    kubectl wait --for=condition=ready pod -l app=redis -n local-ai-system --timeout=300s 2>/dev/null || {
        print_warning "Redis deployment in progress (this may take a few minutes)"
    }
    print_success "Redis deployment submitted"

    # OAuth2 Proxy
    print_warning "Deploying OAuth2 Proxy..."
    # Note: sealed secret must exist
    if ! kubectl get secret -n local-ai-system oauth2-proxy-secrets &> /dev/null; then
        print_error "oauth2-proxy-secrets not found. Please create sealed secret first."
        return 1
    fi
    kubectl apply -f k8s/apps/_common/oauth2-proxy-base.yaml
    print_success "OAuth2 Proxy deployment submitted"
}

deploy_data_layer() {
    print_header "Deploying Data Layer"

    # PostgreSQL
    print_warning "Deploying PostgreSQL (this may take 3-5 minutes)..."
    kubectl apply -f k8s/apps/postgres/statefulset.yaml
    print_success "PostgreSQL deployment submitted"

    # Qdrant
    print_warning "Deploying Qdrant..."
    kubectl apply -f k8s/apps/qdrant/statefulset.yaml
    print_success "Qdrant deployment submitted"

    # Neo4j
    print_warning "Deploying Neo4j (this may take 3-5 minutes)..."
    kubectl apply -f k8s/apps/neo4j/statefulset.yaml
    print_success "Neo4j deployment submitted"

    print_warning "Waiting for data layer services to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n local-ai-data --timeout=600s 2>/dev/null || true
    kubectl wait --for=condition=ready pod -l app=qdrant -n local-ai-data --timeout=300s 2>/dev/null || true
    kubectl wait --for=condition=ready pod -l app=neo4j -n local-ai-data --timeout=600s 2>/dev/null || true
}

deploy_applications() {
    print_header "Deploying Applications via ArgoCD"

    print_warning "Deploying n8n..."
    kubectl apply -f k8s/argocd/applications.yaml | grep n8n || true

    print_warning "Deploying Flowise..."
    # The applications.yaml will handle this via ArgoCD

    print_warning "Deploying SearXNG..."
    # The applications.yaml will handle this via ArgoCD

    print_success "Applications submitted to ArgoCD"
    print_warning "Check ArgoCD dashboard to monitor sync: https://argocd.mylegion5pro.me"
}

verify_deployment() {
    print_header "Verifying Deployment"

    echo ""
    echo "Checking namespace status:"
    kubectl get ns | grep local-ai

    echo ""
    echo "Checking pod status:"
    kubectl get pods -A | grep local-ai || print_warning "No pods running yet (still deploying)"

    echo ""
    echo "Checking Ingress:"
    kubectl get ingress -A | grep local-ai || print_warning "Ingress not yet created"

    echo ""
    echo "Checking Certificates:"
    kubectl get certificate -A 2>/dev/null | grep local-ai || print_warning "Certificates not yet created"

    echo ""
    print_success "Deployment verification complete"
}

next_steps() {
    print_header "Next Steps"

    echo ""
    echo "1. Configure Keycloak OAuth2 clients:"
    echo "   See: k8s/docs/KEYCLOAK-SETUP.md"
    echo ""
    echo "2. Update Nginx Proxy Manager routing:"
    echo "   See: k8s/docs/NGINX-PROXY-MANAGER.md"
    echo ""
    echo "3. Monitor ArgoCD sync status:"
    echo "   kubectl logs -f deployment/argocd-application-controller -n argocd"
    echo ""
    echo "4. Test services:"
    echo "   https://n8n.lupulup.com"
    echo "   https://flowise.lupulup.com"
    echo "   https://neo4j.lupulup.com"
    echo "   https://searxng.lupulup.com"
    echo ""
    echo "5. For detailed migration guide, see:"
    echo "   k8s/docs/MIGRATION.md"
    echo ""
}

# Main execution
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Local AI Kubernetes Quick Start       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    echo ""

    verify_cluster
    echo ""

    create_namespaces
    echo ""

    deploy_sealed_secrets
    echo ""

    deploy_supporting_services
    echo ""

    deploy_data_layer
    echo ""

    deploy_applications
    echo ""

    verify_deployment
    echo ""

    next_steps
    echo ""

    print_success "Quick start completed!"
    echo ""
}

# Run main function
main "$@"
