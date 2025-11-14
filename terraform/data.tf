data "azurerm_client_config" "current" {}

data "azurerm_key_vault" "shared" {
  name                = "kv-${local.department}-shared-${var.location}"
  resource_group_name = "rg-${local.department}-shared-${var.location}"
}

data "azurerm_storage_account" "shared" {
  name                = "st${local.department}shared${var.location}"
  resource_group_name = "rg-${local.department}-shared-${var.location}"
}

data "azurerm_key_vault_secret" "aks_pub_key" {
  name         = "aks-${local.department}-aks-${var.location}-${local.env}-ssh-pub"
  key_vault_id = data.azurerm_key_vault.shared.id
}

data "azurerm_key_vault_secret" "build_pub_key" {
  name         = "vm-build-${local.department}-gateway-${var.location}-${local.env}-ssh-pub"
  key_vault_id = data.azurerm_key_vault.shared.id
}

data "azurerm_key_vault_secret" "psql_admin_password" {
  name         = "psql-${local.department}-storages-${var.location}-${local.env}"
  key_vault_id = data.azurerm_key_vault.shared.id
}

data "azurerm_key_vault_secret" "dev_admin_password" {
  name         = "vm-dev-${local.department}-gateway-${var.location}-${local.env}"
  key_vault_id = data.azurerm_key_vault.shared.id
}

data "azurerm_key_vault_certificate" "ssl_certificate" {
  name         = "default-${local.env}"
  key_vault_id = data.azurerm_key_vault.shared.id
}

data "azurerm_user_assigned_identity" "ingress" {
   name                = "ingressapplicationgateway-${azurerm_kubernetes_cluster.aks.name}"
   resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group

   depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
}

data "azurerm_storage_account_sas" "tools_sas" {
  connection_string = data.azurerm_storage_account.shared.primary_connection_string
  https_only        = true

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    file  = false
    queue = false
    table = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "1h")

   permissions {
    read    = true
    list    = true
    write   = false
    delete  = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}