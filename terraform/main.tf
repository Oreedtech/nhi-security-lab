data "azurerm_client_config" "current" {}

locals {
  # Governance tags carried by every workload identity. The lab treats these as part of the
  # control, not as metadata: an identity that cannot say who owns it and when it expires
  # cannot be recertified, and unrecertified identities are how standing access accumulates.
  governance_tags = merge(var.tags, {
    managed-by = "terraform"
    owner      = var.identity_owner
    review-by  = var.review_by
    purpose    = "non-human-identity-governance-lab"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.prefix}"
  location = var.location
  tags     = local.governance_tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.prefix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.governance_tags
}
