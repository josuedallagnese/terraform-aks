resource "azurerm_log_analytics_workspace" "log" {
  name                = "log-${local.sufix_aks_name}"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

resource "azurerm_log_analytics_solution" "solution" {
  location              = azurerm_resource_group.aks.location
  resource_group_name   = azurerm_resource_group.aks.name
  solution_name         = "ContainerInsights"
  workspace_name        = azurerm_log_analytics_workspace.log.name
  workspace_resource_id = azurerm_log_analytics_workspace.log.id
  tags                  = local.tags

  plan {
    product   = "OMSGallery/ContainerInsights"
    publisher = "Microsoft"
  }
}

resource "azurerm_monitor_data_collection_rule" "aks" {
  name                = "msci-${azurerm_kubernetes_cluster.aks.name}"
  resource_group_name = azurerm_resource_group.aks.name
  location            = var.location
  tags                = local.tags

  destinations {
    log_analytics {
      name                  = "ciworkspace"
      workspace_resource_id = azurerm_log_analytics_workspace.log.id
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory", "Microsoft-KubeNodeInventory", "Microsoft-KubePVInventory", "Microsoft-KubeServices", "Microsoft-KubeMonAgentEvents", "Microsoft-InsightsMetrics", "Microsoft-ContainerInventory", "Microsoft-ContainerNodeInventory", "Microsoft-Perf"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      streams        = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory", "Microsoft-KubeNodeInventory", "Microsoft-KubePVInventory", "Microsoft-KubeServices", "Microsoft-KubeMonAgentEvents", "Microsoft-InsightsMetrics", "Microsoft-ContainerInventory", "Microsoft-ContainerNodeInventory", "Microsoft-Perf"]
      extension_name = "ContainerInsights"
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Exclude"
          namespaces = [
            "kube-system",
            "gatekeeper-system",
            "azure-arc"
          ],
          enableContainerLogV2 = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "aks" {
  name                    = azurerm_kubernetes_cluster.aks.name
  target_resource_id      = azurerm_kubernetes_cluster.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks.id
}