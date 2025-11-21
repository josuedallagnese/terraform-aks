resource "azurerm_storage_account" "main_storage" {
  name                     = "st${local.department}${local.env}"
  resource_group_name      = azurerm_resource_group.storages.name
  location                 = azurerm_resource_group.storages.location
  account_tier             = var.storages.storage_account.account_tier
  account_replication_type = var.storages.storage_account.account_replication_type

  network_rules {

    default_action             = "Deny"
    virtual_network_subnet_ids = ["${azurerm_subnet.snet_st.id}","${azurerm_subnet.snet_vms.id}","${azurerm_subnet.snet_aks.id}"]
  }
}

resource "azurerm_postgresql_flexible_server" "server" {
  name                          = "psql-${local.sufix_storages_name}"
  resource_group_name           = azurerm_resource_group.storages.name
  location                      = azurerm_resource_group.storages.location
  version                       = var.storages.postgres.server.version
  administrator_login           = "storage"
  administrator_password        = data.azurerm_key_vault_secret.psql_admin_password.value
  zone                          = var.storages.postgres.server.zone
  storage_mb                    = var.storages.postgres.server.storage_mb
  sku_name                      = var.storages.postgres.server.sku_name
  backup_retention_days         = var.storages.postgres.server.backup_retention_days
  auto_grow_enabled             = var.storages.postgres.server.auto_grow_enabled
  geo_redundant_backup_enabled  = var.storages.postgres.server.geo_redundant_backup_enabled
  public_network_access_enabled = false
  
  delegated_subnet_id           = azurerm_subnet.snet_psql.id
  private_dns_zone_id           = azurerm_private_dns_zone.storages_private_dns_zone.id

  tags                          = local.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.link_storages]
}

# Configurações de diagnóstico para Query Store
resource "azurerm_postgresql_flexible_server_configuration" "pg_qs_query_capture_mode" {
  name      = "pg_qs.query_capture_mode"
  server_id = azurerm_postgresql_flexible_server.server.id
  value     = "ALL"
}

# Configurações de diagnóstico para Wait Sampling
resource "azurerm_postgresql_flexible_server_configuration" "pgms_wait_sampling_query_capture_mode" {
  name      = "pgms_wait_sampling.query_capture_mode"
  server_id = azurerm_postgresql_flexible_server.server.id
  value     = "ALL"
}

# Configuração para rastreamento de I/O timing
resource "azurerm_postgresql_flexible_server_configuration" "track_io_timing" {
  name      = "track_io_timing"
  server_id = azurerm_postgresql_flexible_server.server.id
  value     = "ON"
}

# Configuração para extensões Azure
resource "azurerm_postgresql_flexible_server_configuration" "azure_extensions" {
  count     = coalesce(var.storages.postgres.server.azure_extensions, "") != "" ? 1 : 0
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.server.id
  value     = var.storages.postgres.server.azure_extensions
}