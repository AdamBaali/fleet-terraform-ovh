output "fleet_url" {
  value = "<FLEET_URL>"
  description = "The URL for accessing the Fleet service."
}

output "load_balancer_ip" {
  value = "<LOAD_BALANCER_IP>"
  description = "The IP address of the load balancer."
}

output "database_host" {
  value = "<DATABASE_HOST>"
  description = "The host address for the database."
}

output "redis_host" {
  value = "<REDIS_HOST>"
  description = "The host address for Redis."
}

output "fleet_instances" {
  value = "<FLEET_INSTANCES>"
  description = "The number of Fleet instances running."
}

output "dns_configuration_instructions" {
  value = "<DNS_CONFIGURATION_INSTRUCTIONS>"
  description = "Instructions for configuring DNS for the Fleet service."
}