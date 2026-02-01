# Complete GitOps Setup - Zero kubectl apply Required

This is the **proper GitOps way** - everything is in Git, ArgoCD manages everything, no manual `kubectl apply` needed.

## 🎯 The GitOps Way

```
┌─────────────────────────────────────────────────────┐
│  You: Edit files in Git → Commit → Push             │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│  ArgoCD: Watches Git → Syncs to Cluster             │
│    1. Infrastructure (StorageClass, PVs, PVCs)      │
│    2. arr-stack (Sonarr, Radarr, etc.)              │
└─────────────────────────────────────────────────────┘
```

**No `kubectl apply` ever needed!** ✅

## 📁 Repository Structure

```
your-repo/
├── infrastructure/              # Storage infrastructure
│   ├── storage.yaml            # PVs, PVCs, StorageClass
│   ├── kustomization.yaml      # Base Kustomize config
│   └── overlays/
│       └── production/
│           └── kustomization.yaml  # Node-specific patches
│
├── arr-stack/                   # Helm chart (unchanged)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│
├── environments/                # Environment-specific values
│   └── production/
│       └── values.yaml
│
└── argocd-apps/                # ArgoCD Application definitions
    ├── root-app.yaml           # App of Apps (deploy this ONE file)
    ├── infrastructure-app.yaml  # Infrastructure Application
    └── arr-stack-app.yaml      # arr-stack Application
```

## 🚀 Complete Setup (GitOps Style)

### Step 0: Install ArgoCD (If Not Already Installed)

**First, check if ArgoCD is installed:**

```bash
kubectl get namespace argocd
```

If you get an error, ArgoCD is not installed. Install it:

```bash
# Run the bootstrap script
./bootstrap-argocd.sh

# Or manually:
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Access ArgoCD UI (optional but recommended):**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Step 1: Clone and Configure

```bash
# Clone your repo
git clone https://github.com/mfalicoff/argotest.git
cd arr-stack-helm

# Get your node name
kubectl get nodes
# NAME: my-k8s-node
```

### Step 2: Update Node Name (Only File Edit Needed)

Edit `infrastructure/overlays/production/kustomization.yaml`:

```yaml
patches:
  - target:
      kind: PersistentVolume
      name: arr-media-pv
    patch: |-
      - op: replace
        path: /spec/nodeAffinity/required/nodeSelectorTerms/0/matchExpressions/0/values/0
        value: my-k8s-node  # <-- Your actual node name

  - target:
      kind: PersistentVolume
      name: arr-downloads-pv
    patch: |-
      - op: replace
        path: /spec/nodeAffinity/required/nodeSelectorTerms/0/matchExpressions/0/values/0
        value: my-k8s-node  # <-- Your actual node name
```

### Step 3: Update Repository URLs

Update all `repoURL` fields in `argocd-apps/*.yaml`:

```bash
# Quick find and replace
find argocd-apps -name "*.yaml" -exec sed -i \
  's|https://github.com/mfalicoff/argotest.git|https://github.com/YOUR_ACTUAL_USERNAME/arr-stack-helm.git|g' {} \;
```

Or manually edit:
- `argocd-apps/root-app.yaml`
- `argocd-apps/infrastructure-app.yaml`
- `argocd-apps/arr-stack-app.yaml`

### Step 4: Update arr-stack Values

Edit `environments/production/values.yaml`:

```yaml
ingress:
  domain: mazilious.org  # Your domain

storage:
  media:
    type: pvc
    existingClaim: arr-media-pvc  # Managed by infrastructure app
  downloads:
    type: pvc
    existingClaim: arr-downloads-pvc

# Node affinity for all services
sonarr:
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - my-k8s-node  # Your node name

radarr:
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - my-k8s-node

jellyseerr:
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - my-k8s-node

prowlarr:
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - my-k8s-node

byparr:
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - my-k8s-node
```

### Step 5: Commit and Push to Git

```bash
git add .
git commit -m "Configure arr-stack for my cluster"
git push origin main
```

### Step 6: Deploy Everything (ONE Command)

This is the **ONLY** `kubectl` command you need:

```bash
kubectl apply -f argocd-apps/root-app.yaml
```

That's it! ✨

## 🎬 What Happens Next

ArgoCD automatically:

1. **Deploys root-app** (App of Apps)
2. **root-app creates**:
   - `infrastructure-app` (sync wave 0-2)
   - `arr-stack` (sync wave 10)
3. **infrastructure-app deploys** (in order):
   - StorageClass (`local-path`)
   - PersistentVolumes (media, downloads)
   - PersistentVolumeClaims
4. **arr-stack deploys**:
   - Waits for PVCs to be ready
   - Deploys all services (Sonarr, Radarr, etc.)
   - Creates Ingress resources

All automatically, in the right order! 🎯

## 📊 Verify Everything

```bash
# Check Applications
kubectl get applications -n argocd
# Should show:
# - arr-stack-root (parent)
# - arr-stack-infrastructure
# - arr-stack

# Check Storage
kubectl get storageclass
kubectl get pv
kubectl get pvc -n media

# Check arr-stack
kubectl get pods -n media
kubectl get ingress -n media
```

Or use ArgoCD UI:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

You'll see a beautiful application tree! 🌳

## 🔄 Making Changes (Pure GitOps)

### Change 1: Update Resource Limits

```bash
# Edit environments/production/values.yaml
vim environments/production/values.yaml

# Change:
sonarr:
  resources:
    limits:
      memory: 2Gi  # Increased from 1Gi

# Commit and push
git add environments/production/values.yaml
git commit -m "Increase Sonarr memory limit"
git push

# ArgoCD auto-syncs within 3 minutes
# Or manually: argocd app sync arr-stack
```

### Change 2: Add Storage

```bash
# Edit infrastructure/storage.yaml - add new PV
vim infrastructure/storage.yaml

# Add:
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: arr-music-pv
  annotations:
    argocd.argoproj.io/sync-wave: "1"
# ... rest of config

# Commit and push
git commit -am "Add music storage"
git push

# ArgoCD deploys new PV automatically
```

### Change 3: Disable a Service

```bash
# Edit environments/production/values.yaml
vim environments/production/values.yaml

jackett:
  enabled: false  # Changed from true

git commit -am "Disable Jackett"
git push

# ArgoCD removes Jackett resources
```

## 🎯 Sync Waves Explained

Sync waves control deployment order:

```
Wave 0: StorageClass
  ↓
Wave 1: PersistentVolumes
  ↓
Wave 2: PersistentVolumeClaims
  ↓
Wave 10: arr-stack (Sonarr, Radarr, etc.)
```

This ensures infrastructure exists before apps try to use it.

## 🌳 App of Apps Pattern

```
arr-stack-root (App of Apps)
├── arr-stack-infrastructure
│   ├── StorageClass: local-path
│   ├── PV: arr-media-pv
│   ├── PV: arr-downloads-pv
│   ├── PVC: arr-media-pvc
│   └── PVC: arr-downloads-pvc
└── arr-stack (Helm Release)
    ├── Deployment: sonarr
    ├── Deployment: radarr
    ├── Deployment: jellyseerr
    ├── Service: sonarr
    ├── Ingress: sonarr
    └── ... (all other resources)
```

## 📝 Alternative: Deploy Infrastructure and App Separately

If you prefer not using App of Apps:

```bash
# Deploy infrastructure first
kubectl apply -f argocd-apps/infrastructure-app.yaml

# Wait for it to sync
argocd app wait arr-stack-infrastructure

# Then deploy arr-stack
kubectl apply -f argocd-apps/arr-stack-app.yaml
```

But App of Apps is cleaner! Just one command.

## 🔒 Secrets Management (GitOps Style)

### Option 1: Sealed Secrets (Recommended)

```bash
# 1. Install controller (one-time setup)
cat << 'EOF' > sealed-secrets-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sealed-secrets
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://bitnami-labs.github.io/sealed-secrets
    targetRevision: 2.13.0
    chart: sealed-secrets
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

kubectl apply -f sealed-secrets-app.yaml

# 2. Install kubeseal CLI (on your machine)
# macOS: brew install kubeseal
# Linux: wget https://github.com/bitnami-labs/sealed-secrets/releases/...

# 3. Create and seal secret
kubectl create secret generic arr-secrets \
  --namespace media \
  --from-literal=sonarr-api-key=your-key \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > infrastructure/sealed-secrets.yaml

# 4. Commit sealed secret (encrypted, safe for Git!)
git add infrastructure/sealed-secrets.yaml
git commit -m "Add API keys"
git push

# ArgoCD deploys the sealed secret
# Sealed Secrets controller decrypts it in the cluster
```

### Option 2: External Secrets Operator

Add to `argocd-apps/`:

```yaml
# external-secrets-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.external-secrets.io
    targetRevision: 0.9.0
    chart: external-secrets
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 🎨 Kustomize Overlays for Multiple Environments

Current structure:

```
infrastructure/
├── storage.yaml              # Base (with placeholders)
├── kustomization.yaml        # Base kustomization
└── overlays/
    ├── production/
    │   └── kustomization.yaml   # Production node
    └── staging/
        └── kustomization.yaml   # Staging node
```

Add staging:

```yaml
# infrastructure/overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../storage.yaml

namespace: media-staging

patches:
  - target:
      kind: PersistentVolume
      name: arr-media-pv
    patch: |-
      - op: replace
        path: /metadata/name
        value: arr-media-staging-pv
      - op: replace
        path: /spec/nodeAffinity/required/nodeSelectorTerms/0/matchExpressions/0/values/0
        value: staging-node
```

## 🚨 Troubleshooting

### Apps Stuck in OutOfSync

```bash
# Check why
argocd app get arr-stack-infrastructure

# Manual sync
argocd app sync arr-stack-infrastructure

# Or enable auto-sync
argocd app set arr-stack --sync-policy automated
```

### PVs Not Binding

```bash
# Check PV status
kubectl get pv

# Check node affinity matches actual node
kubectl get nodes --show-labels

# Check ArgoCD application
kubectl describe application arr-stack-infrastructure -n argocd
```

### Need to Change Node Name

```bash
# Edit Kustomize patch
vim infrastructure/overlays/production/kustomization.yaml

# Update value
git commit -am "Update node name"
git push

# ArgoCD syncs automatically
```

## ✨ Benefits of This Approach

✅ **True GitOps**: Everything in Git
✅ **No Manual kubectl**: One command to rule them all
✅ **Declarative**: Desired state in Git
✅ **Auditable**: Git history is your audit log
✅ **Recoverable**: Disaster recovery is `git clone` + `kubectl apply root-app.yaml`
✅ **Scalable**: Add environments by adding overlays
✅ **Team-Friendly**: PRs for changes, GitOps for deployment

## 📚 Summary

### Old Way (Not GitOps)
```bash
kubectl apply -f local-storage-setup.yaml  # Manual
kubectl apply -f sealed-secret.yaml         # Manual
helm install arr-stack ./arr-stack          # Manual
```

### GitOps Way
```bash
# One time setup
kubectl apply -f argocd-apps/root-app.yaml

# All future changes
vim values.yaml
git commit -am "Update config"
git push
# ArgoCD does the rest! ✨
```

## 🎯 Quick Start Checklist

- [ ] Update node name in `infrastructure/overlays/production/kustomization.yaml`
- [ ] Update repository URLs in `argocd-apps/*.yaml`
- [ ] Update domain and storage paths in `environments/production/values.yaml`
- [ ] Add node affinity to all services in values.yaml
- [ ] Commit everything to Git
- [ ] Deploy: `kubectl apply -f argocd-apps/root-app.yaml`
- [ ] Watch it deploy: `argocd app get arr-stack-root`

That's proper GitOps! 🚀
