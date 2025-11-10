# This example doesn't cover using a remote backend for storing the current
# terraform state in OVH Object Storage or other methods. If using automation
# to apply the configuration or if multiple people will be managing these
# resources, this is recommended.

# Configure the OVH Provider
provider "ovh" {
  endpoint = "ovh-eu" # Change to your OVH endpoint (ovh-eu, ovh-us, ovh-ca)
}

# Configure OpenStack provider for OVH Public Cloud
provider "openstack" {
  # Authentication will be handled via OVH credentials
  # or environment variables (OS_* variables)
}

locals {
  # Change these to match your environment
  domain_name = var.domain_name
  project_id  = var.project_id # Your OVH Public Cloud project ID 
  region      = var.region

  # Network configuration
  network_name = "fleet-network"
  subnet_name  = "fleet-subnet"
  subnet_cidr  = "10.0.0.0/24"

  # Database configuration
  database_name     = "fleet-db"
  database_user     = "fleet"
  database_password = var.database_password

  # Redis configuration
  redis_name = "fleet-redis"

  # Load balancer configuration
  lb_name = "fleet-lb"

  # Fleet configuration
  fleet_image = "fleetdm/fleet:v4.76.0"

  # Extra ENV Vars for Fleet customization
  fleet_environment_variables = {
    FLEET_LOGGING_JSON                      = "true"
    FLEET_MYSQL_MAX_OPEN_CONNS              = "10"
    FLEET_MYSQL_READ_REPLICA_MAX_OPEN_CONNS = "10"
    FLEET_REDIS_MAX_OPEN_CONNS              = "500"
    FLEET_REDIS_MAX_IDLE_CONNS              = "500"
  }
}

# Create a network
resource "openstack_networking_network_v2" "fleet_network" {
  name           = local.network_name
  admin_state_up = "true"
  region         = local.region
}

# Create a subnet
resource "openstack_networking_subnet_v2" "fleet_subnet" {
  name       = local.subnet_name
  network_id = openstack_networking_network_v2.fleet_network.id
  cidr       = local.subnet_cidr
  ip_version = 4
  region     = local.region

  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# Create a router
resource "openstack_networking_router_v2" "fleet_router" {
  name                = "fleet-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
  region              = local.region
}

# Attach the subnet to the router
resource "openstack_networking_router_interface_v2" "fleet_router_interface" {
  router_id = openstack_networking_router_v2.fleet_router.id
  subnet_id = openstack_networking_subnet_v2.fleet_subnet.id
  region    = local.region
}

# Get the external network
data "openstack_networking_network_v2" "external" {
  name     = "Ext-Net"
  external = true
  region   = local.region
}

# Security group for Fleet application
resource "openstack_networking_secgroup_v2" "fleet_app" {
  name        = "fleet-app-sg"
  description = "Security group for Fleet application"
  region      = local.region
}

# Allow HTTP traffic
resource "openstack_networking_secgroup_rule_v2" "fleet_app_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.fleet_app.id
  region            = local.region
}

# Allow HTTPS traffic
resource "openstack_networking_secgroup_rule_v2" "fleet_app_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.fleet_app.id
  region            = local.region
}

# Allow Fleet default port
resource "openstack_networking_secgroup_rule_v2" "fleet_app_8080" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = local.subnet_cidr
  security_group_id = openstack_networking_secgroup_v2.fleet_app.id
  region            = local.region
}

# Security group for database
resource "openstack_networking_secgroup_v2" "fleet_db" {
  name        = "fleet-db-sg"
  description = "Security group for Fleet database"
  region      = local.region
}

# Allow MySQL traffic from Fleet app
resource "openstack_networking_secgroup_rule_v2" "fleet_db_mysql" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3306
  port_range_max    = 3306
  remote_group_id   = openstack_networking_secgroup_v2.fleet_app.id
  security_group_id = openstack_networking_secgroup_v2.fleet_db.id
  region            = local.region
}

# Security group for Redis
resource "openstack_networking_secgroup_v2" "fleet_redis" {
  name        = "fleet-redis-sg"
  description = "Security group for Fleet Redis"
  region      = local.region
}

# Allow Redis traffic from Fleet app
resource "openstack_networking_secgroup_rule_v2" "fleet_redis_port" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6379
  port_range_max    = 6379
  remote_group_id   = openstack_networking_secgroup_v2.fleet_app.id
  security_group_id = openstack_networking_secgroup_v2.fleet_redis.id
  region            = local.region
}

# Create MySQL database instance
resource "openstack_db_instance_v1" "fleet_mysql" {
  name      = local.database_name
  flavor_id = data.openstack_compute_flavor_v2.db_flavor.id
  size      = 20
  region    = local.region

  network {
    uuid = openstack_networking_network_v2.fleet_network.id
  }

  database {
    name = "fleet"
  }

  user {
    name      = local.database_user
    password  = local.database_password
    databases = ["fleet"]
  }

  datastore {
    type    = "mysql"
    version = "8.0"
  }
}

# Get database flavor
data "openstack_compute_flavor_v2" "db_flavor" {
  name   = "db1-7" # Adjust based on your needs 
  region = local.region
}

# Create Redis instance
resource "openstack_compute_instance_v2" "fleet_redis" {
  name            = local.redis_name
  image_name      = "Ubuntu 22.04"
  flavor_name     = "s1-2" # Adjust based on your needs 
  key_pair        = var.key_pair_name
  security_groups = [openstack_networking_secgroup_v2.fleet_redis.name]
  region          = local.region

  network {
    uuid = openstack_networking_network_v2.fleet_network.id
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y redis-server
    sed -i 's/bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
    sed -i 's/protected-mode yes/protected-mode no/' /etc/redis/redis.conf
    systemctl restart redis-server
    systemctl enable redis-server
  EOF
}

# Create Fleet application instances
resource "openstack_compute_instance_v2" "fleet_app" {
  count           = var.fleet_instance_count
  name            = "fleet-app-${count.index + 1}"
  image_name      = "Ubuntu 22.04"
  flavor_name     = var.fleet_instance_flavor
  key_pair        = var.key_pair_name
  security_groups = [openstack_networking_secgroup_v2.fleet_app.name]
  region          = local.region

  network {
    uuid = openstack_networking_network_v2.fleet_network.id
  }

  user_data = templatefile("${path.module}/fleet-user-data.sh", {
    mysql_host        = openstack_db_instance_v1.fleet_mysql.addresses[0]
    mysql_user        = local.database_user
    mysql_password    = local.database_password
    mysql_database    = "fleet"
    redis_host        = openstack_compute_instance_v2.fleet_redis.access_ip_v4
    fleet_image       = local.fleet_image
    domain_name       = local.domain_name
    fleet_license_key = var.fleet_license_key
    environment_vars  = local.fleet_environment_variables
  })

  depends_on = [
    openstack_db_instance_v1.fleet_mysql,
    openstack_compute_instance_v2.fleet_redis
  ]
}

# Create load balancer
resource "openstack_lb_loadbalancer_v2" "fleet_lb" {
  name          = local.lb_name
  vip_subnet_id = openstack_networking_subnet_v2.fleet_subnet.id
  region        = local.region
}

# Create load balancer pool
resource "openstack_lb_pool_v2" "fleet_pool" {
  name            = "fleet-pool"
  protocol        = "HTTP"
  lb_method       = "ROUND_ROBIN"
  loadbalancer_id = openstack_lb_loadbalancer_v2.fleet_lb.id
  region          = local.region
}

# Add Fleet instances to the pool
resource "openstack_lb_member_v2" "fleet_members" {
  count         = length(openstack_compute_instance_v2.fleet_app)
  pool_id       = openstack_lb_pool_v2.fleet_pool.id
  address       = openstack_compute_instance_v2.fleet_app[count.index].access_ip_v4
  protocol_port = 8080
  region        = local.region
}

# Create load balancer listener
resource "openstack_lb_listener_v2" "fleet_listener" {
  name            = "fleet-listener"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = openstack_lb_loadbalancer_v2.fleet_lb.id
  default_pool_id = openstack_lb_pool_v2.fleet_pool.id
  region          = local.region
}

# Create floating IP for load balancer
resource "openstack_networking_floatingip_v2" "fleet_lb_fip" {
  pool   = "Ext-Net"
  region = local.region
}

# Associate floating IP with load balancer
resource "openstack_networking_floatingip_associate_v2" "fleet_lb_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.fleet_lb_fip.address
  port_id     = openstack_lb_loadbalancer_v2.fleet_lb.vip_port_id
  region      = local.region
}

# DNS record (if using OVH DNS)
resource "ovh_domain_zone_record" "fleet_a_record" {
  count     = var.use_ovh_dns ? 1 : 0
  zone      = var.domain_zone
  subdomain = split(".", local.domain_name)[0]
  fieldtype = "A"
  ttl       = 300
  target    = openstack_networking_floatingip_v2.fleet_lb_fip.address
}