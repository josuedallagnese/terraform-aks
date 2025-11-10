#!/bin/bash
set -e

if [ "$#" -ne 5 ]; then
  echo "Usage: sh migrate-pvc-between-clusters.sh <source_rg> <source_disk_name> <dest_rg> <dest_disk_name> <subscription_id>"
  echo "Example:"
  echo "  sh migrate-pvc-between-clusters.sh mc-rg-aks-lab-eastus2-prd pvc-12345 mc-rg-aks-lab-eastus2-prd pvc-12345-copy 1c557827-b798-4783-9f76-01541cda871e"
  exit 1
fi

SOURCE_RG="$1"
SOURCE_DISK_NAME="$2"
DEST_RG="$3"
DEST_DISK_NAME="$4"
AZ_SUBSCRIPTION="$5"
SNAPSHOT_NAME="snapshot-${SOURCE_DISK_NAME}"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "[ERROR] Could not detect subscription. Please run 'az login' first."
  exit 1
fi

echo "[INFO] Using subscription: $SUBSCRIPTION_ID"

# === LOG HEADER ===
echo "==============================================="
echo " PVC MIGRATION BETWEEN AKS CLUSTERS (via Snapshot)"
echo "==============================================="
echo "Source RG:           $SOURCE_RG"
echo "Source Disk:         $SOURCE_DISK_NAME"
echo "Destination RG:      $DEST_RG"
echo "Snapshot Name:       $SNAPSHOT_NAME"
echo "Destination Disk:    $DEST_DISK_NAME"
echo "Subscription:        $AZ_SUBSCRIPTION"
echo "-----------------------------------------------"

# === 1. Create snapshot from source disk ===
echo "[1/4] Creating snapshot from source disk..."
az snapshot create \
  --name "$SNAPSHOT_NAME" \
  --resource-group "$SOURCE_RG" \
  --source "$SOURCE_DISK_NAME" \
  --query "id" -o tsv

echo "✅ Snapshot successfully created."

# === 2. Create managed disk from snapshot ===
echo "[2/4] Creating new managed disk from snapshot..."
az disk create \
  --name "$DEST_DISK_NAME" \
  --resource-group "$DEST_RG" \
  --source "$SNAPSHOT_NAME" \
  --query "id" -o tsv

echo "✅ Managed disk successfully created."

# === 3. Delete snapshot after successful disk creation ===
echo "[3/4] Deleting temporary snapshot..."
az snapshot delete \
  --name "$SNAPSHOT_NAME" \
  --resource-group "$SOURCE_RG"

echo "✅ Snapshot deleted."

# === 4. Output YAML for PV/PVC ===
DISK_URI="/subscriptions/${AZ_SUBSCRIPTION}/resourceGroups/${DEST_RG}/providers/Microsoft.Compute/disks/${DEST_DISK_NAME}"

echo "[4/4] Suggested YAML for PV/PVC:"
cat <<EOF

# ========================================
# PV and PVC to restore in destination cluster
# ========================================
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${DEST_DISK_NAME}-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  azureDisk:
    kind: Managed
    diskName: ${DEST_DISK_NAME}
    diskURI: ${DISK_URI}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${DEST_DISK_NAME}-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ""
  resources:
    requests:
      storage: 10Gi
  volumeName: ${DEST_DISK_NAME}-pv
EOF

echo "✅ PVC migration via snapshot completed successfully!"