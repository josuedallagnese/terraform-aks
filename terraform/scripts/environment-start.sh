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

if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "[ERROR] Could not detect subscription. Please run 'az login' first."
  exit 1
fi

echo "[INFO] Using subscription: $SUBSCRIPTION_ID"

RG_GATEWAY="rg-gateway-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"
RG_STORAGES="rg-storages-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"
RG_AKS="rg-aks-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"

VM_BUILD_NAME="vm-build-gateway-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"
VM_DEV_NAME="vm-dev-gateway-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"
GW_NAME="agw-gateway-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"
AKS_NAME="aks-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"
PSQL_NAME="psql-storages-${DEPARTMENT}-${LOCATION}-${ENVIRONMENT}"

echo "=========================================="
echo "   STARTING ENVIRONMENT: $DEPARTMENT-$ENVIRONMENT"
echo "=========================================="

echo "Starting PostgreSQL server: ${PSQL_NAME}"
az postgres flexible-server start --name "$PSQL_NAME" --resource-group "$RG_STORAGES" || echo "Postgres not found or already running."

echo "Starting AKS cluster: ${AKS_NAME}"
az aks start --name "$AKS_NAME" --resource-group "$RG_AKS" || echo "AKS cluster not found or already running."

echo "Starting Application Gateway: ${GW_NAME}"
az network application-gateway start --resource-group "$RG_GATEWAY" --name "$GW_NAME" || echo "Gateway not found or already running."

echo "Starting Build Server: ${VM_BUILD_NAME}"
az vm start --resource-group "$RG_GATEWAY" --name "$VM_BUILD_NAME" || echo "Build Server not found or already running."

echo "Starting Developer Server: ${VM_DEV_NAME}"
az vm start --resource-group "$RG_GATEWAY" --name "$VM_DEV_NAME" || echo "Developer Server not found or already running."

echo "Environment started successfully."