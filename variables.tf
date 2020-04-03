# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "name_prefix" {
  description = "A prefix used for naming resources."
  type        = string
}

variable "hosted_zone_name" {
  description = "The name of the hosted zone in which to register this site"
  type        = string
}

variable "bucket_versioning" {
  description = "(Optional) Enable versioning. Once you version-enable a bucket, it can never return to an unversioned state. You can, however, suspend versioning on that bucket."
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = map(string)
  default     = {}
}

variable "site_name" {
  description = "The name of the certificate and address for the site"
  type        = string
}

variable "use_external_bucket" {
  description = "Set this value to true if you wish to supply an existing bucket to use for this site"
  type        = bool
  default     = false
}

variable "website_bucket" {
  description = "(Optional) The name of an existing bucket to use - if not set the module will create a bucket"
  type        = string
  default     = ""
}

variable "external_domain" {
  description = "An external domain to access the site from"
  default     = ""
  type        = string
}

