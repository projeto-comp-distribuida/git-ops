#!/bin/bash
# Script to reset Kafka PVC in case of cluster ID mismatch
# Usage: ./scripts/reset-kafka-pvc.sh [namespace] [kafka-release-name]
#
# This script will:
# 1. Scale down Kafka deployment
# 2. Delete the PVC
# 3. Scale up Kafka deployment (which will create a new PVC)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${KUBECONFIG:-}"

if [ -f "$REPO_ROOT/config" ]; then
    export KUBECONFIG="$REPO_ROOT/config"
    echo "✓ Using kubeconfig: $REPO_ROOT/config"
elif [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    export KUBECONFIG="$CONFIG_FILE"
    echo "✓ Using kubeconfig: $CONFIG_FILE"
else
    echo "⚠️  Using default KUBECONFIG"
fi

NAMESPACE="${1:-infrastructure-dev}"
KAFKA_RELEASE="${2:-kafka}"

echo "🔧 Resetting Kafka PVC in namespace: $NAMESPACE"
echo "   Kafka release: $KAFKA_RELEASE"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "❌ Namespace $NAMESPACE does not exist"
    exit 1
fi

# Check if Kafka deployment exists
if ! kubectl get deployment "$KAFKA_RELEASE" -n "$NAMESPACE" &> /dev/null; then
    echo "❌ Kafka deployment '$KAFKA_RELEASE' not found in namespace $NAMESPACE"
    exit 1
fi

# Get PVC name
PVC_NAME="${KAFKA_RELEASE}-data"

echo "📋 Steps:"
echo "   1. Scale down Kafka deployment"
echo "   2. Delete PVC: $PVC_NAME"
echo "   3. Scale up Kafka deployment"
echo ""

read -p "⚠️  This will DELETE all Kafka data. Continue? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted"
    exit 1
fi

echo ""
echo "1️⃣  Scaling down Kafka deployment..."
kubectl scale deployment "$KAFKA_RELEASE" --replicas=0 -n "$NAMESPACE"

echo "   Waiting for pods to terminate..."
kubectl wait --for=delete pod -l app.kubernetes.io/name=kafka -n "$NAMESPACE" --timeout=60s || true

echo ""
echo "2️⃣  Deleting PVC: $PVC_NAME"
if kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" &> /dev/null; then
    kubectl delete pvc "$PVC_NAME" -n "$NAMESPACE"
    echo "   ✓ PVC deleted"
else
    echo "   ⚠️  PVC not found (may have been already deleted)"
fi

echo ""
echo "3️⃣  Scaling up Kafka deployment..."
kubectl scale deployment "$KAFKA_RELEASE" --replicas=1 -n "$NAMESPACE"

echo ""
echo "✅ Kafka reset complete!"
echo ""
echo "📊 Check Kafka status with:"
echo "   kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=kafka"
echo "   kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=kafka --tail=50"
echo ""

