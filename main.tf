#---------------------------------
# Local declarations
#---------------------------------
locals {
  resource_group_name = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
  location            = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)
  public_ip_map       = { for pip in var.public_ip_names : pip => true }

  fw_nat_rules = { for idx, rule in var.firewall_nat_rules : rule.name => {
    idx : idx,
    rule : rule,
    }
  }

  fw_network_rules = { for idx, rule in var.firewall_network_rules : rule.name => {
    idx : idx,
    rule : rule,
    }
  }

  fw_application_rules = { for idx, rule in var.firewall_application_rules : rule.name => {
    idx : idx,
    rule : rule,
    }
  }
}

#---------------------------------------------------------
# Resource Group Creation or selection - Default is "true"
#----------------------------------------------------------
data "azurerm_resource_group" "rgrp" {
  count = var.create_resource_group == false ? 1 : 0
  name  = var.resource_group_name
}

resource "azurerm_resource_group" "rg" {
  count    = var.create_resource_group ? 1 : 0
  name     = lower(var.resource_group_name)
  location = var.location
  tags     = merge({ "ResourceName" = format("%s", var.resource_group_name) }, var.tags, )
}

data "azurerm_log_analytics_workspace" "logws" {
  count               = var.log_analytics_workspace_name != null ? 1 : 0
  name                = var.log_analytics_workspace_name
  resource_group_name = local.resource_group_name
}

data "azurerm_storage_account" "storeacc" {
  count               = var.storage_account_name != null ? 1 : 0
  name                = var.storage_account_name
  resource_group_name = local.resource_group_name
}

#---------------------------------------------------------
# Firewall Subnet Creation or selection
#----------------------------------------------------------
resource "azurerm_subnet" "fw-snet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = var.firewall_subnet_address_prefix #[cidrsubnet(element(var.vnet_address_space, 0), 10, 0)]
  service_endpoints    = var.firewall_service_endpoints
}

#---------------------------------------------------------
# Firewall Managemnet Subnet Creation
#----------------------------------------------------------
resource "azurerm_subnet" "fw-mgnt-snet" {
  count                = var.enable_forced_tunneling ? 1 : 0
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = var.firewall_management_subnet_address_prefix #[cidrsubnet(element(var.vnet_address_space, 0), 10, 0)]
}

#------------------------------------------
# Public IP resources for Azure Firewall
#------------------------------------------
resource "azurerm_public_ip_prefix" "fw-pref" {
  name                = lower("${var.firewall_config.name}-pip-prefix")
  resource_group_name = local.resource_group_name
  location            = local.location
  prefix_length       = var.public_ip_prefix_length
  tags                = merge({ "ResourceName" = lower("${var.firewall_config.name}-pip-prefix") }, var.tags, )
}

resource "azurerm_public_ip" "fw-pip" {
  for_each            = local.public_ip_map
  name                = lower("pip-${var.firewall_config.name}-${each.key}")
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  public_ip_prefix_id = azurerm_public_ip_prefix.fw-pref.id
  tags                = merge({ "ResourceName" = lower("pip-${var.firewall_config.name}-${each.key}") }, var.tags, )
}

resource "azurerm_public_ip" "fw-mgnt-pip" {
  count               = var.enable_forced_tunneling ? 1 : 0
  name                = lower("pip-${var.firewall_config.name}-fw-mgnt")
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = merge({ "ResourceName" = lower("pip-${var.firewall_config.name}-fw-mgnt") }, var.tags, )
}

#-----------------
# Azure Firewall 
#-----------------
resource "azurerm_firewall" "fw" {
  name                = format("%s", var.firewall_config.name)
  resource_group_name = local.resource_group_name
  location            = local.location
  sku_name            = var.firewall_config.sku_name
  sku_tier            = var.firewall_config.sku_tier
  # firewall_policy_id = # firewall_policy resoruce to be added
  dns_servers       = var.firewall_config.dns_servers
  private_ip_ranges = var.firewall_config.private_ip_ranges
  threat_intel_mode = lookup(var.firewall_config, "threat_intel_mode", "Alert")
  zones             = var.firewall_config.zones
  tags              = merge({ "ResourceName" = format("%s", var.firewall_config.name) }, var.tags, )

  dynamic "ip_configuration" {
    for_each = local.public_ip_map
    iterator = ip
    content {
      name                 = ip.key
      subnet_id            = ip.key == var.public_ip_names[0] ? azurerm_subnet.fw-snet.id : null
      public_ip_address_id = azurerm_public_ip.fw-pip[ip.key].id
    }
  }

  dynamic "management_ip_configuration" {
    for_each = var.enable_forced_tunneling ? [1] : []
    content {
      name                 = lower("${var.firewall_config.name}-forced-tunnel")
      subnet_id            = azurerm_subnet.fw-mgnt-snet.0.id
      public_ip_address_id = azurerm_public_ip.fw-mgnt-pip.0.id
    }
  }

  dynamic "virtual_hub" {
    for_each = var.virtual_hub != null ? [var.virtual_hub] : []
    content {
      virtual_hub_id  = virtual_hub.value.virtual_hub_id
      public_ip_count = virtual_hub.value.public_ip_count
    }
  }
}

#----------------------------------------------
# Azure Firewall Network/Application/NAT Rules 
#----------------------------------------------
resource "azurerm_firewall_application_rule_collection" "fw_app" {
  for_each            = local.fw_application_rules
  name                = lower(format("fw-app-rule-%s-${var.firewall_config.name}-${local.location}", each.key))
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = local.resource_group_name
  priority            = 100 * (each.value.idx + 1)
  action              = each.value.rule.action

  rule {
    name             = each.key
    description      = each.value.rule.description
    source_addresses = each.value.rule.source_addresses
    source_ip_groups = each.value.rule.source_ip_groups
    fqdn_tags        = each.value.rule.fqdn_tags
    target_fqdns     = each.value.rule.target_fqdns

    protocol {
      type = each.value.rule.protocol.type
      port = each.value.rule.protocol.port
    }
  }
}

resource "azurerm_firewall_network_rule_collection" "fw" {
  for_each            = local.fw_network_rules
  name                = lower(format("fw-net-rule-%s-${var.firewall_config.name}-${local.location}", each.key))
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = local.resource_group_name
  priority            = 100 * (each.value.idx + 1)
  action              = each.value.rule.action

  rule {
    name                  = each.key
    description           = each.value.rule.description
    source_addresses      = each.value.rule.source_addresses
    destination_ports     = each.value.rule.destination_ports
    destination_addresses = [for dest in each.value.rule.destination_addresses : contains(var.public_ip_names, dest) ? azurerm_public_ip.fw-pip[dest].ip_address : dest]
    destination_fqdns     = each.value.rule.destination_fqdns
    protocols             = each.value.rule.protocols
  }
}

resource "azurerm_firewall_nat_rule_collection" "fw" {
  for_each            = local.fw_nat_rules
  name                = lower(format("fw-nat-rule-%s-${var.firewall_config.name}-${local.location}", each.key))
  azure_firewall_name = azurerm_firewall.fw.name
  resource_group_name = local.resource_group_name
  priority            = 100 * (each.value.idx + 1)
  action              = each.value.rule.action

  rule {
    name                  = each.key
    description           = each.value.rule.description
    source_addresses      = each.value.rule.source_addresses
    destination_ports     = each.value.rule.destination_ports
    destination_addresses = [for dest in each.value.rule.destination_addresses : contains(var.public_ip_names, dest) ? azurerm_public_ip.fw-pip[dest].ip_address : dest]
    protocols             = each.value.rule.protocols
    translated_address    = each.value.rule.translated_address
    translated_port       = each.value.rule.translated_port
  }
}

#---------------------------------------------------------------
# azurerm monitoring diagnostics - Firewall and Public IP's
#---------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "fw-mgnt-pip-diag" {
  count                      = var.log_analytics_workspace_name != null || var.storage_account_name != null && var.enable_forced_tunneling ? 1 : 0
  name                       = lower("fw-${var.firewall_config.name}-mgnt-pip-diag")
  target_resource_id         = azurerm_public_ip.fw-mgnt-pip.0.id
  storage_account_id         = var.storage_account_name != null ? data.azurerm_storage_account.storeacc.0.id : null
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.logws.0.id

  dynamic "log" {
    for_each = var.fw_pip_diag_logs
    content {
      category = log.value
      enabled  = true

      retention_policy {
        enabled = false
        days    = 0
      }
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
      days    = 0
    }
  }

  lifecycle {
    ignore_changes = [log, metric]
  }
}

resource "azurerm_monitor_diagnostic_setting" "fw-pip-diag" {
  for_each                   = local.public_ip_map
  name                       = lower("fw-${var.firewall_config.name}-${each.key}-pip-diag")
  target_resource_id         = azurerm_public_ip.fw-pip[each.key].id
  storage_account_id         = var.storage_account_name != null ? data.azurerm_storage_account.storeacc.0.id : null
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.logws.0.id

  dynamic "log" {
    for_each = var.fw_pip_diag_logs
    content {
      category = log.value
      enabled  = true

      retention_policy {
        enabled = false
        days    = 0
      }
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
      days    = 0
    }
  }

  lifecycle {
    ignore_changes = [log, metric]
  }
}

resource "azurerm_monitor_diagnostic_setting" "fw-diag" {
  for_each                   = local.public_ip_map
  name                       = lower("${var.firewall_config.name}-diag")
  target_resource_id         = azurerm_firewall.fw.id
  storage_account_id         = var.storage_account_name != null ? data.azurerm_storage_account.storeacc.0.id : null
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.logws.0.id

  dynamic "log" {
    for_each = var.fw_diag_logs
    content {
      category = log.value
      enabled  = true

      retention_policy {
        enabled = false
        days    = 0
      }
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
      days    = 0
    }
  }

  lifecycle {
    ignore_changes = [log, metric]
  }
}
