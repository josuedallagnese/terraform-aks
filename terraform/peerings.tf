# -- Peerings
resource "azurerm_virtual_network_peering" "aks_to_gateway" {
  name                      = "aks_to_gateway"
  resource_group_name       = azurerm_virtual_network.vnet_aks.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet_aks.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_gateway.id
}

resource "azurerm_virtual_network_peering" "aks_to_storages" {
  name                      = "aks_to_storages"
  resource_group_name       = azurerm_virtual_network.vnet_aks.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet_aks.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_storages.id
}

resource "azurerm_virtual_network_peering" "gateway_to_aks" {
  name                      = "gateway_to_aks"
  resource_group_name       = azurerm_virtual_network.vnet_gateway.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet_gateway.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_aks.id
}

resource "azurerm_virtual_network_peering" "gateway_to_storages" {
  name                      = "gateway_to_storages"
  resource_group_name       = azurerm_virtual_network.vnet_gateway.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet_gateway.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_storages.id
}

resource "azurerm_virtual_network_peering" "storages_to_aks" {
  name                      = "storages_to_aks"
  resource_group_name       = azurerm_virtual_network.vnet_storages.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet_storages.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_aks.id
}

resource "azurerm_virtual_network_peering" "storages_to_gateway" {
  name                      = "storages_to_gateway"
  resource_group_name       = azurerm_virtual_network.vnet_storages.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet_storages.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_gateway.id
}


# -- Links
resource "azurerm_private_dns_zone_virtual_network_link" "link_storages_to_aks" {
  name                  = "link_storages_to_aks"
  private_dns_zone_name = azurerm_private_dns_zone.storages_private_dns_zone.name
  resource_group_name   = azurerm_private_dns_zone.storages_private_dns_zone.resource_group_name
  virtual_network_id    = azurerm_virtual_network.vnet_aks.id
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_aks_to_gateway" {
  name                  = "link_aks_to_gateway"
  private_dns_zone_name = join(".", slice(split(".", azurerm_kubernetes_cluster.aks.private_fqdn), 1, length(split(".", azurerm_kubernetes_cluster.aks.private_fqdn))))
  resource_group_name   = azurerm_kubernetes_cluster.aks.node_resource_group
  virtual_network_id    = azurerm_virtual_network.vnet_gateway.id
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_storages_to_gateway" {
  name                  = "link_storages_to_gateway"
  private_dns_zone_name = azurerm_private_dns_zone.storages_private_dns_zone.name
  resource_group_name   = azurerm_private_dns_zone.storages_private_dns_zone.resource_group_name
  virtual_network_id    = azurerm_virtual_network.vnet_gateway.id
  tags                  = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_storages" {
  name                  = "link_storages"
  private_dns_zone_name = azurerm_private_dns_zone.storages_private_dns_zone.name
  resource_group_name   = azurerm_private_dns_zone.storages_private_dns_zone.resource_group_name
  virtual_network_id    = azurerm_virtual_network.vnet_storages.id
  tags                  = local.tags
}