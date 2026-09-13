output "workload_identity_client_ids" {
  description = "Client IDs to assign to the compute that runs each workload."
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.client_id }
}

output "workload_identity_principal_ids" {
  description = "Principal (object) IDs, for correlating against sign-in and audit logs."
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.principal_id }
}

output "log_analytics_workspace_id" {
  description = "Workspace the detections in detections/ are written against."
  value       = azurerm_log_analytics_workspace.this.id
}

output "review_by" {
  description = "Recertification date carried by every identity in this deployment."
  value       = var.review_by
}
