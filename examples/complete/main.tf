# Azurerm Provider configuration
provider "azurerm" {
  features {}
}

module "firewall" {
  //  source  = "kumarvna/firewall/azurerm"
  //  version = "1.0.0"
  source = "../../"

  # By default, this module will not create a resource group. Location will be same as existing RG.
  # proivde a name to use an existing resource group, specify the existing resource group name, 
  # set the argument to `create_resource_group = true` to create new resrouce group.
  resource_group_name            = "rg-shared-westeurope-01"
  location                       = "westeurope"
  virtual_network_name           = "vnet-shared-hub-westeurope-001"
  firewall_subnet_address_prefix = ["10.1.5.0/26"]

  firewall_config = {
    name              = "testfirewall1"
    zones             = [1, 2, 3]
    dns_servers       = ["8.8.8.8"]
    private_ip_ranges = ["IANAPrivateRanges"]
  }

  enable_forced_tunneling                   = true
  firewall_management_subnet_address_prefix = ["10.1.6.0/26"]

  public_ip_names = ["fw-public", "fw-private"]

  # (Optional) To enable the availability zones for firewall. 
  # Availability Zones can only be configured during deployment 
  # You can't modify an existing firewall to include Availability Zones
  #firewall_zones = [1, 2, 3]

  # (Optional) specify the application rules for Azure Firewall
  firewall_application_rules = [
    {
      name             = "microsoft"
      action           = "Allow"
      source_addresses = ["10.0.0.0/8"]
      target_fqdns     = ["*.microsoft.com"]
      protocol = {
        type = "Http"
        port = "80"
      }
    },
  ]

  # (Optional) specify the Network rules for Azure Firewall
  firewall_network_rules = [
    {
      name                  = "ntp"
      action                = "Allow"
      source_addresses      = ["10.0.0.0/8"]
      destination_ports     = ["123"]
      destination_addresses = ["*"]
      protocols             = ["UDP"]
    },
  ]

  # (Optional) specify the NAT rules for Azure Firewall
  # Destination address must be Firewall public IP
  # `fw-public` is a variable value and automatically pick the firewall public IP from module.
  firewall_nat_rules = [
    {
      name                  = "testrule"
      action                = "Dnat"
      source_addresses      = ["10.0.0.0/8"]
      destination_ports     = ["53", ]
      destination_addresses = ["fw-public"]
      translated_port       = 53
      translated_address    = "8.8.8.8"
      protocols             = ["TCP", "UDP", ]
    },
  ]

  # (Optional) To enable Azure Monitoring for Azure MySQL database
  # (Optional) Specify `storage_account_name` to save monitoring logs to storage. 
  log_analytics_workspace_name = "loganalytics-we-sharedtest2"

  # Adding TAG's to your Azure resources 
  tags = {
    ProjectName  = "demo-internal"
    Env          = "dev"
    Owner        = "user@example.com"
    BusinessUnit = "CORP"
    ServiceClass = "Gold"
  }
}
