#!/bin/bash

# Script to configure ArgoCD to use this GitOps repository
# Usage: ./scripts/setup-argocd.sh [config-file]
# If config-file is provided, it will be used as KUBECONFIG

set -e

# Use config file if provided, otherwise use default KUBECONFIG
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${1:-$REPO_ROOT/config}"

if [ -f "$CONFIG_FILE" ]; then
    export KUBECONFIG="$CONFIG_FILE"
    echo "✓ Using kubeconfig: $CONFIG_FILE"
else
    echo "⚠️  Config file not found: $CONFIG_FILE"
    echo "   Using default KUBECONFIG"
fi

REPO_URL="https://github.com/projeto-comp-distribuida/git-ops.git"
ARGOCD_NAMESPACE="argocd"

echo "🚀 Setting up ArgoCD to use this GitOps repository..."
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if argocd CLI is available
if ! command -v argocd &> /dev/null; then
    echo "⚠️  ArgoCD CLI not found. Installing instructions:"
    echo "   Visit: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    echo ""
    echo "Alternative: You can use kubectl to apply the repository and applications directly."
    echo ""
    read -p "Continue with kubectl-only approach? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    USE_KUBECTL_ONLY=true
else
    USE_KUBECTL_ONLY=false
fi

# Function to add repository using ArgoCD CLI
add_repo_cli() {
    echo "📦 Adding repository to ArgoCD..."
    
    # Check if repo already exists
    if argocd repo list | grep -q "$REPO_URL"; then
        echo "✓ Repository already exists in ArgoCD"
    else
        echo "Adding repository: $REPO_URL"
        # For public repos, no credentials needed
        # For private repos, you would use: argocd repo add $REPO_URL --username <user> --password <pass>
        if argocd repo add "$REPO_URL"; then
            echo "✓ Repository added successfully"
        else
            echo "❌ Failed to add repository"
            exit 1
        fi
    fi
}

# Function to add repository using kubectl (Repository CRD)
add_repo_kubectl() {
    echo "📦 Adding repository to ArgoCD via kubectl..."
    
    # Check if Repository CRD exists
    if ! kubectl get crd repositories.argoproj.io &> /dev/null; then
        echo "⚠️  Repository CRD not found. ArgoCD might not be installed correctly."
        echo "   Trying to create Secret directly..."
        add_repo_secret
        return
    fi
    
    # Check if repo already exists
    if kubectl get secret -n "$ARGOCD_NAMESPACE" -l argocd.argoproj.io/secret-type=repository --field-selector metadata.name=repo-* 2>/dev/null | grep -q "repo-"; then
        echo "✓ Repository secret already exists"
    else
        echo "Creating repository secret..."
        kubectl create secret generic repo-github-git-ops \
            --from-literal=type=git \
            --from-literal=url="$REPO_URL" \
            --namespace="$ARGOCD_NAMESPACE" \
            --dry-run=client -o yaml | kubectl apply -f -
        echo "✓ Repository secret created"
    fi
}

# Function to add repository as ArgoCD Secret
add_repo_secret() {
    echo "📦 Creating repository secret in ArgoCD namespace..."
    
    # Create a secret with repository information
    # For public repos, we don't need credentials
    kubectl create secret generic repo-github-git-ops \
        --from-literal=type=git \
        --from-literal=url="$REPO_URL" \
        --namespace="$ARGOCD_NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Label it so ArgoCD recognizes it
    kubectl label secret repo-github-git-ops \
        argocd.argoproj.io/secret-type=repository \
        --namespace="$ARGOCD_NAMESPACE" \
        --overwrite
    
    echo "✓ Repository secret created and labeled"
}

# Add repository
if [ "$USE_KUBECTL_ONLY" = true ]; then
    add_repo_kubectl
else
    add_repo_cli || add_repo_kubectl
fi

echo ""
echo "📋 Applying ArgoCD Application manifests..."

# Apply all ArgoCD Application manifests
APPS_DIR="apps/argocd"
if [ ! -d "$APPS_DIR" ]; then
    echo "❌ Directory $APPS_DIR not found"
    exit 1
fi

# Apply each application
for app_file in "$APPS_DIR"/*.yaml; do
    if [ -f "$app_file" ]; then
        app_name=$(basename "$app_file" .yaml)
        echo "  Applying: $app_name"
        kubectl apply -f "$app_file"
    fi
done

echo ""
echo "✅ Setup complete!"
echo ""
echo "📊 Check application status with:"
echo "   kubectl get applications -n argocd"
echo ""
echo "🌐 Or access ArgoCD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Then open: https://localhost:8080"
echo ""
echo "   Default credentials:"
echo "   Username: admin"
echo "   Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"

