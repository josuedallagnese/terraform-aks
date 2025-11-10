resource "azurerm_user_assigned_identity" "agw_id" {
  resource_group_name = azurerm_resource_group.gateway.name
  location            = azurerm_resource_group.gateway.location
  tags                = local.tags

  name = "id-${local.sufix_gateway_name}"
}

resource "azurerm_role_assignment" "agw_keyvault_secret_access" {
  scope                = data.azurerm_key_vault.shared.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.agw_id.principal_id
}

resource "azurerm_public_ip" "pip_gateway" {
  name                = "pip-agw-${local.sufix_gateway_name}"
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name
  domain_name_label   = local.sufix_gateway_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_application_gateway" "agw" {
  name                = "agw-${local.sufix_gateway_name}"
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name
  firewall_policy_id  = azurerm_web_application_firewall_policy.waf_policy.id

  tags = local.tags

  sku {
    name     = var.gateway.sku_name
    tier     = var.gateway.sku_tier
    capacity = var.gateway.sku_capacity
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agw_id.id]
  }

  ssl_certificate {
    name                = data.azurerm_key_vault_certificate.ssl_certificate.name
    key_vault_secret_id = data.azurerm_key_vault_certificate.ssl_certificate.secret_id
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.snet_gateway.id
  }

  frontend_port {
    name = "frontend-port-443"
    port = 443
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.pip_gateway.id
  }

  backend_address_pool {
    name = "default-backend-address-pool"
  }

  http_listener {
    name                           = "default-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "frontend-port-443"
    protocol                       = "Https"
    ssl_certificate_name           = data.azurerm_key_vault_certificate.ssl_certificate.name
  }

  request_routing_rule {
    name                       = "default-http-rule"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "default-listener"
    backend_address_pool_name  = "default-backend-address-pool"
    backend_http_settings_name = "default-backend-settings"
  }

  backend_http_settings {
    name                  = "default-backend-settings"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 20
  }

  lifecycle {
    ignore_changes = [
      tags["managed-by-k8s-ingress"],
      backend_address_pool,
      backend_http_settings,
      frontend_ip_configuration,
      gateway_ip_configuration,
      frontend_port,
      http_listener,
      probe,
      request_routing_rule,
      redirect_configuration,
      ssl_certificate,
      ssl_policy,
      waf_configuration,
      autoscale_configuration,
      url_path_map,
      rewrite_rule_set
    ]
  }
}

resource "azurerm_monitor_diagnostic_setting" "agw" {
  name                       = "agw-diagnostics-${local.sufix_gateway_name}"
  target_resource_id         = azurerm_application_gateway.agw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}