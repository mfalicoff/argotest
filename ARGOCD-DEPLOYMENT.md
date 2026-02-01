# Deploying arr-stack with ArgoCD

This guide walks you through deploying the arr-stack Helm chart using ArgoCD for GitOps-based continuous delivery.

## Table of Contents

1. [Repository Structure](#repository-structure)
2. [Prerequisites](#prerequisites)
3. [Setup Steps](#setup-steps)
4. [Deployment Methods](#deployment-methods)
5. [Managing Multiple Environments](#managing-multiple-environments)
6. [Secrets Management](#secrets-management)
7. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
8. [Best Practices](#best-practices)

## Repository Structure

```
your-repo/
├── arr-stack/                    # Helm chart
│   ├── Chart.yaml
│   ├── values.yaml              # Default values
│   ├── templates/
│   └── ...
├── argocd/                       # ArgoCD configurations
│   ├── application.yaml         # Single environment app
│   ├── applicationset.yaml      # Multi-environment apps
│   └── secrets-management.md    # Secrets guide
└── environments/                 # Environment-specific configs
    ├── production/
    │   └── values.yaml
    └── staging/
        └── values.yaml
```

## Prerequisites

### 1. ArgoCD Installation

If ArgoCD isn't installed yet:

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=600s \
  deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Access the UI:
```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Or install argocd CLI and login
argocd login localhost:8080
```

### 2. Git Repository

1. Create a Git repository (GitHub, GitLab, Gitea, etc.)
2. Add your arr-stack Helm chart
3. Add environment-specific values
4. Add ArgoCD Application manifests

```bash
# Example structure
git init
git add arr-stack/ argocd/ environments/
git commit -m "Initial arr-stack setup"
git remote add origin https://github.com/mfalicoff/argotest.git
git push -u origin main
```

### 3. Cluster Prerequisites

- Kubernetes cluster (v1.20+)
- Caddy Ingress Controller (or your preferred ingress)
- Storage solution configured
- Network access to your Git repository

## Setup Steps

### Step 1: Update Repository URLs

In all ArgoCD manifests, update the repository URL:

```yaml
# argocd/application.yaml and argocd/applicationset.yaml
source:
  repoURL: https://github.com/mfalicoff/argotest.git  # <-- Update this
  targetRevision: master
```

### Step 2: Customize Environment Values

Edit `environments/production/values.yaml`:

```yaml
ingress:
  domain: your-domain.com  # Your actual domain

storage:
  media:
    path: /your/actual/media/path
  downloads:
    path: /your/actual/downloads/path
  appdata:
    path: /your/actual/appdata/path

global:
  puid: 1000  # Your user ID
  pgid: 1000  # Your group ID
```

### Step 3: Commit and Push

```bash
git add .
git commit -m "Customize for my environment"
git push
```

### Step 4: Deploy to ArgoCD

Choose one of the deployment methods below.

## Deployment Methods

### Method 1: Single Environment Application

Best for: Simple deployments with one environment

```bash
# Apply the Application manifest
kubectl apply -f argocd/application.yaml

# Or use ArgoCD CLI
argocd app create arr-stack \
  --repo https://github.com/mfalicoff/argotest.git \
  --path arr-stack \
  --dest-namespace media \
  --dest-server https://kubernetes.default.svc \
  --helm-set-file values=environments/production/values.yaml \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

### Method 2: ApplicationSet (Multiple Environments)

Best for: Managing dev/staging/production environments

```bash
# Apply the ApplicationSet
kubectl apply -f argocd/applicationset.yaml
```

This will automatically create Applications for each environment directory.

### Method 3: ArgoCD UI

1. Log into ArgoCD UI
2. Click **+ NEW APP**
3. Fill in the form:
   - **Application Name**: `arr-stack`
   - **Project**: `default`
   - **Sync Policy**: `Automatic`
   - **Repository URL**: Your Git repo URL
   - **Path**: `arr-stack`
   - **Cluster URL**: `https://kubernetes.default.svc`
   - **Namespace**: `media`
4. Click **CREATE**

### Method 4: App of Apps Pattern

Create a parent app that manages all environments:

```yaml
# argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: arr-stack-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/mfalicoff/argotest.git
    targetRevision: master
    path: argocd
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Managing Multiple Environments

### Environment-Specific Values

Each environment can have different:
- Resource limits
- Domain names
- Storage paths
- Enabled/disabled services
- Scaling policies

Example differences:

**Production** (`environments/production/values.yaml`):
```yaml
sonarr:
  resources:
    limits:
      memory: 1Gi
  persistence:
    config:
      size: 10Gi
```

**Staging** (`environments/staging/values.yaml`):
```yaml
sonarr:
  resources:
    limits:
      memory: 512Mi
  persistence:
    config:
      size: 5Gi
```

### Promoting Between Environments

#### Option 1: Branch-based

```bash
# Staging uses 'develop' branch
# Production uses 'main' branch

# Promote staging to production
git checkout main
git merge develop
git push
```

#### Option 2: Tag-based

```yaml
# Staging uses latest commit
targetRevision: master

# Production uses tagged versions
targetRevision: v1.2.3
```

#### Option 3: Git directories

```
environments/
├── dev/
├── staging/
└── production/
```

Update staging, test, then copy to production.

## Secrets Management

See [secrets-management.md](./secrets-management.md) for detailed instructions.

Quick start with Sealed Secrets:

```bash
# Install sealed-secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create secret
kubectl create secret generic arr-secrets \
  --namespace media \
  --from-literal=api-key=your-key \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > environments/production/sealed-secret.yaml

# Commit the sealed secret
git add environments/production/sealed-secret.yaml
git commit -m "Add sealed secrets"
git push
```

## Monitoring and Troubleshooting

### Check Application Status

```bash
# ArgoCD CLI
argocd app get arr-stack
argocd app sync arr-stack
argocd app logs arr-stack

# Kubectl
kubectl get application -n argocd
kubectl describe application arr-stack -n argocd
```

### View Sync Status in UI

1. Open ArgoCD UI
2. Click on `arr-stack` application
3. View the application tree and sync status
4. Click on individual resources to see their status

### Common Issues

#### Application OutOfSync

**Cause**: Git state differs from cluster state

**Solution**:
```bash
# Manual sync
argocd app sync arr-stack

# Or enable auto-sync
argocd app set arr-stack --sync-policy automated
```

#### Sync Failed

**Cause**: Helm template errors, resource conflicts

**Solution**:
```bash
# View detailed logs
argocd app logs arr-stack

# Check for resource conflicts
kubectl get all -n media

# Dry-run to test locally
helm template arr-stack ./arr-stack \
  -f environments/production/values.yaml
```

#### Pods Not Starting

**Cause**: Storage issues, permissions, resource limits

**Solution**:
```bash
# Check pod status
kubectl get pods -n media
kubectl describe pod <pod-name> -n media
kubectl logs -n media <pod-name>

# Check PVCs
kubectl get pvc -n media
kubectl describe pvc <pvc-name> -n media
```

### Health Checks

ArgoCD monitors resource health automatically. Custom health checks:

```yaml
# In Application spec
spec:
  source:
    helm:
      values: |
        sonarr:
          healthcheck:
            enabled: true
```

### Rollback

```bash
# View application history
argocd app history arr-stack

# Rollback to previous version
argocd app rollback arr-stack <revision-number>
```

## Best Practices

### 1. Git Workflow

- **Use branches** for different environments
- **Tag releases** for production deployments
- **Protect main branch** with PR reviews
- **Use conventional commits** for clear history

### 2. Values Organization

```yaml
# Base values in arr-stack/values.yaml
# Environment overrides in environments/<env>/values.yaml
# Secrets in sealed-secrets or external secrets operator
```

### 3. ArgoCD Projects

Create a dedicated project for arr-stack:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: media
  namespace: argocd
spec:
  description: Media management applications
  sourceRepos:
    - https://github.com/mfalicoff/argotest.git
  destinations:
    - namespace: media
      server: https://kubernetes.default.svc
    - namespace: media-staging
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
```

### 4. Sync Policies

**Production**:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: false  # Manual approval for production
  syncOptions:
    - CreateNamespace=true
```

**Staging**:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true  # Auto-heal in staging
```

### 5. Resource Hooks

Use ArgoCD hooks for pre/post sync operations:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: backup-configs
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      containers:
        - name: backup
          image: backup-tool:latest
          # Backup existing configs before sync
```

### 6. Notifications

Configure ArgoCD notifications:

```bash
# Install notifications engine
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/notifications_catalog/install.yaml
```

Configure Slack/Discord/Email notifications in ConfigMap.

### 7. RBAC

Restrict who can sync production:

```yaml
# argocd-rbac-cm ConfigMap
policy.csv: |
  p, role:developers, applications, sync, */staging, allow
  p, role:admins, applications, *, */* , allow
```

## Advanced Topics

### Progressive Delivery with Argo Rollouts

For blue-green or canary deployments:

```bash
kubectl apply -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### Multi-Cluster Deployment

Register additional clusters:

```bash
argocd cluster add <context-name>
```

Update Application destination:

```yaml
destination:
  name: production-cluster  # Instead of server URL
  namespace: media
```

### Sync Windows

Restrict when production can sync:

```yaml
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    syncWindows:
      - kind: allow
        schedule: '0 22 * * *'  # Only at 10 PM
        duration: 1h
        applications:
          - arr-stack
```

## Troubleshooting Commands

```bash
# Application status
argocd app get arr-stack
argocd app diff arr-stack
argocd app manifests arr-stack

# Sync operations
argocd app sync arr-stack --dry-run
argocd app sync arr-stack --prune
argocd app sync arr-stack --force

# Logs and events
argocd app logs arr-stack --follow
kubectl get events -n media --sort-by='.lastTimestamp'

# Resource inspection
kubectl get all -n media -l app.kubernetes.io/instance=arr-stack
kubectl describe pod -n media <pod-name>
```

## Next Steps

1. Set up monitoring (Prometheus + Grafana)
2. Configure backup for PVCs
3. Set up log aggregation (Loki)
4. Implement alerts for application health
5. Create runbooks for common operations

## Support and Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- arr-stack Helm Chart README
