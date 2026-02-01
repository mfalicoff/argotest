# Local PVC Setup Guide for arr-stack

This guide shows you how to use local persistent volumes (PVs) instead of hostPath mounts. Local PVCs provide better Kubernetes integration while still using your node's local storage.

## Why Use Local PVCs Instead of HostPath?

| Feature | HostPath | Local PVC |
|---------|----------|-----------|
| Kubernetes Native | ❌ | ✅ |
| Proper lifecycle management | ❌ | ✅ |
| Storage capacity tracking | ❌ | ✅ |
| Better scheduling | ❌ | ✅ |
| Portable across clusters | ❌ | ✅ |
| RBAC compatible | ⚠️ | ✅ |
| Backup-friendly | ⚠️ | ✅ |

## Quick Start

### Method 1: Pre-created PVs (Recommended)

This method gives you full control over storage locations.

#### Step 1: Get Your Node Name

```bash
kubectl get nodes
# Output:
# NAME          STATUS   ROLES           AGE   VERSION
# your-node     Ready    control-plane   10d   v1.28.0
```

#### Step 2: Create Storage Directories

On your node, ensure directories exist:

```bash
# SSH to your node or run locally
sudo mkdir -p /mnt/user/media/{tv,movies}
sudo mkdir -p /mnt/user/downloads
sudo chown -R 1000:1000 /mnt/user/media /mnt/user/downloads

# Verify
ls -la /mnt/user/
```

#### Step 3: Create Local Storage Resources

Save this as `local-storage-setup.yaml` and update the node name:

```yaml
# StorageClass for local persistent volumes
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain

---
# PersistentVolume for media
apiVersion: v1
kind: PersistentVolume
metadata:
  name: arr-media-pv
  labels:
    type: local
    storage: media
spec:
  storageClassName: local-path
  capacity:
    storage: 500Gi  # Adjust to your actual media storage size
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  local:
    path: /mnt/user/media
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - your-node-name  # UPDATE: Replace with your node name from Step 1

---
# PersistentVolume for downloads
apiVersion: v1
kind: PersistentVolume
metadata:
  name: arr-downloads-pv
  labels:
    type: local
    storage: downloads
spec:
  storageClassName: local-path
  capacity:
    storage: 200Gi  # Adjust to your downloads storage size
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  local:
    path: /mnt/user/downloads
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - your-node-name  # UPDATE: Same node as above

---
# PersistentVolumeClaim for media
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: arr-media-pvc
  namespace: media
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Gi
  selector:
    matchLabels:
      storage: media

---
# PersistentVolumeClaim for downloads
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: arr-downloads-pvc
  namespace: media
spec:
  storageClassName: local-path
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 200Gi
  selector:
    matchLabels:
      storage: downloads
```

#### Step 4: Apply the Configuration

```bash
# Create namespace first
kubectl create namespace media

# Apply storage setup
kubectl apply -f local-storage-setup.yaml

# Verify
kubectl get storageclass
kubectl get pv
kubectl get pvc -n media
```

Expected output:
```
NAME         STATUS   VOLUME            CAPACITY   ACCESS MODES   STORAGECLASS
arr-media-pvc      Bound    arr-media-pv      500Gi      RWX            local-path
arr-downloads-pvc  Bound    arr-downloads-pv  200Gi      RWX            local-path
```

#### Step 5: Update Helm Values

Use these values in your `values.yaml` or `environments/production/values.yaml`:

```yaml
global:
  storageClass: local-path

storage:
  media:
    type: pvc
    existingClaim: arr-media-pvc  # Use pre-created PVC
  
  downloads:
    type: pvc
    existingClaim: arr-downloads-pvc  # Use pre-created PVC
  
  appdata:
    type: pvc  # Let Helm create dynamic PVCs for each service config
    storageClass: local-path

# Add node affinity to ensure pods run on the node with storage
sonarr:
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - your-node-name  # Same as in PV definitions

radarr:
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - your-node-name

# Repeat for other services...
```

#### Step 6: Deploy with ArgoCD

```bash
# Commit your changes
git add local-storage-setup.yaml environments/production/values.yaml
git commit -m "Configure local PVCs"
git push

# ArgoCD will auto-sync if enabled, or manually sync:
argocd app sync arr-stack
```

### Method 2: Dynamic Provisioning with Local Path Provisioner

This automatically creates PVs for you.

#### Step 1: Install Local Path Provisioner

```bash
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
```

This creates:
- StorageClass: `local-path`
- Provisioner that auto-creates PVs

#### Step 2: Configure Default Path (Optional)

Edit the ConfigMap to change where volumes are created:

```bash
kubectl -n local-path-storage edit configmap local-path-config
```

Change the path:
```yaml
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["/mnt/user/local-path-provisioner"]  # Your path
        }
      ]
    }
```

#### Step 3: Update Helm Values

```yaml
global:
  storageClass: local-path

storage:
  media:
    type: pvc
    size: 500Gi  # Will be dynamically created
  
  downloads:
    type: pvc
    size: 200Gi  # Will be dynamically created
  
  appdata:
    type: pvc
    storageClass: local-path

# No need for node affinity - provisioner handles it
```

**Note**: This creates separate PV directories under the provisioner path, not your existing `/mnt/user/media` structure.

## Multi-Node Considerations

### Option 1: Node Affinity (Single Node)

If you have one node with all the media:

```yaml
# In values.yaml
sonarr:
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - storage-node  # The node with your storage
```

All arr services will run on this node.

### Option 2: Multiple Nodes with Replicated Storage

If you have NFS or replicated storage accessible from all nodes:

```yaml
# In local-storage-setup.yaml
spec:
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-role.kubernetes.io/worker
          operator: Exists  # Any worker node
```

Or use NFS type instead:

```yaml
storage:
  media:
    type: nfs
    server: your-nas.local
    path: /volume1/media
```

## Storage Layouts

### Layout 1: Separate PVs for Media and Downloads

```
/mnt/user/media/       → arr-media-pv (500Gi)
  ├── tv/
  └── movies/
/mnt/user/downloads/   → arr-downloads-pv (200Gi)
/mnt/user/appdata/     → Dynamic PVCs per service
  ├── sonarr/
  ├── radarr/
  └── ...
```

**Pros**: Clear separation, easy to manage
**Cons**: Need to create multiple PVs

### Layout 2: Single PV for Everything

```yaml
# Single large PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: arr-storage-pv
spec:
  capacity:
    storage: 1Ti
  local:
    path: /mnt/user
  # ... rest of config
```

Then use subPaths in deployments:

```yaml
volumeMounts:
  - name: storage
    mountPath: /media
    subPath: media
  - name: storage
    mountPath: /downloads
    subPath: downloads
```

**Pros**: Single PV to manage
**Cons**: No per-volume capacity tracking

### Layout 3: Per-Service PVs (Most Granular)

```
arr-sonarr-media-pv → /mnt/user/media/tv
arr-radarr-media-pv → /mnt/user/media/movies
arr-shared-downloads-pv → /mnt/user/downloads
```

**Pros**: Maximum control and isolation
**Cons**: More PVs to manage

## Verification Steps

### Check StorageClass

```bash
kubectl get storageclass local-path
# Should show: local-path with provisioner kubernetes.io/no-provisioner
```

### Check PersistentVolumes

```bash
kubectl get pv
# Should show: arr-media-pv and arr-downloads-pv in Available or Bound state
```

### Check PersistentVolumeClaims

```bash
kubectl get pvc -n media
# Should show: Bound status for media and downloads PVCs
```

### Check Pod Storage

```bash
# After deployment
kubectl get pods -n media
kubectl exec -n media arr-stack-sonarr-xxxxx -- df -h | grep -E '/tv|/downloads'
```

Should show your actual storage mounted:

```
/dev/sda1      500G  100G  400G  20% /tv
/dev/sda1      200G   50G  150G  25% /downloads
```

## Troubleshooting

### PVC Stuck in Pending

**Symptom**: `kubectl get pvc` shows Pending

**Causes**:
1. No matching PV available
2. Node affinity doesn't match
3. Wrong access mode
4. Storage size mismatch

**Fix**:
```bash
kubectl describe pvc arr-media-pvc -n media
# Look for events showing why it can't bind

# Check PV status
kubectl get pv arr-media-pv -o yaml
```

Common fixes:
- Ensure PV labels match PVC selector
- Verify node name in nodeAffinity is correct
- Check storage capacity matches

### Pod Can't Mount Volume

**Symptom**: Pod in ContainerCreating or CrashLoopBackOff

```bash
kubectl describe pod -n media arr-stack-sonarr-xxxxx
```

**Common causes**:
1. Path doesn't exist on node
2. Wrong permissions
3. Node affinity mismatch

**Fix**:
```bash
# On the node:
sudo mkdir -p /mnt/user/media/tv
sudo chown -R 1000:1000 /mnt/user/media
sudo chmod -R 755 /mnt/user/media
```

### Permission Denied Errors

**Symptom**: Logs show permission denied writing to `/tv` or `/downloads`

**Fix**:
```bash
# On the node:
sudo chown -R 1000:1000 /mnt/user/media /mnt/user/downloads
```

Make sure `PUID` and `PGID` in values.yaml match:
```yaml
global:
  puid: 1000  # Should match the user owning the directories
  pgid: 1000
```

## Migration from HostPath

If you're currently using hostPath:

### Step 1: Create PVs Pointing to Existing Paths

Your data stays in the same location, you're just managing it through PVCs now.

### Step 2: Update Values

Change from:
```yaml
storage:
  media:
    type: hostPath
    path: /mnt/user/media
```

To:
```yaml
storage:
  media:
    type: pvc
    existingClaim: arr-media-pvc
```

### Step 3: Redeploy

```bash
helm upgrade arr-stack ./arr-stack -f values.yaml -n media
```

**No data movement required** - same physical storage, just managed differently.

## Best Practices

1. **Use Retain policy**: Prevents accidental data deletion
   ```yaml
   persistentVolumeReclaimPolicy: Retain
   ```

2. **Match capacity to actual size**: Use realistic storage sizes
   ```yaml
   capacity:
     storage: 500Gi  # Match your actual disk space
   ```

3. **Use WaitForFirstConsumer**: Better pod scheduling
   ```yaml
   volumeBindingMode: WaitForFirstConsumer
   ```

4. **Label everything**: Makes management easier
   ```yaml
   metadata:
     labels:
       app: arr-stack
       storage: media
       type: local
   ```

5. **Document node affinity**: Know which node has which storage

6. **Backup your data**: Local PVs are still local storage - implement backups!

## Backup Strategies

### Using Velero

```bash
# Install Velero
velero install --provider aws --bucket my-backup-bucket

# Backup namespace
velero backup create arr-stack-backup --include-namespaces media

# Restore
velero restore create --from-backup arr-stack-backup
```

### Using rsync

```bash
# On the node
rsync -avz /mnt/user/media/ backup-server:/backups/arr-media/
```

### Using Kubernetes CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: arr-backup
  namespace: media
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: rclone/rclone:latest
            volumeMounts:
            - name: media
              mountPath: /media
            command: ["rclone", "sync", "/media", "remote:backup/media"]
          volumes:
          - name: media
            persistentVolumeClaim:
              claimName: arr-media-pvc
```

## Summary

Local PVCs provide a Kubernetes-native way to use local storage while maintaining proper lifecycle management and capacity tracking. They're especially useful when:

- You want better Kubernetes integration
- You need storage capacity tracking
- You're using backup tools like Velero
- You want portable configurations across clusters
- You need proper RBAC controls

Choose pre-created PVs (Method 1) for maximum control, or dynamic provisioning (Method 2) for convenience.
