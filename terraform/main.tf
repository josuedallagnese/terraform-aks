locals {
  department          = lower(var.department)
  env                 = lower(var.environment)
  sufix               = "${local.department}-${var.location}-${local.env}"
  sufix_aks_name      = "aks-${local.sufix}"
  sufix_storages_name = "storages-${local.sufix}"
  sufix_gateway_name  = "gateway-${local.sufix}"
  
  resource_groups_aks_name      = "rg-${local.sufix_aks_name}"
  resource_groups_storages_name = "rg-${local.sufix_storages_name}"
  resource_groups_gateway_name  = "rg-${local.sufix_gateway_name}"
  vnets_aks_name                = "vnet-${local.sufix_aks_name}"
  vnets_storages_name           = "vnet-${local.sufix_storages_name}"
  vnets_gateway_name            = "vnet-${local.sufix_gateway_name}"
  
  tags = {
    department = local.department
    env = local.env
  }
}

terraform {
  required_version = ">= 1.13"

  required_providers {

    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.51"
    }

    random = {
      source  = "hashicorp/random"
      version = "~>3.7"
    }
  }

  backend "azurerm" { }
}

provider "azurerm" {
  features {}
}