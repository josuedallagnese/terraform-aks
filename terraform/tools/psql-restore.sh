#!/bin/bash
set -e

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 <department> <environment> <location> <database_name> <backup_file>"
  exit 1
fi

DEPARTMENT="$1"
ENVIRONMENT="$2"
LOCATION="$3"
DATABASE="$4"
BACKUP_FILE="$5"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "[ERROR] Could not detect subscription. Please run 'az login' first."
  exit 1
fi

echo "[INFO] Using subscription: $SUBSCRIPTION_ID"

STORAGE_ACCOUNT="st${DEPARTMENT}shared${LOCATION}"
KEY_VAULT_NAME="kv-${DEPARTMENT}-shared-${LOCATION}"
CONTAINER_NAME="backups-${ENVIRONMENT}"
PSQL_SECRET_NAME="psql-${DEPARTMENT}-storages-${LOCATION}-${ENVIRONMENT}"
PGSERVER="psql-${DEPARTMENT}-storages-${LOCATION}-${ENVIRONMENT}"

echo "=============================================="
echo "   RESTORE POSTGRES DATABASE: ${DATABASE} -- $DEPARTMENT-$ENVIRONMENT"
echo "=============================================="

echo "Getting credentials from Key Vault..."
PGPASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$PSQL_SECRET_NAME" --query value -o tsv)

if [ -z "$PGPASSWORD" ]; then
  echo "Error: Database password not found in Key Vault ($PGSERVER)."
  exit 1
fi

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

echo "Downloading backup from Azure Storage..."
az storage blob download \
  --account-name "$STORAGE_ACCOUNT" \
  --container-name "$CONTAINER_NAME" \
  --name "$BACKUP_FILE" \
  --file "$BACKUP_FILE" \
  --auth-mode login \
  --overwrite

echo "Restoring database..."
pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  -d "$PGDATABASE" \
  "$BACKUP_FILE"

rm -f "$BACKUP_FILE"

echo "Restore completed successfully."
