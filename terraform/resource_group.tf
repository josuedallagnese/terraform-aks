resource "azurerm_resource_group" "aks" {
  name     = local.resource_groups_aks_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "gateway" {
  name     = local.resource_groups_gateway_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "storages" {
  name     = local.resource_groups_storages_name
  location = var.location
  tags     = local.tags
}
