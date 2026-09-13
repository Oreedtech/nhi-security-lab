# Three workload identities modelling the roles a real pipeline separates. They exist as
# distinct identities rather than one shared principal because shared identities make the
# blast radius of a compromise equal to the union of everything the platform does.
locals {
  workload_identities = {
    ingest = {
      description = "Writes raw events to the landing container. Write-only by design."
    }
    processor = {
      description = "Reads the landing container and writes curated output. No secret access."
    }
    reader = {
      description = "Reads curated output and the single config secret. No write path."
    }
  }
}

resource "azurerm_user_assigned_identity" "workload" {
  for_each = local.workload_identities

  name                = "id-${var.prefix}-${each.key}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  tags = merge(local.governance_tags, {
    workload  = each.key
    role-note = each.value.description
  })
}
