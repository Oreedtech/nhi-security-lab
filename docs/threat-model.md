# Threat model

Scope: the three workload identities this lab deploys, their role assignments, and the
identity-plane surface around them. Out of scope: the compute that assumes the identities,
and the tenant's human-identity controls.

## What an attacker wants here

Not the data in the storage account — a lab has none worth taking. The target is the
**identity itself**: a principal that authenticates without a human, is rarely reviewed, and
often holds more scope than the thing it serves.

## Attack paths

| # | Path | Control | Residual risk |
|---|------|---------|---------------|
| 1 | Compromise the compute, use its managed identity | Scoped assignments — `ingest` cannot read `curated`; `reader` cannot write anywhere | Real. A compromised host acts as its identity. The control limits blast radius, it does not prevent use. |
| 2 | Steal a credential and replay it off-host | No credential exists — `CKV_NHI_7`, and managed identity tokens are issued by IMDS to the host only | Token theft from the host itself remains possible. |
| 3 | Bypass RBAC with a storage account key | Keys disabled — `CKV_NHI_5` | None while the check holds. |
| 4 | Escalate by granting the identity a broader role | `CKV_NHI_1`, `CKV_NHI_2` in CI; `managed-identity-role-drift.kql` for out-of-band changes | Detection is after the fact. A grant made in the portal is live before the query runs. |
| 5 | Illicit consent grant to an attacker-controlled app | `oauth-consent-grant-abuse.kql` | Detection only. Prevention is tenant-level consent policy, which is outside this lab. |
| 6 | Standing app permission on a decommissioned integration | `overpermissioned-app-consent.kql`, plus `CKV_NHI_6` forcing an owner and review date | Depends on someone acting on the review. |
| 7 | Vault-wide access via a legacy access policy | RBAC enforced — `CKV_NHI_4` | None while the check holds. |

## Known gaps

1. **No private endpoints.** Public network access is denied on the storage account and the
   vault, but the resources are not reachable over private link either. Deploying this into a
   VNet is left to the environment. `CKV2_AZURE_*` findings about private endpoints are
   genuine and not suppressed.

2. **No customer-managed keys.** Platform-managed encryption only.

3. **Detection depends on log ingestion that this repo does not configure for the tenant.**
   The Terraform wires diagnostics for the resources it creates. `AuditLogs` and
   `AADServicePrincipalSignInLogs` are tenant-level Entra ID settings — the queries in
   `detections/` return nothing until those are pointed at a workspace.

4. **Path 1 is not solved.** Nothing here prevents a compromised host from using its own
   identity legitimately. That is the accepted trade of workload identity: the credential
   problem is exchanged for a host-trust problem. The scoped assignments are what keep the
   consequence proportional.

An exception with a reason attached is a decision. One without is a gap.
