#!/bin/bash
set -e

echo "===================================="
echo "ArgoCD Bootstrap"
echo "===================================="
echo ""

# Check if ArgoCD namespace exists
if kubectl get namespace argocd &> /dev/null; then
    echo "✅ ArgoCD namespace exists"
else
    echo "Creating ArgoCD namespace..."
    kubectl create namespace argocd
    echo "✅ Created ArgoCD namespace"
fi

# Check if ArgoCD is installed
if kubectl get deployment argocd-server -n argocd &> /dev/null; then
    echo "✅ ArgoCD is already installed"
else
    echo ""
    echo "Installing ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    echo ""
    echo "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    echo ""
    echo "✅ ArgoCD installed successfully!"
fi

echo ""
echo "===================================="
echo "ArgoCD Access"
echo "===================================="
echo ""

# Get admin password
echo "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ -z "$ARGOCD_PASSWORD" ]; then
    echo "⚠️  Could not retrieve admin password (may need to wait a moment)"
else
    echo "ArgoCD Admin Credentials:"
    echo "  Username: admin"
    echo "  Password: $ARGOCD_PASSWORD"
    echo ""
    echo "Save this password! You'll need it to access the ArgoCD UI."
fi

echo ""
echo "===================================="
echo "Next Steps"
echo "===================================="
echo ""
echo "1. Access ArgoCD UI (in a new terminal):"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Open: https://localhost:8080"
echo ""
echo "2. Deploy arr-stack:"
echo "   kubectl apply -f argocd-apps/root-app.yaml"
echo ""
echo "3. Watch deployment:"
echo "   kubectl get applications -n argocd -w"
echo ""
echo "✨ Bootstrap complete!"
