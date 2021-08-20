output "resource_group_name" {
  description = "The name of the resource group in which resources are created"
  value       = element(coalescelist(data.azurerm_resource_group.rgrp.*.name, azurerm_resource_group.rg.*.name, [""]), 0)
}

output "resource_group_id" {
  description = "The id of the resource group in which resources are created"
  value       = element(coalescelist(data.azurerm_resource_group.rgrp.*.id, azurerm_resource_group.rg.*.id, [""]), 0)
}

output "resource_group_location" {
  description = "The location of the resource group in which resources are created"
  value       = element(coalescelist(data.azurerm_resource_group.rgrp.*.location, azurerm_resource_group.rg.*.location, [""]), 0)
}

output "firewall_id" {
  description = "The ID of the Azure Firewall"
  value       = azurerm_firewall.fw.id
}

output "public_ip_prefix_id" {
  description = "The id of the Public IP Prefix resource"
  value       = azurerm_public_ip_prefix.fw-pref.id
}

output "firewall_public_ip" {
  description = "the public ip of firewall."
  value       = concat([for ip in azurerm_public_ip.fw-pip : ip.ip_address], [""])
}

output "firewall_private_ip" {
  description = "The private ip of firewall."
  value       = flatten(concat(azurerm_firewall.fw.ip_configuration.*.private_ip_address, [""]))
}

output "firewall_name" {
  description = "The name of the Azure Firewall."
  value       = azurerm_firewall.fw.name
}

output "virtual_hub_private_ip_address" {
  description = "The private IP address associated with the Firewall"
  value       = var.virtual_hub != null ? azurerm_firewall.fw.virtual_hub.0.private_ip_address : null
}

output "virtual_hub_public_ip_addresses" {
  description = "The private IP address associated with the Firewall"
  value       = var.virtual_hub != null ? azurerm_firewall.fw.virtual_hub.0.public_ip_addresses : null
}

