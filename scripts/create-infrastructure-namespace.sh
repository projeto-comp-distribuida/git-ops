#!/bin/bash
# Script to create the infrastructure-dev namespace
# Usage: ./scripts/create-infrastructure-namespace.sh [config-file]

set -e

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

NAMESPACE="infrastructure-dev"

echo "🔧 Creating namespace: $NAMESPACE"
echo ""

# Check if namespace already exists
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "✓ Namespace $NAMESPACE already exists"
else
    echo "Creating namespace $NAMESPACE..."
    kubectl create namespace "$NAMESPACE"
    echo "✓ Namespace $NAMESPACE created successfully"
fi

echo ""
echo "✅ Done!"
echo ""
echo "You can now sync your ArgoCD applications:"
echo "  - redis-dev"
echo "  - kafka-dev"
echo "  - kafka-ui-dev"
echo "  - zookeeper-dev"





