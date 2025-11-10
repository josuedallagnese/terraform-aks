#!/bin/bash
set -e

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 <department> <environment> <location> <database_name>"
  exit 1
fi

DEPARTMENT="$1"
ENVIRONMENT="$2"
LOCATION="$3"
DATABASE="$4"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "[ERROR] Could not detect subscription. Please run 'az login' first."
  exit 1
fi

echo "[INFO] Using subscription: $SUBSCRIPTION_ID"

STORAGE_ACCOUNT="stshared${DEPARTMENT}${LOCATION}"
KEY_VAULT_NAME="kv-shared-${DEPARTMENT}-${LOCATION}"
CONTAINER_NAME="backups-${ENVIRONMENT}"
PSQL_SECRET_NAME="psql-${DEPARTMENT}-${ENVIRONMENT}"
PGSERVER="psql-storages-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"

echo "=============================================="
echo "   BACKUP POSTGRES DATABASE: ${DATABASE} -- $DEPARTMENT-$ENVIRONMENT"
echo "=============================================="

echo "Getting credentials from Key Vault..."
PGPASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$PSQL_SECRET_NAME" --query value -o tsv)

if [ -z "$PGPASSWORD" ]; then
  echo "Error: Database password not found in Key Vault ($PGSERVER)."
  exit 1
fi

BACKUP_FILE="${DATABASE}-$(date +%Y%m%d-%H%M%S).dump"
PGUSER="storage"
PGHOST="${PGSERVER}.postgres.database.azure.com"
PGPORT="5432"
PGDATABASE="$DATABASE"
export PGPASSWORD
export PGUSER
export PGHOST
export PGPORT
export PGDATABASE
export PGSSLMODE="require"

echo "Creating local backup..."
pg_dump -Fc -f "$BACKUP_FILE"

echo "Uploading backup to Azure Storage..."
az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER_NAME" \
  --file "$BACKUP_FILE" \
  --name "$BACKUP_FILE" \
  --auth-mode login \
  --overwrite

rm -f "$BACKUP_FILE"

echo "Backup completed and uploaded to container '$CONTAINER_NAME'."
