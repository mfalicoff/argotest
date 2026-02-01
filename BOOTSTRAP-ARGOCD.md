# ArgoCD Bootstrap Guide

## The Error You're Seeing

```
error: no matches for kind "Application" in version "argoproj.io/v1alpha1"
ensure CRDs are installed first
```

This means **ArgoCD is not installed yet**. You need to install it first!

## Quick Fix (2 Steps)

### Step 1: Install ArgoCD

```bash
# Use the included script
./bootstrap-argocd.sh

# Or manually:
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for it to be ready (takes ~1-2 minutes)
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### Step 2: Deploy arr-stack

```bash
# Now this will work
kubectl apply -f argocd-apps/root-app.yaml
```

## Verify ArgoCD is Running

```bash
# Check if ArgoCD pods are running
kubectl get pods -n argocd

# You should see:
# NAME                                  READY   STATUS
# argocd-application-controller-0       1/1     Running
# argocd-server-xxxxx                   1/1     Running
# argocd-repo-server-xxxxx              1/1     Running
# argocd-redis-xxxxx                    1/1     Running
# argocd-dex-server-xxxxx               1/1     Running
```

## Get ArgoCD Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

## Access ArgoCD UI (Optional)

```bash
# Port forward in one terminal
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser: https://localhost:8080
# Username: admin
# Password: (from command above)
```

## Complete Installation Flow

```bash
# 1. Install ArgoCD (ONE TIME)
./bootstrap-argocd.sh

# 2. Configure your setup
./gitops-setup.sh

# 3. Commit to Git
git add . && git commit -m "Setup" && git push

# 4. Deploy arr-stack
kubectl apply -f argocd-apps/root-app.yaml

# 5. Watch it deploy
kubectl get applications -n argocd -w
```

## Why This Happens

ArgoCD uses **Custom Resource Definitions (CRDs)** to define `Application` resources. These CRDs are only created when you install ArgoCD. The error means those CRDs don't exist yet.

Think of it like this:
- **ArgoCD = The engine**
- **Application CRDs = The fuel**
- **Your apps = What gets delivered**

You need the engine (ArgoCD) before you can use it!

## Troubleshooting

### Check if ArgoCD is installed

```bash
kubectl get crd applications.argoproj.io
```

If you get "NotFound", ArgoCD isn't installed.

### Completely reinstall ArgoCD

```bash
# Remove old installation
kubectl delete namespace argocd

# Fresh install
./bootstrap-argocd.sh
```

### ArgoCD UI not accessible

```bash
# Make sure port-forward is running
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Try different port if 8080 is busy
kubectl port-forward svc/argocd-server -n argocd 9090:443
```

## Next Steps After ArgoCD is Installed

Once ArgoCD is running:

1. ✅ `kubectl apply -f argocd-apps/root-app.yaml`
2. ✅ Watch: `kubectl get applications -n argocd`
3. ✅ Check pods: `kubectl get pods -n media`
4. ✅ View in UI: https://localhost:8080

That's it! ArgoCD handles everything else automatically.
