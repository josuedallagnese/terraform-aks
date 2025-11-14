#!/bin/bash
set -e

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <department> <environment> <location>"
  echo "Example: $0 lab prd eastus2"
  exit 1
fi

DEPARTMENT="$1"
ENVIRONMENT="$2"
LOCATION="$3"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

if [ -z "$SUBSCRIPTION_ID" ] || [ -z "$TENANT_ID" ]; then
  echo "[ERROR] Could not detect subscription or tenant. Please run 'az login' first."
  exit 1
fi

echo "[INFO] Using subscription: $SUBSCRIPTION_ID"
echo "[INFO] Current tenant ID: $TENANT_ID"

terraform plan \
  -lock=false \
  -var-file=tfvars.json \
  -var "department=${DEPARTMENT}" \
  -var "environment=${ENVIRONMENT}" \
  -var "location=${LOCATION}" \
  -var "subscription_id=${SUBSCRIPTION_ID}" \
  -var "tenant_id=${TENANT_ID}"