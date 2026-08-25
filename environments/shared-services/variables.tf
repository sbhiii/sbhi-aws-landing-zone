
# Common
variable "region" {
  description = "Region of the shared services account"
  type        = string
  default     = "eu-west-1"
}

variable "shared_services_account_id" {
  description = "account ID of the shared services account"
  type        = string
}

## DNS

variable "homelab_zone_name" {
  description = "Subdomain delegated from the apex zone for the homelab cluster"
  type        = string
}

variable "mail_zones" {
  description = "Apex zones for domains registered in this account, keyed by zone name. Mail records only."
  type = map(object({
    mx            = list(string)
    txt           = optional(list(string), [])
    ttl           = optional(number, 60)
    auto_renew    = optional(bool, true)
    transfer_lock = optional(bool, false)
  }))
  default = {}
}

variable "unserved_domains" {
  description = "Domains registered in this account with no hosted zone here. Nameservers are left unmanaged."
  type = map(object({
    auto_renew = bool
    # Stated rather than defaulted: the provider defaults this to true, so
    # omitting it silently enables a lock on a domain that did not have one.
    transfer_lock = bool
  }))
  default = {}
}
