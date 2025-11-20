#!/bin/bash
# Script to create Kubernetes secrets from .env file
#
# Single:
#   Usage: ./scripts/create-secrets.sh <service-name> <namespace>
#   Example: ./scripts/create-secrets.sh auth auth-dev
#
# Batch (all services into one namespace):
#   Usage: ./scripts/create-secrets.sh --all-in-namespace <namespace>
#   Example: ./scripts/create-secrets.sh --all-in-namespace distrischool
#
# Batch (matrix file with pairs "service namespace" per line):
#   Usage: ./scripts/create-secrets.sh --matrix <file>
#   Example: ./scripts/create-secrets.sh --matrix services-namespaces.txt

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${KUBECONFIG:-$REPO_ROOT/config}"

MODE="single"
SERVICE_NAME=""
NAMESPACE=""
MATRIX_FILE=""

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <service-name> <namespace> | --all-in-namespace <namespace> | --matrix <file>"
    echo "Examples:"
    echo "  $0 auth auth-dev"
    echo "  $0 --all-in-namespace distrischool"
    echo "  $0 --matrix services-namespaces.txt"
    exit 1
fi

if [ "$1" = "--all-in-namespace" ]; then
    if [ "$#" -lt 2 ]; then
        echo "❌ Error: missing <namespace> for --all-in-namespace"
        exit 1
    fi
    MODE="all_in_namespace"
    NAMESPACE=$2
elif [ "$1" = "--matrix" ]; then
    if [ "$#" -lt 2 ]; then
        echo "❌ Error: missing <file> for --matrix"
        exit 1
    fi
    MODE="matrix"
    MATRIX_FILE=$2
    if [ ! -f "$MATRIX_FILE" ]; then
        echo "❌ Error: matrix file not found at $MATRIX_FILE"
        exit 1
    fi
else
    if [ "$#" -lt 2 ]; then
        echo "Usage: $0 <service-name> <namespace> | --all-in-namespace <namespace> | --matrix <file>"
        exit 1
    fi
    MODE="single"
    SERVICE_NAME=$1
    NAMESPACE=$2
fi

APPS_DIR="$REPO_ROOT/apps"

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

create_or_update_secret() {
    local svc_name="$1"
    local ns_name="$2"
    local secret_name="${svc_name}-dev-secrets"

    # Ensure namespace exists
    if ! kubectl get namespace "$ns_name" &> /dev/null; then
        echo "⚠️  Namespace $ns_name does not exist, creating it..."
        kubectl create namespace "$ns_name"
    fi

    echo "🔐 Creating/Updating secret: $secret_name in namespace: $ns_name"

    # Determine service-specific database URL
    # Check for service-specific variable first (e.g., SPRING_DATASOURCE_URL_GESTAO_DE_PROFESSORES)
    local svc_upper=$(echo "$svc_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local db_url_var="SPRING_DATASOURCE_URL_${svc_upper}"
    local db_url="${!db_url_var:-}"

    # If service-specific URL not found, try to derive from base URL
    if [ -z "$db_url" ] && [ -n "$SPRING_DATASOURCE_URL" ]; then
        # Map service names to database names
        case "$svc_name" in
            auth)
                db_url=$(echo "$SPRING_DATASOURCE_URL" | sed 's|/[^/]*$|/distrischool_auth|')
                ;;
            gestao-de-alunos)
                db_url=$(echo "$SPRING_DATASOURCE_URL" | sed 's|/[^/]*$|/distrischool_students|')
                ;;
            gestao-de-professores)
                db_url=$(echo "$SPRING_DATASOURCE_URL" | sed 's|/[^/]*$|/distrischool_teachers|')
                ;;
            *)
                # Default: use as-is or try to derive database name from service name
                db_url="$SPRING_DATASOURCE_URL"
                echo "⚠️  Warning: No specific database mapping for service '$svc_name', using base URL"
                ;;
        esac
    fi

    # Fallback to base URL if still empty
    if [ -z "$db_url" ]; then
        db_url="$SPRING_DATASOURCE_URL"
        echo "⚠️  Warning: Using base SPRING_DATASOURCE_URL for service '$svc_name'"
    fi

    echo "   Database URL: ${db_url}"
    echo "   Using database: $(echo "$db_url" | sed 's|.*/\([^/]*\)$|\1|')"

    kubectl create secret generic "$secret_name" \
        --from-literal=auth0-domain="$AUTH0_DOMAIN" \
        --from-literal=auth0-client-id="$AUTH0_CLIENT_ID" \
        --from-literal=auth0-client-secret="$AUTH0_CLIENT_SECRET" \
        --from-literal=auth0-audience="$AUTH0_AUDIENCE" \
        --from-literal=spring-datasource-url="$db_url" \
        --from-literal=spring-datasource-username="$SPRING_DATASOURCE_USERNAME" \
        --from-literal=spring-datasource-password="$SPRING_DATASOURCE_PASSWORD" \
        -n "$ns_name" \
        --dry-run=client -o yaml | kubectl apply -f -

    echo "✅ Secret '$secret_name' applied to namespace '$ns_name'"
    echo ""
}

list_services() {
    # List app directories as service names, excluding infra/non-service entries
    if [ -d "$APPS_DIR" ]; then
        find "$APPS_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | grep -Ev '^(argocd|kafka|kafka-ui|redis|zookeeper)$' | sort
    else
        echo ""
    fi
}

case "$MODE" in
    single)
        create_or_update_secret "$SERVICE_NAME" "$NAMESPACE"
        ;;
    all_in_namespace)
        SERVICES=$(list_services)
        if [ -z "$SERVICES" ]; then
            echo "❌ Error: could not determine services under $APPS_DIR"
            exit 1
        fi
        echo "📦 Processing services in '$APPS_DIR' for namespace '$NAMESPACE'"
        echo "$SERVICES" | while read -r svc; do
            [ -z "$svc" ] && continue
            create_or_update_secret "$svc" "$NAMESPACE"
        done
        ;;
    matrix)
        echo "📚 Reading service/namespace pairs from $MATRIX_FILE"
        while read -r svc ns; do
            # skip empty and comment lines
            if echo "$svc" | grep -qE '^(#|$)'; then
                continue
            fi
            if [ -z "$svc" ] || [ -z "$ns" ]; then
                continue
            fi
            create_or_update_secret "$svc" "$ns"
        done < "$MATRIX_FILE"
        ;;
    *)
        echo "❌ Error: unknown mode '$MODE'"
        exit 1
        ;;
esac

echo "All requested secrets are up to date."

