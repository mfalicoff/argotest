#!/bin/bash
set -e

# Quick start script for deploying arr-stack with ArgoCD

echo "==================================="
echo "arr-stack ArgoCD Quick Start"
echo "==================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi
echo "✅ kubectl found"

if ! command -v argocd &> /dev/null; then
    echo "⚠️  argocd CLI not found. Continuing without CLI..."
else
    echo "✅ argocd CLI found"
fi

# Check if ArgoCD is installed
echo ""
echo "Checking if ArgoCD is installed..."
if ! kubectl get namespace argocd &> /dev/null; then
    echo "❌ ArgoCD namespace not found"
    echo ""
    read -p "Do you want to install ArgoCD? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing ArgoCD..."
        kubectl create namespace argocd
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        
        echo "Waiting for ArgoCD to be ready..."
        kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
        
        echo ""
        echo "✅ ArgoCD installed successfully"
        echo ""
        echo "To access ArgoCD UI:"
        echo "1. Get the admin password:"
        echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
        echo "2. Port forward:"
        echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
        echo "3. Open: https://localhost:8080"
        echo "4. Login with username: admin, password: (from step 1)"
    else
        echo "Please install ArgoCD first: https://argo-cd.readthedocs.io/en/stable/getting_started/"
        exit 1
    fi
else
    echo "✅ ArgoCD is installed"
fi

# Check for customization
echo ""
echo "==================================="
echo "Configuration"
echo "==================================="
echo ""
echo "Before deploying, you should customize:"
echo "1. Repository URL in argocd/application.yaml"
echo "2. Environment values in environments/production/values.yaml"
echo "3. Storage paths, domain, timezone, etc."
echo ""
read -p "Have you customized the configuration? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Please customize the following files:"
    echo "- argocd/application.yaml (set your Git repo URL)"
    echo "- environments/production/values.yaml (set your domain, storage paths, etc.)"
    echo ""
    echo "Then run this script again."
    exit 0
fi

# Deploy
echo ""
echo "==================================="
echo "Deploying arr-stack"
echo "==================================="
echo ""

read -p "Deploy using which method? (1=Application, 2=ApplicationSet, 3=Manual via CLI) " -n 1 -r
echo ""

case $REPLY in
    1)
        echo "Deploying using Application manifest..."
        kubectl apply -f argocd/application.yaml
        echo ""
        echo "✅ Application deployed"
        echo ""
        echo "Check status with:"
        echo "  argocd app get arr-stack"
        echo "  kubectl get application -n argocd"
        ;;
    2)
        echo "Deploying using ApplicationSet..."
        kubectl apply -f argocd/applicationset.yaml
        echo ""
        echo "✅ ApplicationSet deployed"
        echo ""
        echo "This will create applications for each environment in environments/"
        echo ""
        echo "Check status with:"
        echo "  argocd app list"
        echo "  kubectl get applicationset -n argocd"
        ;;
    3)
        if ! command -v argocd &> /dev/null; then
            echo "❌ argocd CLI not found. Please install it or use option 1 or 2."
            exit 1
        fi
        
        echo "Enter your Git repository URL:"
        read -r REPO_URL
        
        echo "Deploying via ArgoCD CLI..."
        argocd app create arr-stack \
          --repo "$REPO_URL" \
          --path arr-stack \
          --dest-namespace media \
          --dest-server https://kubernetes.default.svc \
          --sync-policy automated \
          --auto-prune \
          --self-heal \
          --helm-set-file values=environments/production/values.yaml
        
        echo ""
        echo "✅ Application created"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "==================================="
echo "Next Steps"
echo "==================================="
echo ""
echo "1. Check ArgoCD UI at: https://localhost:8080 (if port-forwarded)"
echo "2. Verify pods are running:"
echo "   kubectl get pods -n media"
echo "3. Check ingress:"
echo "   kubectl get ingress -n media"
echo "4. Access your services at:"
echo "   https://sonarr.your-domain.com"
echo "   https://radarr.your-domain.com"
echo "   etc."
echo ""
echo "For troubleshooting, see: ARGOCD-DEPLOYMENT.md"
echo ""
echo "Happy automating! 🎬"
