resource "azurerm_kubernetes_cluster" "aks" {
  name                              = local.sufix_aks_name
  dns_prefix                        = local.sufix_aks_name
  location                          = azurerm_resource_group.aks.location
  resource_group_name               = azurerm_resource_group.aks.name
  node_resource_group               = "mc-${azurerm_resource_group.aks.name}"
  kubernetes_version                = var.aks.kubernetes_version
  sku_tier                          = var.aks.sku_tier
  private_cluster_enabled           = true
  role_based_access_control_enabled = true
  tags                              = local.tags

  oms_agent {
    msi_auth_for_monitoring_enabled = true
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.log.id
  }

  identity {
    type         = "SystemAssigned"
  }

  default_node_pool {
    name                          = "systempool01"
    vm_size                       = var.aks.default_node_pool.vm_size
    node_count                    = var.aks.default_node_pool.node_count
    vnet_subnet_id                = azurerm_subnet.snet_aks.id
    orchestrator_version          = var.aks.kubernetes_version
    zones                         = var.aks.default_node_pool.zones
    temporary_name_for_rotation   = "sysrotate01"
    tags                          = local.tags

    auto_scaling_enabled = var.aks.default_node_pool.auto_scaling.enabled
    min_count            = var.aks.default_node_pool.auto_scaling.min_count
    max_count            = var.aks.default_node_pool.auto_scaling.max_count
  }

  linux_profile {
    admin_username       = local.sufix_aks_name

    ssh_key {
      key_data           = data.azurerm_key_vault_secret.aks_pub_key.value
    }
  }

  network_profile {
    network_plugin = "azure"
  }

  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.agw.id
  }

   lifecycle {
    ignore_changes = [
      tags,
      linux_profile,
      default_node_pool[0].upgrade_settings,
      default_node_pool[0].node_count
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "userpool" {
  count                       = var.aks.user_node_pool.node_count > 0 ? 1 : 0
  
  name                        = "userpool01"
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.aks.id
  vm_size                     = var.aks.user_node_pool.vm_size
  node_count                  = var.aks.user_node_pool.node_count
  zones                       = var.aks.user_node_pool.zones
  orchestrator_version        = var.aks.kubernetes_version
  mode                        = "User"
  os_type                     = "Linux"
  vnet_subnet_id              = azurerm_subnet.snet_aks.id
  temporary_name_for_rotation = "userrotate01"
  tags                        = local.tags

  auto_scaling_enabled        = var.aks.user_node_pool.auto_scaling.enabled
  min_count                   = var.aks.user_node_pool.auto_scaling.min_count
  max_count                   = var.aks.user_node_pool.auto_scaling.max_count

  lifecycle {
    ignore_changes = [ 
      tags,
      node_count
     ]
  }
}

resource "azurerm_role_assignment" "aks_contributor_agw" {
  role_definition_name = "Contributor"
  scope                = azurerm_resource_group.gateway.id
  principal_id         = data.azurerm_user_assigned_identity.ingress.principal_id

  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]

  lifecycle {
    ignore_changes = [principal_id]
  }
}

resource "azurerm_role_assignment" "aks_reader_rg_gateway" {
  role_definition_name = "Reader"
  scope                = azurerm_resource_group.gateway.id
  principal_id         = data.azurerm_user_assigned_identity.ingress.principal_id

  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]

  lifecycle {
    ignore_changes = [
      principal_id,
      principal_type,
      role_definition_id
    ]
  }
}

resource "azurerm_role_assignment" "agw_network_contributor_vnet" {
  role_definition_name = "Network Contributor"
  scope                = azurerm_virtual_network.vnet_gateway.id
  principal_id         = data.azurerm_user_assigned_identity.ingress.principal_id
}

resource "azurerm_role_assignment" "aks_log_analytics_contributor" {
  role_definition_name = "Log Analytics Contributor"
  scope                = azurerm_log_analytics_workspace.log.id
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id

  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_log_analytics_workspace.log
  ]
}

resource "azapi_resource_action" "apply_workloads" {
  type        = "Microsoft.ContainerService/managedClusters@2024-02-01"
  resource_id = azurerm_kubernetes_cluster.aks.id
  action      = "runCommand"

  body = {
    command = <<EOT
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: ${local.env}
---
apiVersion: v1
kind: Pod
metadata:
  name: aspnetapp01
  namespace: ${local.env}
  labels:
    app: aspnetapp01
spec:
  containers:
  - name: aspnetapp-image
    image: mcr.microsoft.com/dotnet/samples:aspnetapp
    ports:
    - containerPort: 8080
      protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: aspnetapp01
  namespace: ${local.env}
spec:
  selector:
    app: aspnetapp01
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aspnetapp01
  namespace: ${local.env}
  annotations:
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: "default-${local.env}"
spec:
  ingressClassName: azure-application-gateway
  rules:
  - host: lab.dallagnese.dev
    http:
      paths:
      - path: /
        pathType: Exact
        backend:
          service:
            name: aspnetapp01
            port:
              number: 80
EOF
EOT
  }

  response_export_values = ["properties.logs"]
}