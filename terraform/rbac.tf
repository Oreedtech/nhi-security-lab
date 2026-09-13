# Every assignment below is scoped to a single container or a single vault, never to the
# resource group and never to the subscription. CKV_NHI_1 fails the build on a subscription-
# or management-group-scoped assignment; CKV_NHI_2 fails it on Owner, Contributor, or User
# Access Administrator. Those two checks are what stop the lab from quietly drifting back
# into the "just give it Contributor" pattern it exists to demonstrate against.

# ingest: append-only into landing. Storage Blob Data Contributor is the narrowest built-in
# role that permits create-and-write; it cannot read the curated container at this scope.
resource "azurerm_role_assignment" "ingest_landing_write" {
  scope                = "${azurerm_storage_account.this.id}/blobServices/default/containers/${azurerm_storage_container.landing.name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workload["ingest"].principal_id
  principal_type       = "ServicePrincipal"
}

# processor: read landing, write curated. Two assignments rather than one broader one --
# the split is the control, because a single account-scoped grant would collapse them.
resource "azurerm_role_assignment" "processor_landing_read" {
  scope                = "${azurerm_storage_account.this.id}/blobServices/default/containers/${azurerm_storage_container.landing.name}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.workload["processor"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "processor_curated_write" {
  scope                = "${azurerm_storage_account.this.id}/blobServices/default/containers/${azurerm_storage_container.curated.name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.workload["processor"].principal_id
  principal_type       = "ServicePrincipal"
}

# reader: curated only, plus one secret. No write path anywhere.
resource "azurerm_role_assignment" "reader_curated_read" {
  scope                = "${azurerm_storage_account.this.id}/blobServices/default/containers/${azurerm_storage_container.curated.name}"
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.workload["reader"].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "reader_vault_secrets" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload["reader"].principal_id
  principal_type       = "ServicePrincipal"
}
