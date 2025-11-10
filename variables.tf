variable "project_id" {
  description = "The ID of the project"
  type        = string
}

variable "region" {
  description = "The region to deploy the fleet"
  type        = string
}

variable "database_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}

variable "fleet_instance_count" {
  description = "The number of fleet instances to deploy"
  type        = number
  default     = 1
}

variable "fleet_instance_flavor" {
  description = "The flavor of the fleet instances to use"
  type        = string
}

variable "key_pair_name" {
  description = "The name of the key pair to use for SSH access"
  type        = string
}

variable "domain_name" {
  description = "The fully qualified domain name for Fleet (e.g., fleet.example.com)"
  type        = string
}

variable "use_ovh_dns" {
  description = "Whether to use OVH DNS to create DNS records automatically"
  type        = bool
  default     = false
}

variable "domain_zone" {
  description = "The OVH DNS zone (e.g., example.com) - required if use_ovh_dns is true"
  type        = string
  default     = ""
}

variable "fleet_license_key" {
  description = "Fleet premium license key (optional, for premium features)"
  type        = string
  default     = ""
  sensitive   = true
}

# Additional customization options can be added here
