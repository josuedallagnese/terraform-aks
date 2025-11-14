variable "subscription_id" {
  type        = string
  description = "The subscription ID to deploy the resources."
}

variable "tenant_id" {
  type        = string
  description = "The tenant ID to deploy the resources."
}

variable "location" {
  type        = string
  default     = "eastus2"
  description = "The region to deploy the resources."
}

variable "environment" {
  type        = string
  description = "The environment will be created: dev, hlg, prd."
}

variable "department" {
  type        = string
  description = "The department name: lab, etc.."
}

variable "gateway" {
  description = "Gateway configurations"
  type = object({
    sku_name                          = string
    sku_tier                          = string
    sku_capacity                      = number
    vnet_address_space                = list(string)
    subnet_address_prefixes           = list(string)
    bastion_subnet_address_prefixes   = list(string)
    vms_subnet_address_prefixes       = list(string)
    build_server = object({
      size                         = string
      image_publisher              = string
      image_offer                  = string
      image_sku                    = string
      image_version                = string
      os_disk_caching              = string
      os_disk_storage_account_type = string
    })
    dev_server = object({
      enabled                      = bool
      size                         = string
      image_publisher              = string
      image_offer                  = string
      image_sku                    = string
      image_version                = string
      os_disk_caching              = string
      os_disk_storage_account_type = string
    })
    policy = object({
      rate_limit_countries = list(string)
      rate_limit_threshold = number
      allow_countries      = list(string)
    })
  })
}

variable "storages" {
  description = "Storages configurations"
  type = object({
    vnet_address_space = list(string)
    postgres = object({
      snet_address_prefixes = list(string)
      server = object({
        sku_name                     = string
        storage_mb                   = number
        backup_retention_days        = number
        geo_redundant_backup_enabled = bool
        auto_grow_enabled            = bool
        zone                         = string
        version                      = string
        ssl_enforcement_enabled      = bool
      })
    })
    storage_account = object({
      snet_address_prefixes     = list(string)
      account_tier              = string
      account_replication_type  = string
    })
  })
}

variable "aks" {
  description = "Aks configurations"
  type = object({
    kubernetes_version              = string
    sku_tier                        = string
    vnet_address_space              = list(string)
    subnet_address_prefixes         = list(string)
    default_node_pool = object({
      vm_size    = string
      node_count = number
      zones      = list(string)
      auto_scaling  = object({
        enabled    = bool
        min_count  = number
        max_count  = number
      })
    })
    user_node_pool = object({
      vm_size       = string
      node_count    = number
      zones         = list(string)
      auto_scaling  = object({
        enabled    = bool
        min_count  = number
        max_count  = number
      })
    })
  })
}