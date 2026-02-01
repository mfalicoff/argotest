#!/bin/bash
set -e

# GitOps Quick Start for arr-stack
# This script helps configure the repository for your cluster

echo "===================================="
echo "arr-stack GitOps Quick Setup"
echo "===================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi
echo "✅ kubectl found"

if ! command -v git &> /dev/null; then
    echo "❌ git not found. Please install git first."
    exit 1
fi
echo "✅ git found"

echo ""
echo "===================================="
echo "Configuration"
echo "===================================="
echo ""

# Get node name
echo "Getting your Kubernetes node name..."
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Detected node: $NODE_NAME"
echo ""

read -p "Is this correct? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please enter your node name:"
    read -r NODE_NAME
fi

# Get Git repo
echo ""
echo "What is your Git repository URL?"
echo "Example: https://github.com/username/arr-stack-helm.git"
read -r GIT_REPO

# Detect OS for sed compatibility
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS (BSD sed)
    SED_INPLACE="sed -i ''"
else
    # Linux (GNU sed)
    SED_INPLACE="sed -i"
fi

# Update node name in Kustomize overlay
echo ""
echo "Updating node name in infrastructure configuration..."
if [ -f "infrastructure/overlays/production/kustomization.yaml" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/your-actual-node-name/$NODE_NAME/g" infrastructure/overlays/production/kustomization.yaml
    else
        sed -i "s/your-actual-node-name/$NODE_NAME/g" infrastructure/overlays/production/kustomization.yaml
    fi
    echo "✅ Updated infrastructure/overlays/production/kustomization.yaml"
else
    echo "⚠️  File not found: infrastructure/overlays/production/kustomization.yaml"
fi

# Update node name in values.yaml
echo "Updating node name in arr-stack values..."
if [ -f "environments/production/values.yaml" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/your-node-name/$NODE_NAME/g" environments/production/values.yaml
    else
        sed -i "s/your-node-name/$NODE_NAME/g" environments/production/values.yaml
    fi
    echo "✅ Updated environments/production/values.yaml"
else
    echo "⚠️  File not found: environments/production/values.yaml"
fi

# Update Git repo URLs
echo "Updating Git repository URLs..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    find argocd-apps -name "*.yaml" -exec sed -i '' "s|https://github.com/mfalicoff/argotest.git|$GIT_REPO|g" {} \;
else
    find argocd-apps -name "*.yaml" -exec sed -i "s|https://github.com/mfalicoff/argotest.git|$GIT_REPO|g" {} \;
fi
echo "✅ Updated argocd-apps/*.yaml"

echo ""
echo "===================================="
echo "Review Changes"
echo "===================================="
echo ""

# Show what changed
echo "Changes made:"
git diff --stat || echo "No git repository detected"

echo ""
echo "===================================="
echo "Next Steps"
echo "===================================="
echo ""
echo "1. Review the changes:"
echo "   git diff"
echo ""
echo "2. Optionally update other settings:"
echo "   - Domain: environments/production/values.yaml"
echo "   - Storage paths: infrastructure/storage.yaml"
echo "   - Resource limits: environments/production/values.yaml"
echo ""
echo "3. Commit and push:"
echo "   git add ."
echo "   git commit -m 'Configure for my cluster'"
echo "   git push"
echo ""
echo "4. Deploy (ONLY kubectl command you'll ever need!):"
echo "   kubectl apply -f argocd-apps/root-app.yaml"
echo ""
echo "5. Watch it deploy:"
echo "   kubectl get applications -n argocd"
echo "   kubectl get pods -n media"
echo ""
echo "For detailed instructions, see: GITOPS-COMPLETE-GUIDE.md"
echo ""
echo "Happy GitOps! 🚀"
