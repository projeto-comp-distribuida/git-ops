#!/bin/bash
# Script to create Kubernetes secrets from .env file
# Usage: ./scripts/create-secrets.sh <service-name> <namespace>
# Example: ./scripts/create-secrets.sh auth auth-dev

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${KUBECONFIG:-$REPO_ROOT/config}"

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <service-name> <namespace>"
    echo "Example: $0 auth auth-dev"
    exit 1
fi

SERVICE_NAME=$1
NAMESPACE=$2

if [ -f "$CONFIG_FILE" ]; then
    export KUBECONFIG="$CONFIG_FILE"
    echo "✓ Using kubeconfig: $CONFIG_FILE"
else
    echo "⚠️  Config file not found: $CONFIG_FILE"
    echo "   Using default KUBECONFIG"
fi

ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found at $ENV_FILE"
    exit 1
fi

echo "📄 Loading secrets from $ENV_FILE"
source "$ENV_FILE"

# Check if namespace exists, create if not
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "⚠️  Namespace $NAMESPACE does not exist, creating it..."
    kubectl create namespace "$NAMESPACE"
fi

SECRET_NAME="${SERVICE_NAME}-dev-secrets"

echo "🔐 Creating secret: $SECRET_NAME in namespace: $NAMESPACE"
echo ""

# Create secret from .env variables
kubectl create secret generic "$SECRET_NAME" \
    --from-literal=auth0-domain="$AUTH0_DOMAIN" \
    --from-literal=auth0-client-id="$AUTH0_CLIENT_ID" \
    --from-literal=auth0-client-secret="$AUTH0_CLIENT_SECRET" \
    --from-literal=auth0-audience="$AUTH0_AUDIENCE" \
    --from-literal=spring-datasource-url="$SPRING_DATASOURCE_URL" \
    --from-literal=spring-datasource-username="$SPRING_DATASOURCE_USERNAME" \
    --from-literal=spring-datasource-password="$SPRING_DATASOURCE_PASSWORD" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✅ Secret created successfully!"
echo ""
echo "The secret '$SECRET_NAME' is now available in namespace '$NAMESPACE'"
echo "Your Helm charts will reference this secret automatically."

