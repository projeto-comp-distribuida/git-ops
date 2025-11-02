#!/bin/bash
# Generic script to re-encrypt secrets for any service
# Usage: ./scripts/re-encrypt-secrets.sh <service-name> <namespace>
# Examples:
#   ./scripts/re-encrypt-secrets.sh auth auth-dev
#   ./scripts/re-encrypt-secrets.sh gestao-de-alunos gestao-de-alunos-dev
#   ./scripts/re-encrypt-secrets.sh gestao-de-professores gestao-de-professores-dev

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${KUBECONFIG:-$REPO_ROOT/config}"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <service-name> <namespace>"
  echo ""
  echo "Examples:"
  echo "  $0 auth auth-dev"
  echo "  $0 gestao-de-alunos gestao-de-alunos-dev"
  echo "  $0 gestao-de-professores gestao-de-professores-dev"
  exit 1
fi

SERVICE_NAME=$1
NAMESPACE=$2

# Determine the values file path based on service name
if [ "$SERVICE_NAME" = "auth" ]; then
  VALUES_FILE="$REPO_ROOT/environments/dev/values-auth.yaml"
  SECRET_NAME="auth-dev-secrets"
elif [ "$SERVICE_NAME" = "gestao-de-alunos" ]; then
  VALUES_FILE="$REPO_ROOT/environments/dev/values-gestao-de-alunos.yaml"
  SECRET_NAME="gestao-de-alunos-dev-secrets"
elif [ "$SERVICE_NAME" = "gestao-de-professores" ]; then
  VALUES_FILE="$REPO_ROOT/environments/dev/values-gestao-de-professores.yaml"
  SECRET_NAME="gestao-de-professores-dev-secrets"
else
  echo "Error: Unknown service name '$SERVICE_NAME'"
  echo "Supported services: auth, gestao-de-alunos, gestao-de-professores"
  exit 1
fi

if [ -f "$CONFIG_FILE" ]; then
    export KUBECONFIG="$CONFIG_FILE"
    echo "✓ Using kubeconfig: $CONFIG_FILE"
else
    echo "⚠️  Config file not found: $CONFIG_FILE"
    echo "   Using default KUBECONFIG"
fi

echo "🔐 Re-encrypting secrets for $SERVICE_NAME service"
echo "   Namespace: $NAMESPACE"
echo "   Values file: $VALUES_FILE"
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
echo "Copy the following to $VALUES_FILE"
echo "under sealedSecrets.data:"
echo "=========================================="
echo ""
echo "sealedSecrets:"
echo "  enabled: true"
echo "  secretName: \"$SECRET_NAME\""
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
echo "  git add $VALUES_FILE"
echo "  git commit -m 'Re-encrypt secrets for $SERVICE_NAME with current cluster key'"
echo "  git push"
echo "  ArgoCD will automatically sync the changes"
echo "=========================================="

