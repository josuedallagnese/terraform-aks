# -- Cluster
resource "azurerm_virtual_network" "vnet_aks" {
  name                = local.vnets_aks_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = var.aks.vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "snet_aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_virtual_network.vnet_aks.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_aks.name
  address_prefixes     = var.aks.subnet_address_prefixes
  service_endpoints    = ["Microsoft.Storage"]

  private_endpoint_network_policies = "Enabled"
}

# -- Storages
resource "azurerm_virtual_network" "vnet_storages" {
  name                = local.vnets_storages_name
  location            = azurerm_resource_group.storages.location
  resource_group_name = azurerm_resource_group.storages.name
  address_space       = var.storages.vnet_address_space
  tags                = local.tags
}

resource "azurerm_network_security_group" "nsg_storages" {
  name                = "nsg-${local.sufix_storages_name}"
  location            = azurerm_virtual_network.vnet_storages.location
  resource_group_name = azurerm_virtual_network.vnet_storages.resource_group_name
  tags                = local.tags

  security_rule {
    name                       = "psql"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "5432"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet" "snet_psql" {
  name                 = "snet-psql"
  virtual_network_name = azurerm_virtual_network.vnet_storages.name
  resource_group_name  = azurerm_virtual_network.vnet_storages.resource_group_name
  address_prefixes     = var.storages.postgres.snet_address_prefixes
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "subnet_association" {
  subnet_id                 = azurerm_subnet.snet_psql.id
  network_security_group_id = azurerm_network_security_group.nsg_storages.id
}

resource "azurerm_subnet" "snet_st" {
  name                 = "snet-st"
  resource_group_name  = azurerm_virtual_network.vnet_storages.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet_storages.name
  address_prefixes     = var.storages.storage_account.snet_address_prefixes
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_private_dns_zone" "storages_private_dns_zone" {
  name                = "${local.sufix_storages_name}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.storages.name
  tags                = local.tags

  depends_on = [azurerm_subnet_network_security_group_association.subnet_association]
}

# -- Gateway
resource "azurerm_virtual_network" "vnet_gateway" {
  name                = local.vnets_gateway_name
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name
  address_space       = var.gateway.vnet_address_space
  tags                = local.tags
}

resource "azurerm_subnet" "snet_gateway" {
  name                 = "snet-gateway"
  resource_group_name  = azurerm_resource_group.gateway.name
  virtual_network_name = azurerm_virtual_network.vnet_gateway.name
  address_prefixes     = var.gateway.subnet_address_prefixes

  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = false
}

resource "azurerm_subnet" "snet_vms" {
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.gateway.name
  virtual_network_name = azurerm_virtual_network.vnet_gateway.name
  address_prefixes     = var.gateway.vms_subnet_address_prefixes
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_network_security_group" "nsg_gateway" {
  name                = "nsg-${local.sufix_gateway_name}"
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name
  tags                = local.tags
}