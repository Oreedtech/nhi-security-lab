# Non-human identity security lab

[![verify](https://github.com/Oreedtech/nhi-security-lab/actions/workflows/verify.yml/badge.svg)](https://github.com/Oreedtech/nhi-security-lab/actions/workflows/verify.yml)

Workload identity governance in Azure, built with Terraform and verified in CI.

Three user-assigned managed identities model the roles a real pipeline separates — ingest,
processor, reader — each holding the narrowest built-in role that lets it do its job, scoped
to a single blob container or a single vault. **No identity in this lab has a credential.**
There is no client secret to rotate, leak, or forget to expire, because a managed identity
does not have one.

Seven custom Checkov policies assert that on every commit. The detections in `detections/`
cover the same ground from the other side: the identity-plane attacks that a correctly
configured tenant still has to be able to see.

## The controls this claims

| Control | Enforced by |
|---------|-------------|
| No role assignment reaches subscription or management-group scope | `CKV_NHI_1` |
| No workload identity holds Owner, Contributor, or User Access Administrator | `CKV_NHI_2` |
| Every assignment pins `principal_type` rather than resolving it at apply time | `CKV_NHI_3` |
| Key Vault uses RBAC, so a grant can target one secret instead of the whole vault | `CKV_NHI_4` |
| Storage account keys are disabled, so identity is the only access path | `CKV_NHI_5` |
| Every identity carries an accountable owner and a recertification date | `CKV_NHI_6` |
| No client secret or service principal password is declared anywhere | `CKV_NHI_7` |

`CKV_NHI_3` is the one worth reading the implementation of. Omitting `principal_type` looks
harmless — Terraform resolves the principal against the directory at apply time and the plan
succeeds. But object IDs are recyclable. If the id is ever reissued to a different kind of
principal, the assignment silently follows it, and nothing in the configuration records what
it was supposed to be pointing at. Declaring the type turns an inference into an assertion.

`CKV_NHI_6` is a governance check rather than a technical one, and it is deliberate. The
failure mode for workload identity is not usually a misconfigured grant — it is a correctly
configured grant that outlives the thing it was created for. An identity that cannot name its
owner cannot be recertified, and an identity that is never recertified becomes permanent.

## Detections

Policy-as-code only covers changes made through this repository. These queries cover the
same controls from the portal, a script, or another pipeline — the paths CI cannot see.

| Query | What it surfaces |
|-------|-----------------|
| [`oauth-consent-grant-abuse.kql`](detections/oauth-consent-grant-abuse.kql) | Illicit consent grants — an app given delegated mail or directory scopes, especially tenant-wide |
| [`overpermissioned-app-consent.kql`](detections/overpermissioned-app-consent.kql) | Application permissions granted and never exercised — standing access nobody is watching |
| [`credential-lifecycle-drift.kql`](detections/credential-lifecycle-drift.kql) | Secrets added to apps, and credentials minted with lifetimes over a year |
| [`managed-identity-role-drift.kql`](detections/managed-identity-role-drift.kql) | A service principal granted a forbidden role or subscription scope outside this repo |

The consent queries are the ones that matter most in practice. An illicit consent grant does
not steal a password, so a password reset does not revoke it and MFA does not stop it — the
refresh token simply keeps working until someone notices the app.

## Verifying it

No Azure subscription or credentials required. `terraform init -backend=false` resolves
providers without contacting Azure.

```bash
cd terraform
terraform init -backend=false
terraform validate

cd ..
pip install checkov
checkov --directory terraform --external-checks-dir policy/checkov --framework terraform
```

CI additionally runs `terraform fmt`, `tflint`, and `gitleaks`.
See [.github/workflows/verify.yml](.github/workflows/verify.yml).

A clean run reports **40 passed, 0 failed, 8 skipped**, and the passed set includes every
`CKV_NHI_*` policy. If you see 26 passed and no `CKV_NHI_*` rows, the external checks did not
load — `policy/checkov/__init__.py` is what makes the directory importable, and without it
Checkov's loader silently imports nothing while still exiting 0. Confirm with:

```bash
checkov -d terraform --external-checks-dir policy/checkov --framework terraform --compact | grep CKV_NHI
```

### Policy exceptions

Checkov's built-in Azure ruleset also runs. Where a finding is right, it is fixed. Where it
conflicts with a deliberate decision, it is suppressed inline with a written reason rather
than by loosening the scan:

```bash
grep -rn "checkov:skip" terraform/
```

Two are worth calling out. `CKV_AZURE_43` is a false positive — the storage account name is
assembled with `substr(sha1(...))`, which the parser cannot evaluate, so it cannot confirm a
pattern the construction already guarantees. `CKV2_AZURE_21` is the more interesting one: it
asks that blob reads be logged, and accepts only `azurerm_log_analytics_storage_insights`,
whose `storage_account_key` argument the provider marks *required*. This account disables
account keys, and `CKV_NHI_5` fails the build if that changes. Reads are audited keylessly
through a diagnostic setting instead. Satisfying the check literally would mean reintroducing
an account key to log the reads of an account whose reads are already logged.

An exception with a reason attached is a decision. One without is a gap.

## Deploying it

The lab is designed for a **dedicated subscription**, so that "no assignment reaches
subscription scope" is a meaningful statement rather than an accident of what else happens to
live there.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# fill in subscription_id, identity_owner, review_by
terraform -chdir=terraform apply
```

`identity_owner` and `review_by` are required variables with no defaults. That is intentional:
`CKV_NHI_6` would fail the build anyway, and a required variable surfaces it at plan time
instead.

To run the detections, point Entra ID diagnostic settings (`AuditLogs`,
`ServicePrincipalSignInLogs`) and the subscription activity log at the workspace this
deploys, then run the queries from `detections/` in Log Analytics or as Sentinel analytics
rules.

## Scope and honesty

This is a lab, not a production module. It is built to demonstrate and test a set of workload
identity controls end to end, and it deliberately leaves some things out:

- Single region, no failover, LRS storage — the cost profile is a trial subscription.
- Private endpoints are not deployed. Public network access is denied on both data-plane
  resources, but reaching them from a VNet is left to the deploying environment. The
  corresponding Checkov findings are suppressed inline pointing at gap 1 of the
  [threat model](docs/threat-model.md), not silently passed. See
  [sentinel-secure-ingestion](https://github.com/Oreedtech/sentinel-secure-ingestion) for the
  private-link version of this pattern.
- The detections are written against the documented schemas for `AuditLogs`,
  `AADServicePrincipalSignInLogs` and `AzureActivity`. Tune the thresholds and the
  approved-app lists to your own tenant before alerting on any of them.

## Layout

```
terraform/           identities, scoped RBAC, storage, vault, diagnostics
policy/checkov/      the seven custom policies asserting the controls above
detections/          KQL for the identity-plane attacks the controls do not prevent
docs/                threat model
```
