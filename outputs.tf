output "fleet_url" {
  value       = var.use_ovh_dns ? "https://${var.domain_name}" : "http://${openstack_networking_floatingip_v2.fleet_lb_fip.address}"
  description = "The URL for accessing the Fleet service."
}

output "load_balancer_ip" {
  value       = openstack_networking_floatingip_v2.fleet_lb_fip.address
  description = "The IP address of the load balancer."
}

output "database_host" {
  value       = openstack_db_instance_v1.fleet_mysql.addresses[0]
  description = "The host address for the database."
}

output "redis_host" {
  value       = openstack_compute_instance_v2.fleet_redis.access_ip_v4
  description = "The host address for Redis."
}

output "fleet_instances" {
  value = {
    count = length(openstack_compute_instance_v2.fleet_app)
    instances = [for instance in openstack_compute_instance_v2.fleet_app : {
      name       = instance.name
      private_ip = instance.access_ip_v4
    }]
  }
  description = "Information about the Fleet instances running."
}

output "dns_configuration_instructions" {
  value       = var.use_ovh_dns ? "DNS has been automatically configured with OVH DNS." : <<-EOT
    Manual DNS configuration required:
    
    Please create an A record for ${var.domain_name} pointing to ${openstack_networking_floatingip_v2.fleet_lb_fip.address}
    
    Example DNS record:
    Type: A
    Name: ${var.domain_name}
    Value: ${openstack_networking_floatingip_v2.fleet_lb_fip.address}
    TTL: 300
  EOT
  description = "Instructions for configuring DNS for the Fleet service."
}