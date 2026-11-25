variable "environment" {
  description = "Environment name for resource naming"
  type        = string
  default     = "dev"
}

variable "api_access_ip_ranges" {
  description = "Canonical CIDRs allowed by the example API access rule. The default is a documentation range (RFC 5737): replace it with your own egress ranges before applying, or you will lock yourself out of the API"
  type        = list(string)
  default     = ["192.0.2.0/24"]
}
