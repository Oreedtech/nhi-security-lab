variable "subscription_id" {
  description = "Target subscription. The lab is designed to run in a dedicated subscription so that scope boundaries are meaningful."
  type        = string
}

variable "prefix" {
  description = "Short name prefix for all resources."
  type        = string
  default     = "nhilab"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.prefix))
    error_message = "prefix must be 3-10 lowercase alphanumeric characters."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

# Every workload identity must declare an owner and an expiry date. CKV_NHI_6 fails the
# build if either is missing -- an identity nobody owns is the one that outlives its purpose.
variable "identity_owner" {
  description = "Team or individual accountable for reviewing these identities."
  type        = string
}

variable "review_by" {
  description = "Date (YYYY-MM-DD) by which these identities must be recertified."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", var.review_by))
    error_message = "review_by must be an ISO date, YYYY-MM-DD."
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
