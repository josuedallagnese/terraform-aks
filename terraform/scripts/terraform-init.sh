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

RESOURCE_GROUP_NAME="rg-${DEPARTMENT}-shared-${LOCATION}"
KEY_VAULT_NAME="kv-${DEPARTMENT}-shared-${LOCATION}"
STORAGE_ACCOUNT_NAME="st${DEPARTMENT}shared${LOCATION}"

AKS_NAME_SECRET_NAME="aks-${DEPARTMENT}-${ENVIRONMENT}-ssh"
BUILD_SECRET_NAME="build-server-${DEPARTMENT}-${ENVIRONMENT}-ssh"
PSQL_SECRET_NAME="psql-${DEPARTMENT}-${ENVIRONMENT}"
DEV_SECRET_NAME="dev-server-${DEPARTMENT}-${ENVIRONMENT}"

echo "[INFO] Creating resource group ${RESOURCE_GROUP_NAME}..."
az group create -n "${RESOURCE_GROUP_NAME}" -l "${LOCATION}" >/dev/null || true

echo "[INFO] Creating Key Vault ${KEY_VAULT_NAME}..."
az keyvault create \
  --name "${KEY_VAULT_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --location "${LOCATION}" \
  --enable-rbac-authorization true \
  --sku standard >/dev/null || true

echo "[INFO] Creating Storage Account ${STORAGE_ACCOUNT_NAME}..."
az storage account create \
  --name "${STORAGE_ACCOUNT_NAME}" \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --location "${LOCATION}" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Cool >/dev/null || true

ACCOUNT_KEY=$(az storage account keys list \
  --resource-group "${RESOURCE_GROUP_NAME}" \
  --account-name "${STORAGE_ACCOUNT_NAME}" \
  --query "[0].value" -o tsv)

for CONTAINER in terraform-state backups-${ENVIRONMENT} tools-${ENVIRONMENT}; do
  echo "[INFO] Creating container ${CONTAINER}..."
  az storage container create \
    --name "${CONTAINER}" \
    --account-name "${STORAGE_ACCOUNT_NAME}" \
    --account-key "${ACCOUNT_KEY}" \
    --public-access off >/dev/null || true
done

if [ -d "./tools" ]; then
  echo "[INFO] Uploading local ./tools folder to container 'tools-${ENVIRONMENT}'..."
  az storage blob upload-batch \
    --destination "tools-${ENVIRONMENT}" \
    --source "./tools" \
    --account-name "${STORAGE_ACCOUNT_NAME}" \
    --account-key "${ACCOUNT_KEY}" \
    --overwrite
  echo "[INFO] Upload completed successfully."
else
  echo "[WARN] Local folder './tools' not found. Skipping upload."
fi

echo "[INFO] Checking default-${ENVIRONMENT} certificate in Key Vault..."
CERT_EXISTS=$(az keyvault certificate show \
  --vault-name "${KEY_VAULT_NAME}" \
  --name "default-${ENVIRONMENT}" \
  --query "name" -o tsv 2>/dev/null || echo "")

if [ -z "$CERT_EXISTS" ]; then
  echo "[INFO] Creating default-${ENVIRONMENT} certificate..."
  cat > /tmp/cert-policy.json <<EOF
{
  "issuerParameters": {
    "name": "Self"
  },
  "x509CertificateProperties": {
    "subject": "CN=lab.dallagnese.dev",
    "subjectAlternativeNames": {
      "dnsNames": [
        "lab.dallagnese.dev",
        "*.lab.dallagnese.dev"
      ]
    },
    "ekus": [
      "1.3.6.1.5.5.7.3.1",
      "1.3.6.1.5.5.7.3.2"
    ],
    "keyUsage": [
      "digitalSignature",
      "keyEncipherment"
    ],
    "validityInMonths": 12
  },
  "keyProperties": {
    "exportable": true,
    "keyType": "RSA",
    "keySize": 2048,
    "reuseKey": false
  },
  "lifetimeActions": [
    {
      "trigger": { "daysBeforeExpiry": 30 },
      "action": { "actionType": "AutoRenew" }
    }
  ],
  "secretProperties": { "contentType": "application/x-pkcs12" }
}
EOF

  az keyvault certificate create \
    --vault-name "${KEY_VAULT_NAME}" \
    --name "default-${ENVIRONMENT}" \
    --policy @/tmp/cert-policy.json >/dev/null
  rm -f /tmp/cert-policy.json
  echo "[INFO] Default certificate created successfully."
else
  echo "[INFO] Default certificate already exists. Skipping creation."
fi

echo "[INFO] Checking SSH keys in Key Vault..."

check_secret_exists() {
  local secret_name="$1"
  local result
  result=$(az keyvault secret show \
    --vault-name "${KEY_VAULT_NAME}" \
    --name "${secret_name}" \
    --query "name" -o tsv 2>/dev/null || echo "")
  if [ -n "$result" ]; then
    echo "[INFO] Secret '${secret_name}' already exists. Skipping creation."
    return 0
  else
    echo "[INFO] Secret '${secret_name}' does not exist. Creating..."
    return 1
  fi
}

create_ssh_key() {
  local key_name="$1"
  if ! check_secret_exists "${key_name}"; then  
    rm -f "${key_name}" "${key_name}.pub"
    echo "[INFO] Generating SSH key pair '${key_name}'..."
    ssh-keygen -q -t rsa -b 4096 -C "${key_name}" -f "${key_name}" -N "" >/dev/null
    echo "[INFO] Uploading SSH keys to Key Vault..."
    az keyvault secret set --vault-name "${KEY_VAULT_NAME}" --name "${key_name}-pub" --file "${key_name}.pub" >/dev/null
    az keyvault secret set --vault-name "${KEY_VAULT_NAME}" --name "${key_name}" --file "${key_name}" >/dev/null
    echo "[INFO] SSH key pair '${key_name}' uploaded to Key Vault."
    rm -f "${key_name}" "${key_name}.pub"
  fi
}

create_ssh_key "${AKS_NAME_SECRET_NAME}"
create_ssh_key "${BUILD_SECRET_NAME}"

if ! check_secret_exists "${PSQL_SECRET_NAME}"; then 
  echo "[INFO] Creating PostgreSQL secret..."
  PSQL_PASSWORD=$(openssl rand -base64 32)
  az keyvault secret set \
    --vault-name "${KEY_VAULT_NAME}" \
    --name "${PSQL_SECRET_NAME}" \
    --value "$PSQL_PASSWORD" >/dev/null
  echo "[INFO] PostgreSQL password secret created."
fi

if ! check_secret_exists "${DEV_SECRET_NAME}"; then 
  echo "[INFO] Creating Developer Server secret..."
  DEV_PASSWORD=$(openssl rand -base64 32)
  az keyvault secret set \
    --vault-name "${KEY_VAULT_NAME}" \
    --name "${DEV_SECRET_NAME}" \
    --value "$DEV_PASSWORD" >/dev/null
  echo "[INFO] Developer Server password secret created."
fi

echo "[INFO] Initializing Terraform backend..."
terraform init -reconfigure -upgrade \
  -lock=false \
  -backend-config="resource_group_name=${RESOURCE_GROUP_NAME}" \
  -backend-config="storage_account_name=${STORAGE_ACCOUNT_NAME}" \
  -backend-config="container_name=terraform-state" \
  -backend-config="key=${DEPARTMENT}.${ENVIRONMENT}.terraform.tfstate"

echo "[INFO] Done."