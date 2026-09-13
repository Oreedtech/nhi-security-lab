"""Custom Checkov policies asserting the non-human identity controls this lab claims.

Each check corresponds to one row of the control table in the README. They run on every
commit, so a change that reintroduces standing privilege, a shared secret, or an
unaccountable identity fails the build instead of merging.
"""

from checkov.common.models.enums import CheckCategories, CheckResult
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

# Roles that make the rest of the model meaningless. Owner and User Access Administrator can
# grant themselves anything; Contributor can read and rewrite every data-plane resource in
# scope. A workload identity holding one of these has no least-privilege story at all.
_PRIVILEGED_ROLES = {
    "owner",
    "contributor",
    "user access administrator",
    "role based access control administrator",
}


def _first(conf, key):
    """Terraform confs arrive as {key: [value]}; unwrap one level."""
    v = conf.get(key)
    if isinstance(v, list) and v:
        return v[0]
    return v


class RoleAssignmentNotSubscriptionScoped(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="Role assignments must target a resource, not a subscription or management group",
            id="CKV_NHI_1",
            categories=[CheckCategories.IAM],
            supported_resources=["azurerm_role_assignment"],
        )

    def scan_resource_conf(self, conf):
        scope = _first(conf, "scope")
        if not isinstance(scope, str):
            # An interpolated scope resolves to a resource id; a bare subscription scope is
            # written as a literal, so a non-literal here is the safe case.
            return CheckResult.PASSED
        s = scope.strip().lower()
        if s.startswith("/subscriptions/") and "/resourcegroups/" not in s:
            return CheckResult.FAILED
        if s.startswith("/providers/microsoft.management/"):
            return CheckResult.FAILED
        return CheckResult.PASSED


class RoleAssignmentNotPrivileged(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="Workload identities must not hold Owner, Contributor, or UAA",
            id="CKV_NHI_2",
            categories=[CheckCategories.IAM],
            supported_resources=["azurerm_role_assignment"],
        )

    def scan_resource_conf(self, conf):
        role = _first(conf, "role_definition_name")
        if isinstance(role, str) and role.strip().lower() in _PRIVILEGED_ROLES:
            return CheckResult.FAILED
        return CheckResult.PASSED


class RoleAssignmentDeclaresPrincipalType(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="Role assignments must declare principal_type ServicePrincipal",
            id="CKV_NHI_3",
            categories=[CheckCategories.IAM],
            supported_resources=["azurerm_role_assignment"],
        )

    def scan_resource_conf(self, conf):
        # Without principal_type, Terraform resolves the principal at apply time against the
        # directory. If the object id is ever recycled onto a different principal kind, the
        # assignment silently follows it. Declaring the type pins the intent.
        pt = _first(conf, "principal_type")
        if isinstance(pt, str) and pt.strip() == "ServicePrincipal":
            return CheckResult.PASSED
        return CheckResult.FAILED


class KeyVaultUsesRbac(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="Key Vault must use RBAC authorization, not access policies",
            id="CKV_NHI_4",
            categories=[CheckCategories.IAM],
            supported_resources=["azurerm_key_vault"],
        )

    def scan_resource_conf(self, conf):
        v = _first(conf, "rbac_authorization_enabled")
        return CheckResult.PASSED if v is True else CheckResult.FAILED


class StorageAccountKeysDisabled(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="Storage account keys must be disabled so identity is the only access path",
            id="CKV_NHI_5",
            categories=[CheckCategories.IAM],
            supported_resources=["azurerm_storage_account"],
        )

    def scan_resource_conf(self, conf):
        v = _first(conf, "shared_access_key_enabled")
        return CheckResult.PASSED if v is False else CheckResult.FAILED


class IdentityIsAccountable(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="Every workload identity must carry an owner and a recertification date",
            id="CKV_NHI_6",
            categories=[CheckCategories.IAM],
            supported_resources=["azurerm_user_assigned_identity"],
        )

    def scan_resource_conf(self, conf):
        tags = _first(conf, "tags")
        if not isinstance(tags, dict):
            return CheckResult.FAILED
        keys = {str(k).lower() for k in tags}
        # An identity that cannot name its owner cannot be recertified, and an identity that
        # is never recertified is how standing workload access outlives the thing it served.
        return CheckResult.PASSED if {"owner", "review-by"} <= keys else CheckResult.FAILED


class NoDirectorySecrets(BaseResourceCheck):
    def __init__(self):
        super().__init__(
            name="No client secrets or SP passwords may be declared in configuration",
            id="CKV_NHI_7",
            categories=[CheckCategories.SECRETS],
            supported_resources=[
                "azuread_application_password",
                "azuread_service_principal_password",
            ],
        )

    def scan_resource_conf(self, conf):
        # This resource type existing at all is the finding. A managed identity has no
        # secret to rotate, leak, or forget to expire -- introducing one reverts the lab's
        # central premise, so the check fails unconditionally rather than inspecting fields.
        return CheckResult.FAILED


check_scope = RoleAssignmentNotSubscriptionScoped()
check_privileged_role = RoleAssignmentNotPrivileged()
check_principal_type = RoleAssignmentDeclaresPrincipalType()
check_kv_rbac = KeyVaultUsesRbac()
check_storage_keys = StorageAccountKeysDisabled()
check_accountable = IdentityIsAccountable()
check_no_secrets = NoDirectorySecrets()
