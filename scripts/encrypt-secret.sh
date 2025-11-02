#!/bin/bash
# Script to encrypt secrets from a .env file using kubeseal for Sealed Secrets
# Usage: ./encrypt-secret.sh <path-to-.env-file> <namespace>
# Example: ./encrypt-secret.sh .env auth-dev

set -e

if [ $# -lt 2 ]; then
  echo "Usage: $0 <path-to-.env-file> <namespace>"
  echo "Example: $0 .env auth-dev"
  echo ""
  echo "The .env file should contain key-value pairs in the format:"
  echo "  KEY1=value1"
  echo "  KEY2=value2"
  exit 1
fi

ENV_FILE=$1
NAMESPACE=$2

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: File '$ENV_FILE' not found"
  exit 1
fi

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
  echo "Error: kubeseal is not installed"
  echo "Install it from: https://github.com/bitnami-labs/sealed-secrets/releases"
  echo "Or via brew: brew install kubeseal"
  exit 1
fi

echo "Reading secrets from '$ENV_FILE' for namespace '$NAMESPACE'..."
echo ""

# Create temporary directory for processing
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Process each line in the .env file
ENCRYPTED_SECRETS=()
LINE_NUM=0

while IFS= read -r line || [ -n "$line" ]; do
  LINE_NUM=$((LINE_NUM + 1))
  
  # Skip empty lines and comments
  if [[ -z "$line" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi
  
  # Parse KEY=VALUE format
  if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
    KEY="${BASH_REMATCH[1]}"
    VALUE="${BASH_REMATCH[2]}"
    
    # Remove quotes if present
    VALUE=$(echo "$VALUE" | sed -e 's/^["'\'']//' -e 's/["'\'']$//')
    
    # Convert key to lowercase with hyphens (for Kubernetes secret key naming)
    SECRET_KEY=$(echo "$KEY" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    
    # Create temporary file with secret value
    TEMP_FILE="$TEMP_DIR/$SECRET_KEY"
    echo -n "$VALUE" > "$TEMP_FILE"
    
    # Encrypt the secret
    echo "Encrypting '$KEY'..."
    ENCRYPTED_VALUE=$(kubeseal --raw --from-file="$TEMP_FILE" -n "$NAMESPACE" --controller-name=sealed-secrets --controller-namespace=kube-system --name="$SECRET_KEY")
    
    # Store the encrypted value
    ENCRYPTED_SECRETS+=("$SECRET_KEY:$ENCRYPTED_VALUE")
  else
    echo "Warning: Skipping invalid line $LINE_NUM: $line"
  fi
done < "$ENV_FILE"

# Output results
echo ""
echo "=========================================="
echo "Encrypted secrets for sealedSecrets.data:"
echo "=========================================="
echo ""

if [ ${#ENCRYPTED_SECRETS[@]} -eq 0 ]; then
  echo "No valid secrets found in the .env file"
  exit 1
fi

# Output in YAML format
for secret in "${ENCRYPTED_SECRETS[@]}"; do
  KEY="${secret%%:*}"
  VALUE="${secret#*:}"
  echo "  $KEY: $VALUE"
done

echo ""
echo "=========================================="
echo "Copy the above lines to your values file under sealedSecrets.data"
echo "=========================================="
echo ""


