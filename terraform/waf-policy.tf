resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "waf-${local.sufix_gateway_name}"
  location            = azurerm_resource_group.gateway.location
  resource_group_name = azurerm_resource_group.gateway.name
  tags                = local.tags

  policy_settings {
    enabled                          = true
    mode                             = "Prevention"
    request_body_check               = true
    file_upload_limit_in_mb          = 100
    max_request_body_size_in_kb      = 128
    request_body_inspect_limit_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  custom_rules {
    name                 = "ratelimit"
    priority             = 2
    rule_type            = "RateLimitRule"
    rate_limit_threshold = var.gateway.policy.rate_limit_threshold
    rate_limit_duration  = "OneMin"
    group_rate_limit_by  = "ClientAddr"
    enabled              = true

    match_conditions {

      match_variables {
        variable_name = "RemoteAddr"
      }

      operator     = "GeoMatch"
      match_values = var.gateway.policy.rate_limit_countries
    }

    action = "Block"
  }

  custom_rules {
    name      = "outofcountries"
    priority  = 3
    rule_type = "MatchRule"
    enabled   = true

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "GeoMatch"
      negation_condition = true
      match_values       = var.gateway.policy.allow_countries
    }

    action = "Block"
  }
}
