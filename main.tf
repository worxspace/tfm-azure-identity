/**
 * # tfm-azure-identity
 *
 * Creates ADDS landing zone in azure in a standardised way using the latest recommendations.
 *
 * We use azurecaf_name to generate a unique name for the user assigned identity.
 * so make sure to provide the project-name, prefixes, suffixes as necessary
 */

module "landingzone" {
  source = "github.com/worxspace/tfm-azure-landingzone?ref=0.0.2"

  project-name       = var.project-name
  resource-prefixes  = var.resource-prefixes
  resource-suffixes  = var.resource-suffixes
  location           = var.location
  hub-vnet           = var.hub-vnet
  vnet-address-space = var.address-space
  firewall-ip        = var.firewall-ip
}

module "identity-subnet" {
  source = "github.com/worxspace/tfm-azure-subnet?ref=0.0.2"

  name                = "identity"
  tenant-short-name   = var.tenant-short-name
  resource-group-name = module.landingzone.vnet-resource-group-name
  location            = var.location
  vnet-name           = module.landingzone.vnet-name
  address-space       = var.address-space[0]
  firewall-ip         = var.firewall-ip
}

resource "azurerm_virtual_network_dns_servers" "identity-dns" {
  virtual_network_id = module.landingzone.vnet-id
  dns_servers        = module.adds-vm[*].ip-address
}

resource "azurerm_virtual_network_dns_servers" "hub-dns" {
  provider = azurerm.Connectivity

  virtual_network_id = var.hub-vnet.id
  dns_servers        = module.adds-vm[*].ip-address
}
