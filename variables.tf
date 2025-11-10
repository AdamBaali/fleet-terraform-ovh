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

variable "domain" {
  description = "Domain settings for the deployment"
  type        = string
}

# Additional customization options can be added here
