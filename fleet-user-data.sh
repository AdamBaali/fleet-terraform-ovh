#!/bin/bash
set -e

# Fleet User Data Script for OVH Public Cloud
# This script sets up Docker and runs Fleet in a container

# Update system packages
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Create Fleet configuration directory
mkdir -p /etc/fleet

# Build MySQL connection string
MYSQL_CONNECTION="mysql://${mysql_user}:${mysql_password}@${mysql_host}:3306/${mysql_database}"

# Build Redis connection string
REDIS_CONNECTION="redis://${redis_host}:6379"

# Create environment file for Fleet
cat > /etc/fleet/fleet.env <<EOF
FLEET_MYSQL_ADDRESS=$MYSQL_CONNECTION
FLEET_REDIS_ADDRESS=$REDIS_CONNECTION
FLEET_SERVER_ADDRESS=0.0.0.0:8080
FLEET_SERVER_TLS=false
FLEET_LOGGING_JSON=true
%{ for key, value in environment_vars ~}
${key}=${value}
%{ endfor ~}
EOF

# Add license key if provided
if [ -n "${fleet_license_key}" ]; then
    echo "FLEET_LICENSE_KEY=${fleet_license_key}" >> /etc/fleet/fleet.env
fi

# Pull Fleet Docker image
docker pull ${fleet_image}

# Run Fleet database migrations (only on first instance)
# This command will fail gracefully if migrations are already applied
docker run --rm \
    --env-file /etc/fleet/fleet.env \
    ${fleet_image} \
    fleet prepare db || true

# Create systemd service for Fleet
cat > /etc/systemd/system/fleet.service <<EOF
[Unit]
Description=Fleet Server
After=docker.service
Requires=docker.service

[Service]
TimeoutStartSec=0
Restart=always
RestartSec=10
ExecStartPre=-/usr/bin/docker stop fleet
ExecStartPre=-/usr/bin/docker rm fleet
ExecStart=/usr/bin/docker run \\
    --name fleet \\
    --env-file /etc/fleet/fleet.env \\
    -p 8080:8080 \\
    ${fleet_image} \\
    fleet serve

ExecStop=/usr/bin/docker stop fleet

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Fleet service
systemctl daemon-reload
systemctl enable fleet.service
systemctl start fleet.service

# Configure log rotation for Fleet
cat > /etc/logrotate.d/fleet <<EOF
/var/log/fleet/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF

echo "Fleet installation completed successfully"
