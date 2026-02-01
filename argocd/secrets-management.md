# Secrets Management for arr-stack with ArgoCD

This directory contains examples for managing secrets in ArgoCD.

## Option 1: Sealed Secrets (Recommended for GitOps)

Install Sealed Secrets controller:
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

Create and seal a secret:
```bash
# Create a regular secret (DON'T commit this!)
kubectl create secret generic arr-secrets \
  --namespace media \
  --from-literal=sonarr-api-key=your-api-key \
  --from-literal=radarr-api-key=your-api-key \
  --dry-run=client -o yaml > /tmp/secret.yaml

# Seal it (this CAN be committed to Git)
kubeseal -f /tmp/secret.yaml -w sealed-secret.yaml

# Commit sealed-secret.yaml to your repo
```

Example sealed secret structure (sealed-secret.yaml):
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: arr-secrets
  namespace: media
spec:
  encryptedData:
    sonarr-api-key: AgA... # encrypted value
    radarr-api-key: AgB... # encrypted value
  template:
    metadata:
      name: arr-secrets
      namespace: media
    type: Opaque
```

## Option 2: External Secrets Operator

Install External Secrets Operator:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace
```

Example with AWS Secrets Manager:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: media
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: arr-secrets
  namespace: media
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: arr-secrets
    creationPolicy: Owner
  data:
    - secretKey: sonarr-api-key
      remoteRef:
        key: arr-stack/sonarr
        property: api-key
    - secretKey: radarr-api-key
      remoteRef:
        key: arr-stack/radarr
        property: api-key
```

Example with HashiCorp Vault:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: media
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "arr-stack"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: arr-secrets
  namespace: media
spec:
  refreshInterval: 15m
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: arr-secrets
  data:
    - secretKey: sonarr-api-key
      remoteRef:
        key: arr-stack/sonarr
        property: api-key
```

## Option 3: SOPS (Mozilla's Secret Operations)

Install SOPS and age:
```bash
# Install SOPS
brew install sops  # macOS
# or download from https://github.com/mozilla/sops/releases

# Install age for encryption
brew install age
```

Generate age key:
```bash
age-keygen -o key.txt
# Save the public key for encryption
# Keep key.txt SECURE and NEVER commit it!
```

Create encrypted values file:
```bash
# Create unencrypted file first
cat > secrets.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: arr-secrets
  namespace: media
type: Opaque
stringData:
  sonarr-api-key: your-key-here
  radarr-api-key: your-key-here
EOF

# Encrypt with SOPS
export SOPS_AGE_RECIPIENTS=age1... # your age public key
sops -e -i secrets.yaml

# Now secrets.yaml is encrypted and can be committed
```

Configure ArgoCD to decrypt SOPS:
```yaml
# Install Argo CD with SOPS support
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  kustomize.buildOptions: "--enable-alpha-plugins --enable-exec"
```

Add age key to ArgoCD:
```bash
kubectl create secret generic helm-secrets-private-keys \
  --namespace argocd \
  --from-file=key.txt=./key.txt
```

## Option 4: Git-crypt (Simple but less flexible)

Initialize git-crypt in your repo:
```bash
cd your-repo
git-crypt init
git-crypt add-gpg-user your-gpg-key-id
```

Create .gitattributes:
```
environments/*/secrets.yaml filter=git-crypt diff=git-crypt
*.secret.yaml filter=git-crypt diff=git-crypt
```

Now any file matching the pattern will be encrypted automatically.

## Option 5: Manual Secret Management (Not Recommended)

If you must store secrets outside Git:

1. Create secrets manually in the cluster:
```bash
kubectl create secret generic arr-secrets \
  --namespace media \
  --from-literal=sonarr-api-key=your-key
```

2. Reference them in your Helm values:
```yaml
# values.yaml
sonarr:
  existingSecret: arr-secrets
  apiKeySecretKey: sonarr-api-key
```

3. Update deployment templates to use the secret:
```yaml
env:
  - name: SONARR__API_KEY
    valueFrom:
      secretKeyRef:
        name: {{ .Values.sonarr.existingSecret }}
        key: {{ .Values.sonarr.apiKeySecretKey }}
```

## Best Practices

1. **Never commit unencrypted secrets to Git**
2. **Use namespace isolation** - keep secrets in the same namespace as the app
3. **Rotate secrets regularly**
4. **Use RBAC** to restrict secret access
5. **Audit secret access** with tools like Falco
6. **Consider using a secrets manager** (Vault, AWS Secrets Manager, etc.)

## Recommended Approach

For most use cases, we recommend:
- **Sealed Secrets** for simple, Kubernetes-native secret management
- **External Secrets Operator** if you already use a secrets manager
- **SOPS** if you prefer file-based encryption with Git

Choose based on your existing infrastructure and security requirements.
