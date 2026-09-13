resource "azurerm_key_vault" "this" {
  # checkov:skip=CKV2_AZURE_32:No private endpoint. Public network access is denied and the default action is Deny, but private-link reachability is out of scope for this lab and is recorded as gap 1 in docs/threat-model.md.
  name                = "kv-${var.prefix}-${substr(sha1(azurerm_resource_group.this.id), 0, 6)}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Access policies grant vault-wide access to a principal. RBAC lets a role assignment
  # target one secret, which is what makes the least-privilege claim in this lab testable.
  # CKV_NHI_4 fails the build if a vault falls back to access policies.
  rbac_authorization_enabled = true

  public_network_access_enabled = false
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = local.governance_tags
}
