resource "azurerm_storage_account" "this" {
  # checkov:skip=CKV_AZURE_43:False positive. The name is built from substr(sha1(...)), which the parser cannot evaluate, so it cannot confirm the pattern. The rendered name is "st" + prefix (<=10 lowercase alnum) + 8 hex characters, which satisfies the 3-24 lowercase-alphanumeric rule by construction.
  # checkov:skip=CKV_AZURE_206:LRS is intentional. This is a single-region lab holding no data worth replicating across regions; GRS would double storage cost for a subscription that exists to demonstrate identity scoping. Production deployments should raise this.
  # checkov:skip=CKV_AZURE_33:No queues exist on this account. Queue logging would monitor a surface this lab never creates.
  # checkov:skip=CKV2_AZURE_1:Platform-managed keys. Customer-managed keys are recorded as gap 2 in docs/threat-model.md rather than silently omitted.
  # checkov:skip=CKV2_AZURE_33:No private endpoint. Public network access is denied, but private-link reachability is deliberately out of scope for an identity lab and is recorded as gap 1 in docs/threat-model.md. See sentinel-secure-ingestion for the private-link version of this pattern.
  name                = "st${var.prefix}${substr(sha1(azurerm_resource_group.this.id), 0, 8)}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # The whole point of the lab is identity-based access. Leaving account keys enabled would
  # mean every scoped role assignment below is decorative: anyone with the key bypasses all
  # of them. CKV_NHI_5 fails the build if this is ever flipped.
  shared_access_key_enabled       = false
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = local.governance_tags
}

resource "azurerm_storage_container" "landing" {
  # checkov:skip=CKV2_AZURE_21:Deliberately stricter than the check. It is satisfied only by azurerm_log_analytics_storage_insights, whose storage_account_key argument is required by the provider -- but this account sets shared_access_key_enabled = false, which CKV_NHI_5 enforces. Blob read auditing is implemented keylessly instead: azurerm_monitor_diagnostic_setting.blob streams StorageRead to Log Analytics.
  name                  = "landing"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "curated" {
  # checkov:skip=CKV2_AZURE_21:Deliberately stricter than the check. It is satisfied only by azurerm_log_analytics_storage_insights, whose storage_account_key argument is required by the provider -- but this account sets shared_access_key_enabled = false, which CKV_NHI_5 enforces. Blob read auditing is implemented keylessly instead: azurerm_monitor_diagnostic_setting.blob streams StorageRead to Log Analytics.
  name                  = "curated"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
