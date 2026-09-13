# Identity-plane activity is only auditable if it is being collected. These settings are
# what the KQL in detections/ runs against.
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "diag-${var.prefix}-kv"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "AuditEvent"
  }
}

resource "azurerm_monitor_diagnostic_setting" "blob" {
  name                       = "diag-${var.prefix}-blob"
  target_resource_id         = "${azurerm_storage_account.this.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }
}
