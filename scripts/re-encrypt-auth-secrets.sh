#!/bin/bash
# Script to generate re-encrypted secrets for the auth service
# Usage: ./scripts/re-encrypt-auth-secrets.sh
# This will prompt for secret values and output encrypted values that can be copied to values-auth.yaml

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

NAMESPACE="auth-dev"

echo "🔐 Re-encrypting secrets for auth service"
echo "   Namespace: $NAMESPACE"
echo ""

# Check if kubeseal is available
if ! command -v kubeseal &> /dev/null; then
    echo "❌ kubeseal is not installed"
    echo "   Install from: https://github.com/bitnami-labs/sealed-secrets/releases"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "⚠️  Namespace $NAMESPACE does not exist, creating it..."
    kubectl create namespace "$NAMESPACE"
fi

# Load secrets from .env file
ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env file not found at $ENV_FILE"
    echo "   Please create the file with the following variables:"
    echo "   AUTH0_DOMAIN"
    echo "   AUTH0_CLIENT_ID"
    echo "   AUTH0_CLIENT_SECRET"
    echo "   AUTH0_AUDIENCE"
    echo "   SPRING_DATASOURCE_URL"
    echo "   SPRING_DATASOURCE_USERNAME"
    echo "   SPRING_DATASOURCE_PASSWORD"
    exit 1
fi

echo "📄 Loading secrets from $ENV_FILE"
echo ""

# Load .env file (handle comments and empty lines)
set -a
source "$ENV_FILE"
set +a

# Validate that all required variables are set
REQUIRED_VARS=(
    "AUTH0_DOMAIN"
    "AUTH0_CLIENT_ID"
    "AUTH0_CLIENT_SECRET"
    "AUTH0_AUDIENCE"
    "SPRING_DATASOURCE_URL"
    "SPRING_DATASOURCE_USERNAME"
    "SPRING_DATASOURCE_PASSWORD"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo "❌ Error: Missing required variables in .env file:"
    printf '   - %s\n' "${MISSING_VARS[@]}"
    exit 1
fi

echo "✓ All required secrets loaded from .env file"
echo ""

echo ""
echo "🔒 Encrypting secrets with current cluster's sealed-secrets controller..."

# Encrypt each secret
encrypt_secret() {
    local key=$1
    local value=$2
    echo -n "$value" | kubeseal --raw --from-file=/dev/stdin -n "$NAMESPACE" \
        --controller-name=sealed-secrets \
        --controller-namespace=kube-system \
        --name="$key" 2>/dev/null
}

AUTH0_DOMAIN_ENC=$(encrypt_secret "auth0-domain" "$AUTH0_DOMAIN")
AUTH0_CLIENT_ID_ENC=$(encrypt_secret "auth0-client-id" "$AUTH0_CLIENT_ID")
AUTH0_CLIENT_SECRET_ENC=$(encrypt_secret "auth0-client-secret" "$AUTH0_CLIENT_SECRET")
AUTH0_AUDIENCE_ENC=$(encrypt_secret "auth0-audience" "$AUTH0_AUDIENCE")
SPRING_DATASOURCE_URL_ENC=$(encrypt_secret "spring-datasource-url" "$SPRING_DATASOURCE_URL")
SPRING_DATASOURCE_USERNAME_ENC=$(encrypt_secret "spring-datasource-username" "$SPRING_DATASOURCE_USERNAME")
SPRING_DATASOURCE_PASSWORD_ENC=$(encrypt_secret "spring-datasource-password" "$SPRING_DATASOURCE_PASSWORD")

echo ""
echo "✅ Secrets encrypted!"
echo ""
echo "=========================================="
echo "Copy the following to environments/dev/values-auth.yaml"
echo "under sealedSecrets.data:"
echo "=========================================="
echo ""
echo "sealedSecrets:"
echo "  enabled: true"
echo "  secretName: \"auth-dev-secrets\""
echo "  data:"
echo "    auth0-domain: $AUTH0_DOMAIN_ENC"
echo "    auth0-client-id: $AUTH0_CLIENT_ID_ENC"
echo "    auth0-client-secret: $AUTH0_CLIENT_SECRET_ENC"
echo "    auth0-audience: $AUTH0_AUDIENCE_ENC"
echo "    spring-datasource-url: $SPRING_DATASOURCE_URL_ENC"
echo "    spring-datasource-username: $SPRING_DATASOURCE_USERNAME_ENC"
echo "    spring-datasource-password: $SPRING_DATASOURCE_PASSWORD_ENC"
echo ""
echo "=========================================="
echo "After updating the file, commit and push:"
echo "  git add environments/dev/values-auth.yaml"
echo "  git commit -m 'Re-encrypt auth secrets with current cluster key'"
echo "  git push"
echo "  ArgoCD will automatically sync the changes"
echo "=========================================="
