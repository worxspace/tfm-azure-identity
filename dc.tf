resource "azurecaf_name" "adds-resource-group-name" {
  resource_type = "azurerm_resource_group"
  name          = "adds"
  prefixes      = [var.tenant-short-name]
}

resource "azurerm_resource_group" "adds-resource-group" {
  name     = azurecaf_name.adds-resource-group-name.result
  location = var.location
}

resource "azurecaf_name" "vm-ade-key-adds" {
  count = var.domain-controller == null ? 0 : var.domain-controller.high-availability == true ? 2 : 1

  name          = "adds"
  resource_type = "azurerm_key_vault_key"
  suffixes      = ["vm-${count.index}"]
  prefixes      = [var.tenant-short-name]
}

resource "azurerm_key_vault_key" "vm-ade-key-adds" {
  count = var.domain-controller == null ? 0 : var.domain-controller.high-availability == true ? 2 : 1

  name         = azurecaf_name.vm-ade-key-adds[count.index].result
  key_vault_id = azurerm_key_vault.identity-key-vault.id
  key_type     = "RSA"
  key_size     = 3072

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  depends_on = [
    azurerm_role_assignment.identity-key-vault-current-officer
  ]
}

module "adds-vm" {
  source = "github.com/worxspace/tfm-azure-vm-windows?ref=v0.3"
  depends_on = [
    azurerm_role_assignment.identity-key-vault-current-officer
  ]
  count = var.domain-controller == null ? 0 : var.domain-controller.high-availability == true ? 2 : 1

  resource-group-name = azurerm_resource_group.adds-resource-group.name
  location            = var.location
  project-name        = "adds"
  resource-prefixes   = [var.tenant-short-name]
  resource-suffixes   = [count.index]
  subnet-id           = module.identity-subnet.subnet-id
  ip-address          = cidrhost(module.identity-subnet.address-prefixes[0], (count.index + 4)) # Note: the first 3 IPs are reserved by Azure. So starting at 4.

  vm-size              = var.domain-controller.vm-size
  support-hvic         = true
  enable-azuread-login = false

  data-disks = [{
    name         = "addata"
    size-gb      = 10
    storage-type = "Premium_LRS"
    tier         = "P3"
  }]

  disk-encryption = {
    key-vault-url            = azurerm_key_vault.identity-key-vault.vault_uri
    key-vault-encryption-url = azurerm_key_vault_key.vm-ade-key-adds[count.index].id
    key-vault-resource-id    = azurerm_key_vault.identity-key-vault.id
  }
}