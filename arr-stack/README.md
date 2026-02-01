# arr-stack Helm Chart

A Helm chart for deploying the arr media management stack (Sonarr, Radarr, Jellyseerr, Byparr, Prowlarr, Jackett) on Kubernetes with Caddy reverse proxy support.

## Prerequisites

- Kubernetes cluster (v1.20+)
- Helm 3.x
- Caddy Ingress Controller (or configure for your ingress)
- Storage solution (hostPath, NFS, or dynamic PVC provisioner)
- Tailscale integration (optional)

## Features

- ✅ All arr services with production-ready configurations
- ✅ Caddy ingress with automatic HTTPS (when using Caddy Ingress Controller)
- ✅ Persistent storage for config data
- ✅ Glance dashboard annotations for monitoring
- ✅ Health checks for Jellyseerr
- ✅ Shared memory support for Byparr
- ✅ Customizable resource limits and requests
- ✅ Support for image digests for reproducible builds

## Quick Start

### 1. Install the Chart

```bash
# Add your local chart directory
helm install arr-stack ./arr-stack \
  --namespace media \
  --create-namespace
```

### 2. Customize Values

Create a `custom-values.yaml` file:

```yaml
# Update domain
ingress:
  domain: your-domain.com

# Update storage paths to match your setup
storage:
  media:
    type: nfs  # or hostPath, pvc
    path: /your/media/path
  downloads:
    type: nfs
    path: /your/downloads/path
  appdata:
    type: nfs
    path: /your/appdata/path

# Disable services you don't need
jackett:
  enabled: false

# Adjust resource limits
sonarr:
  resources:
    limits:
      memory: 1Gi
      cpu: 1000m
    requests:
      memory: 512Mi
      cpu: 500m
```

Install with custom values:

```bash
helm install arr-stack ./arr-stack \
  -f custom-values.yaml \
  --namespace media \
  --create-namespace
```

## Configuration

### Global Settings

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.storageClass` | Default storage class for PVCs | `""` (default) |
| `global.timezone` | Timezone for all containers | `America/Toronto` |
| `global.puid` | User ID for LinuxServer containers | `1000` |
| `global.pgid` | Group ID for LinuxServer containers | `1000` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress for all services | `true` |
| `ingress.className` | Ingress class name | `caddy` |
| `ingress.domain` | Base domain for services | `local.mazilious.org` |
| `ingress.tls.enabled` | Enable TLS | `true` |

### Storage Configuration

Each service can use:
- `hostPath` - Direct host path mounting (for single-node or NFS-backed paths)
- `nfs` - NFS mounts (requires NFS provisioner)
- `pvc` - Dynamic PVC provisioning

Example with NFS:

```yaml
storage:
  media:
    type: nfs
    server: 192.168.1.100
    path: /volume1/media
  downloads:
    type: nfs
    server: 192.168.1.100
    path: /volume1/downloads
```

### Service-Specific Configuration

Each service (sonarr, radarr, etc.) has these common parameters:

| Parameter | Description |
|-----------|-------------|
| `<service>.enabled` | Enable/disable the service |
| `<service>.image.repository` | Image repository |
| `<service>.image.tag` | Image tag |
| `<service>.image.digest` | Image digest (for reproducible builds) |
| `<service>.service.type` | Kubernetes service type |
| `<service>.service.port` | Service port |
| `<service>.resources` | Resource limits and requests |
| `<service>.persistence.config.enabled` | Enable persistent config storage |
| `<service>.persistence.config.size` | PVC size for config |
| `<service>.ingress.enabled` | Enable ingress for this service |
| `<service>.ingress.hostname` | Hostname (subdomain) |

## Tailscale Integration

### Option 1: Using Caddy Ingress Controller with Tailscale

If you're using the Caddy Ingress Controller with Tailscale built-in:

```yaml
ingress:
  className: caddy
  annotations:
    caddy.ingress.kubernetes.io/tailscale: "true"
```

### Option 2: Tailscale Operator

Install the Tailscale Kubernetes Operator first:

```bash
kubectl apply -f https://pkgs.tailscale.com/stable/tailscale-operator.yaml
```

Then create a Tailscale service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: arr-stack-tailscale
  namespace: media
  annotations:
    tailscale.com/expose: "true"
    tailscale.com/hostname: "arr-stack"
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  selector:
    app.kubernetes.io/name: arr-stack
  ports:
  - port: 443
    targetPort: 443
```

## Upgrading

```bash
# Pull latest changes if using git
git pull

# Upgrade the release
helm upgrade arr-stack ./arr-stack \
  -f custom-values.yaml \
  --namespace media
```

## Uninstalling

```bash
helm uninstall arr-stack --namespace media

# Optionally delete PVCs (this will delete your config data!)
kubectl delete pvc -n media -l "app.kubernetes.io/instance=arr-stack"
```

## Accessing Services

After installation, services will be available at:

- Sonarr: `https://sonarr.local.mazilious.org`
- Radarr: `https://radarr.local.mazilious.org`
- Jellyseerr: `https://jellyseerr.local.mazilious.org`
- Byparr: `https://byparr.local.mazilious.org`
- Prowlarr: `https://prowlarr.local.mazilious.org`
- Jackett: `https://jackett.local.mazilious.org`

## Storage Notes

### HostPath Storage

When using `hostPath`:
- Ensure paths exist on the nodes where pods will run
- For multi-node clusters, consider using node affinity
- Media paths should be accessible from all nodes (e.g., via NFS mount on host)

### Persistent Volume Claims

When using PVCs, ensure your cluster has:
- A default StorageClass configured
- Or specify `storageClass` in values.yaml

## Troubleshooting

### Pods stuck in Pending

Check PVC status:
```bash
kubectl get pvc -n media
kubectl describe pvc <pvc-name> -n media
```

### Cannot access via Ingress

Check ingress status:
```bash
kubectl get ingress -n media
kubectl describe ingress <service-name> -n media
```

Verify Caddy Ingress Controller is running:
```bash
kubectl get pods -n caddy-system
```

### Permission issues with LinuxServer images

Ensure `PUID` and `PGID` match your host's user:
```bash
id your-user
```

Update in values.yaml:
```yaml
global:
  puid: 1001  # Your user ID
  pgid: 1001  # Your group ID
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

This Helm chart is provided as-is for personal use.
