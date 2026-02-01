# arr-stack GitOps - Quick Reference Card

## 🎯 The Only kubectl Command You Need

```bash
kubectl apply -f argocd-apps/root-app.yaml
```

That's it! Everything else is Git operations.

## ⚡ 30-Second Setup

```bash
# 1. Extract
tar -xzf arr-stack-argocd-gitops.tar.gz
cd arr-stack-helm

# 2. Auto-configure
./gitops-setup.sh

# 3. Commit & Deploy
git add . && git commit -m "Setup" && git push
kubectl apply -f argocd-apps/root-app.yaml
```

## 📝 Files You Must Edit

### Required Edits

**1. Node Name (2 files):**

`infrastructure/overlays/production/kustomization.yaml`:
```yaml
values:
  - your-actual-node-name  # Change this (run: kubectl get nodes)
```

`environments/production/values.yaml`:
```yaml
sonarr:
  nodeAffinity:
    # ... lines ...
    values:
      - your-node-name  # Change this (same as above)
```

**2. Git Repository (3 files):**

All files in `argocd-apps/*.yaml`:
```yaml
repoURL: https://github.com/YOUR_USERNAME/arr-stack-helm.git  # Change this
```

**3. Domain (1 file):**

`environments/production/values.yaml`:
```yaml
ingress:
  domain: your-domain.com  # Change this
```

### Optional Edits

- Storage paths: `infrastructure/storage.yaml`
- Resource limits: `environments/production/values.yaml`
- Timezone: `environments/production/values.yaml`

## 📂 Repository Structure

```
arr-stack-helm/
├── argocd-apps/              ⭐ Deploy this directory
│   ├── root-app.yaml        ← Apply this ONE file
│   ├── infrastructure-app.yaml
│   └── arr-stack-app.yaml
│
├── infrastructure/          ⭐ Storage config
│   ├── storage.yaml         ← PVs, PVCs, StorageClass
│   └── overlays/
│       └── production/
│           └── kustomization.yaml  ← Edit node name here
│
├── environments/            ⭐ Your settings
│   └── production/
│       └── values.yaml      ← Edit domain, node name here
│
└── arr-stack/               ⭐ Helm chart (usually no edits)
    └── templates/
```

## 🔄 Common Operations

### Make Changes

```bash
# Edit files
vim environments/production/values.yaml

# Commit and push
git commit -am "Update memory limits"
git push

# ArgoCD syncs automatically (within 3 min)
# Or manually: argocd app sync arr-stack
```

### Check Status

```bash
# Applications
kubectl get applications -n argocd

# Storage
kubectl get pv
kubectl get pvc -n media

# Pods
kubectl get pods -n media

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080
```

### View Logs

```bash
# All services
kubectl logs -n media -l app.kubernetes.io/instance=arr-stack -f

# Specific service
kubectl logs -n media -l app.kubernetes.io/component=sonarr -f
```

### Force Sync

```bash
argocd app sync arr-stack
argocd app sync arr-stack-infrastructure
```

## 🎬 Deployment Flow

```
kubectl apply root-app.yaml
         ↓
   ArgoCD creates:
         ↓
    ┌────┴────┐
    ↓         ↓
infrastructure  arr-stack
(wave 0-2)   (wave 10)
    ↓         ↓
StorageClass  Waits...
PVs          ↓
PVCs    Deploys services
    ↓         ↓
    └────┬────┘
         ↓
    All running!
```

## 🌐 What Gets Deployed

### Infrastructure App
- StorageClass: `local-path`
- PV: `arr-media-pv` (500Gi)
- PV: `arr-downloads-pv` (200Gi)  
- PVC: `arr-media-pvc`
- PVC: `arr-downloads-pvc`

### arr-stack App
- Sonarr (TV shows)
- Radarr (Movies)
- Jellyseerr (Requests)
- Prowlarr (Indexers)
- Byparr (Captcha solver)
- Services, Ingress, Config PVCs

## 🔍 Troubleshooting

### Apps Not Syncing

```bash
# Check status
argocd app get arr-stack

# Manual sync
argocd app sync arr-stack --prune

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### PVCs Not Binding

```bash
# Check PV status
kubectl get pv -o wide

# Check node affinity matches
kubectl get nodes

# Verify node name in:
# - infrastructure/overlays/production/kustomization.yaml
# - environments/production/values.yaml
```

### Pods Pending

```bash
# Describe pod
kubectl describe pod -n media <pod-name>

# Common issues:
# - PVC not bound
# - Node affinity not matching
# - Storage path doesn't exist on node
```

## 🎨 Storage Types

### Local PVC (Default) ⭐
```yaml
storage:
  media:
    type: pvc
    existingClaim: arr-media-pvc
```

### HostPath (Simple)
```yaml
storage:
  media:
    type: hostPath
    path: /mnt/user/media
```

### NFS (Multi-node)
```yaml
storage:
  media:
    type: nfs
    server: nas.local
    path: /volume1/media
```

## 🔐 Add Secrets

```bash
# Install Sealed Secrets controller via ArgoCD
cat << 'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sealed-secrets
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://bitnami-labs.github.io/sealed-secrets
    chart: sealed-secrets
    targetRevision: 2.13.0
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated: {}
EOF

# Create sealed secret
kubectl create secret generic arr-secrets \
  --namespace media \
  --from-literal=api-key=your-key \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > infrastructure/sealed-secrets.yaml

# Commit to Git
git add infrastructure/sealed-secrets.yaml
git commit -m "Add secrets"
git push
```

## 🌟 Benefits

| Old Way | GitOps Way |
|---------|------------|
| `kubectl apply` everything | ONE initial `kubectl apply` |
| Manual updates | Git commit → auto-deploy |
| No audit trail | Full Git history |
| Hard to replicate | `git clone` → deploy |
| Error-prone | Declarative & consistent |

## 📚 Documentation

| File | Purpose |
|------|---------|
| GITOPS-COMPLETE-GUIDE.md | Full walkthrough |
| PACKAGE-SUMMARY.md | Complete overview |
| LOCAL-PVC-GUIDE.md | Storage details |
| STORAGE-OPTIONS-GUIDE.md | Compare storage types |

## 🎯 Quick Checklist

Initial Setup:
- [ ] Update node name (2 files)
- [ ] Update Git URLs (3 files)
- [ ] Update domain (1 file)
- [ ] Commit to Git
- [ ] `kubectl apply -f argocd-apps/root-app.yaml`

Verify:
- [ ] `kubectl get applications -n argocd` (3 apps)
- [ ] `kubectl get pv` (2 PVs)
- [ ] `kubectl get pvc -n media` (2 PVCs bound)
- [ ] `kubectl get pods -n media` (all running)

## 💡 Pro Tips

1. **Always edit in Git** - Never use `kubectl edit`
2. **Use branches** - Test in feature branch first
3. **Tag releases** - `git tag v1.0.0`
4. **Watch syncs** - Set up ArgoCD notifications
5. **Backup Git** - It's your single source of truth

## 🚀 You're Ready!

- ONE kubectl command to deploy
- Git commits for all changes
- ArgoCD handles the rest

**Welcome to GitOps!** 🎉
