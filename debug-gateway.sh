#!/bin/bash
# Script to debug gateway and auth service connectivity
# This helps identify why the gateway is returning 500 errors

set -e

CONFIG_FILE="${KUBECONFIG:-./config}"

if [ -f "$CONFIG_FILE" ]; then
    export KUBECONFIG="$CONFIG_FILE"
    echo "✓ Using kubeconfig: $CONFIG_FILE"
else
    echo "⚠️  Config file not found: $CONFIG_FILE"
    echo "   Using default KUBECONFIG"
fi

echo "🔍 Debugging Gateway and Auth Service Connectivity"
echo "=================================================="
echo ""

echo "1. Checking Auth Service in auth-dev namespace:"
echo "-----------------------------------------------"
kubectl get svc -n auth-dev
echo ""

echo "2. Checking Auth Pods:"
echo "----------------------"
kubectl get pods -n auth-dev
echo ""

echo "3. Checking Gateway Service in api-gateway-dev namespace:"
echo "----------------------------------------------------------"
kubectl get svc -n api-gateway-dev
echo ""

echo "4. Checking Gateway Pods:"
echo "-------------------------"
kubectl get pods -n api-gateway-dev
echo ""

echo "5. Getting Auth Service Details:"
echo "--------------------------------"
AUTH_SVC=$(kubectl get svc -n auth-dev -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "NOT_FOUND")
if [ "$AUTH_SVC" != "NOT_FOUND" ]; then
    echo "Auth Service Name: $AUTH_SVC"
    kubectl describe svc "$AUTH_SVC" -n auth-dev
else
    echo "❌ No auth service found!"
fi
echo ""

echo "6. Checking Auth Pod Logs (last 50 lines):"
echo "-------------------------------------------"
AUTH_POD=$(kubectl get pods -n auth-dev -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "NOT_FOUND")
if [ "$AUTH_POD" != "NOT_FOUND" ]; then
    echo "Auth Pod: $AUTH_POD"
    kubectl logs "$AUTH_POD" -n auth-dev --tail=50 || echo "Failed to get logs"
else
    echo "❌ No auth pod found!"
fi
echo ""

echo "7. Checking Gateway Pod Logs (last 50 lines):"
echo "----------------------------------------------"
GATEWAY_POD=$(kubectl get pods -n api-gateway-dev -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "NOT_FOUND")
if [ "$GATEWAY_POD" != "NOT_FOUND" ]; then
    echo "Gateway Pod: $GATEWAY_POD"
    kubectl logs "$GATEWAY_POD" -n api-gateway-dev --tail=50 || echo "Failed to get logs"
else
    echo "❌ No gateway pod found!"
fi
echo ""

echo "8. Testing DNS resolution from Gateway Pod:"
echo "--------------------------------------------"
if [ "$GATEWAY_POD" != "NOT_FOUND" ]; then
    echo "Testing: auth-dev.auth-dev"
    kubectl exec -n api-gateway-dev "$GATEWAY_POD" -- nslookup auth-dev.auth-dev || echo "DNS lookup failed"
    echo ""
    echo "Testing: auth-dev-auth.auth-dev"
    kubectl exec -n api-gateway-dev "$GATEWAY_POD" -- nslookup auth-dev-auth.auth-dev || echo "DNS lookup failed"
fi
echo ""

echo "✅ Debug script completed!"
echo ""
echo "Next steps:"
echo "- Check the service name above and update gateway config if needed"
echo "- Verify auth service is running and healthy"
echo "- Check logs for specific error messages"

