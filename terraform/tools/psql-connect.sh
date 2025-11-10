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

KEY_VAULT_NAME="kv-shared-${DEPARTMENT}-${LOCATION}"
PSQL_SECRET_NAME="psql-${DEPARTMENT}-${ENVIRONMENT}"
PGSERVER="psql-storages-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"

echo "=============================================="
echo "   CONNECT TO POSTGRES DATABASE: ${DATABASE} -- $DEPARTMENT-$ENVIRONMENT"
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
PGSSLMODE="require"

export PGHOST PGUSER PGPASSWORD PGPORT PGSSLMODE

echo "Connecting to PostgreSQL..."
echo "Host: $PGHOST"
echo "Database: $DATABASE"
echo "User: $PGUSER"
echo ""

psql -d "$DATABASE"

echo ""
echo "Connection closed."