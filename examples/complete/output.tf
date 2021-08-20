output "resource_group_name" {
  description = "The name of the resource group in which resources are created"
  value       = module.firewall.resource_group_name
}

output "resource_group_id" {
  description = "The id of the resource group in which resources are created"
  value       = module.firewall.resource_group_id
}

output "resource_group_location" {
  description = "The location of the resource group in which resources are created"
  value       = module.firewall.resource_group_location
}

output "firewall_id" {
  description = "The ID of the Azure Firewall"
  value       = module.firewall.firewall_id
}

output "public_ip_prefix_id" {
  description = "The id of the Public IP Prefix resource"
  value       = module.firewall.public_ip_prefix_id
}

output "firewall_public_ip" {
  description = "the public ip of firewall."
  value       = module.firewall.firewall_public_ip
}

output "firewall_private_ip" {
  description = "The private ip of firewall."
  value       = module.firewall.firewall_private_ip
}

output "firewall_name" {
  description = "The name of the Azure Firewall."
  value       = module.firewall.firewall_name
}

output "virtual_hub_private_ip_address" {
  description = "The private IP address associated with the Firewall"
  value       = module.firewall.virtual_hub_private_ip_address
}

output "virtual_hub_public_ip_addresses" {
  description = "The private IP address associated with the Firewall"
  value       = module.firewall.virtual_hub_public_ip_addresses
}
