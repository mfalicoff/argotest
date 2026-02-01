# arr-stack Helm Chart - GitOps with ArgoCD

<div align="center">

[![Helm](https://img.shields.io/badge/Helm-3.0%2B-blue)](https://helm.sh)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.20%2B-blue)](https://kubernetes.io)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-orange)](https://argoproj.github.io/cd/)

A production-ready Helm chart for deploying the arr media management stack with GitOps best practices.

</div>

## 🎯 What This Is

This repository contains a Helm chart for deploying the complete arr media management stack (Sonarr, Radarr, Jellyseerr, Prowlarr, etc.) to Kubernetes using ArgoCD for GitOps-based continuous delivery.

### Services Included

- **Sonarr** - TV show management and automation
- **Radarr** - Movie management and automation
- **Jellyseerr** - Media request system
- **Prowlarr** - Indexer manager
- **Byparr** - FlareSolverr alternative for captcha solving
- **Jackett** - Indexer manager (alternative to Prowlarr)

## 🚀 Quick Start (True GitOps - No kubectl apply needed!)

### The GitOps Way ⭐ (Recommended)

Everything is managed through Git. You only run ONE `kubectl` command ever.

**Step 1: Setup**
```bash
git clone https://github.com/mfalicoff/argotest.git
cd arr-stack-helm

# Update node name in infrastructure/overlays/production/kustomization.yaml
# Update repo URLs in argocd-apps/*.yaml
# Update values in environments/production/values.yaml

git add .
git commit -m "Configure for my cluster"
git push
```

**Step 2: Deploy (ONE command)**
```bash
kubectl apply -f argocd-apps/root-app.yaml
```

That's it! ArgoCD deploys everything automatically:
1. Storage infrastructure (PVs, PVCs)
2. arr-stack services (Sonarr, Radarr, etc.)

**All future changes:** Edit → Commit → Push → ArgoCD syncs automatically!

See **[GITOPS-COMPLETE-GUIDE.md](GITOPS-COMPLETE-GUIDE.md)** for complete walkthrough.

### Alternative: Manual ArgoCD Setup

If you prefer the old way:

### 1. Fork/Clone This Repository

```bash
git clone https://github.com/mfalicoff/argotest.git
cd arr-stack-helm
```

### 2. Install ArgoCD (if not already installed)

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### 3. Customize Your Environment

Edit `environments/production/values.yaml`:

```yaml
ingress:
  domain: your-domain.com

storage:
  media:
    path: /your/media/path
  downloads:
    path: /your/downloads/path
  appdata:
    path: /your/appdata/path
```

### 4. Deploy with ArgoCD

```bash
# Update repo URL in argocd/application.yaml
# Then apply
kubectl apply -f argocd/application.yaml
```

Or via ArgoCD CLI:

```bash
argocd app create arr-stack \
  --repo https://github.com/mfalicoff/argotest.git \
  --path arr-stack \
  --dest-namespace media \
  --dest-server https://kubernetes.default.svc \
  --values-literal-file environments/production/values.yaml \
  --sync-policy automated
```

## 📁 Repository Structure

```
.
├── arr-stack/                    # Helm chart
│   ├── Chart.yaml               # Chart metadata
│   ├── values.yaml              # Default values
│   ├── templates/               # Kubernetes manifests
│   │   ├── sonarr-*.yaml
│   │   ├── radarr-*.yaml
│   │   ├── jellyseerr-*.yaml
│   │   └── ...
│   └── README.md                # Chart documentation
│
├── argocd/                       # ArgoCD configurations
│   ├── application.yaml         # Single environment app
│   ├── applicationset.yaml      # Multi-environment setup
│   └── secrets-management.md    # Secrets handling guide
│
├── environments/                 # Environment-specific values
│   ├── production/
│   │   └── values.yaml
│   └── staging/
│       └── values.yaml
│
├── ARGOCD-DEPLOYMENT.md         # Comprehensive deployment guide
└── README.md                    # This file
```

## 🎨 Features

### GitOps Best Practices

- ✅ **Declarative configuration** - Everything in Git
- ✅ **Environment separation** - Dev, staging, production
- ✅ **Automated deployments** - Auto-sync with Git changes
- ✅ **Self-healing** - ArgoCD fixes configuration drift
- ✅ **Rollback capability** - Easy revert to previous versions
- ✅ **Audit trail** - Git history shows who changed what

### Production Ready

- ✅ **Health checks** - Liveness and readiness probes
- ✅ **Resource limits** - CPU and memory constraints
- ✅ **Persistent storage** - PVCs for config data
- ✅ **Ingress support** - Caddy reverse proxy integration
- ✅ **Secrets management** - Multiple options (Sealed Secrets, External Secrets, SOPS)
- ✅ **Multi-environment** - Easy management of multiple deployments

### Kubernetes Native

- ✅ **Helm chart** - Industry-standard packaging
- ✅ **Custom labels** - Proper Kubernetes labels and annotations
- ✅ **Network policies** - Optional network isolation
- ✅ **RBAC ready** - ServiceAccount support
- ✅ **Pod security** - SecurityContext configurations

## 📖 Documentation

- **[ARGOCD-DEPLOYMENT.md](ARGOCD-DEPLOYMENT.md)** - Complete deployment guide
- **[arr-stack/README.md](arr-stack/README.md)** - Helm chart documentation
- **[argocd/secrets-management.md](argocd/secrets-management.md)** - Secrets handling

## 🔧 Configuration

### Basic Configuration

Minimum required changes in `environments/production/values.yaml`:

```yaml
# Your domain
ingress:
  domain: mazilious.org

# Your storage paths
storage:
  media:
    path: /mnt/user/media
  downloads:
    path: /mnt/user/downloads
  appdata:
    path: /mnt/user/appdata

# Your timezone and user IDs
global:
  timezone: America/Toronto
  puid: 1000  # Run 'id -u'
  pgid: 1000  # Run 'id -g'
```

### Advanced Configuration

See [arr-stack/values.yaml](arr-stack/values.yaml) for all available options:

- Resource limits and requests
- Storage class configuration
- Ingress annotations
- Service-specific settings
- Enable/disable individual services
- And much more...

## 🔒 Secrets Management

This repository supports multiple secrets management approaches:

### Recommended: Sealed Secrets

```bash
# Install controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Seal a secret
kubectl create secret generic arr-secrets \
  --namespace media \
  --from-literal=api-key=your-key \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > environments/production/sealed-secret.yaml

# Commit to Git (sealed secrets are encrypted)
git add environments/production/sealed-secret.yaml
git commit -m "Add API keys"
git push
```

See [argocd/secrets-management.md](argocd/secrets-management.md) for other options:
- External Secrets Operator (Vault, AWS Secrets Manager, etc.)
- SOPS (Mozilla Secret Operations)
- Git-crypt

## 🌍 Multiple Environments

### Option 1: Separate Applications

Create one Application per environment:

```bash
kubectl apply -f argocd/application.yaml  # Production
```

### Option 2: ApplicationSet

Automatically manage multiple environments:

```bash
kubectl apply -f argocd/applicationset.yaml
```

This creates apps for each directory in `environments/`.

### Environment Promotion

1. **Test in staging**:
   ```bash
   git checkout -b feature/new-version
   # Update environments/staging/values.yaml
   git push
   ```

2. **Promote to production**:
   ```bash
   git checkout main
   git merge feature/new-version
   git push
   ```

## 🎯 Deployment Methods

### Method 1: ArgoCD UI

1. Open ArgoCD UI
2. Click **NEW APP**
3. Fill in repository details
4. Click **CREATE**

### Method 2: ArgoCD CLI

```bash
argocd app create arr-stack \
  --repo https://github.com/mfalicoff/argotest.git \
  --path arr-stack \
  --dest-namespace media \
  --dest-server https://kubernetes.default.svc \
  --sync-policy automated
```

### Method 3: Kubectl

```bash
kubectl apply -f argocd/application.yaml
```

### Method 4: App of Apps

```bash
# Deploy parent app that manages all child apps
kubectl apply -f argocd/app-of-apps.yaml
```

## 📊 Monitoring

Check application status:

```bash
# ArgoCD CLI
argocd app get arr-stack
argocd app sync arr-stack

# Kubectl
kubectl get application -n argocd
kubectl get pods -n media
```

View in ArgoCD UI:
- Application health and sync status
- Resource tree visualization
- Event logs
- Manifest diffs

## 🔄 Common Operations

### Sync Application

```bash
argocd app sync arr-stack
```

### View Diff

```bash
argocd app diff arr-stack
```

### Rollback

```bash
argocd app history arr-stack
argocd app rollback arr-stack <revision>
```

### Update Values

```bash
# Edit values
vim environments/production/values.yaml

# Commit and push
git add environments/production/values.yaml
git commit -m "Update resource limits"
git push

# ArgoCD auto-syncs if enabled
```

## 🐛 Troubleshooting

### Application Won't Sync

```bash
# Check application status
argocd app get arr-stack

# View events
kubectl describe application arr-stack -n argocd

# Manual sync with prune
argocd app sync arr-stack --prune --force
```

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n media
kubectl describe pod <pod-name> -n media
kubectl logs -n media <pod-name>

# Check PVCs
kubectl get pvc -n media
```

### Resource Conflicts

```bash
# View what ArgoCD wants to apply
argocd app manifests arr-stack

# Compare with cluster state
argocd app diff arr-stack
```

## 🤝 Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test in staging environment
5. Submit a pull request

## 📝 License

This Helm chart is provided as-is for personal and commercial use.

## 🙏 Acknowledgments

- LinuxServer.io for the container images
- The arr team for the amazing software
- ArgoCD team for GitOps tooling
- Kubernetes and Helm communities

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Sonarr Wiki](https://wiki.servarr.com/sonarr)
- [Radarr Wiki](https://wiki.servarr.com/radarr)
- [Jellyseerr Docs](https://docs.jellyseerr.dev/)

## 💬 Support

For issues and questions:
- Check the [ARGOCD-DEPLOYMENT.md](ARGOCD-DEPLOYMENT.md) guide
- Review ArgoCD application logs
- Check individual service logs
- Consult official documentation

---

<div align="center">
Made with ❤️ for the arr community
</div>
```
