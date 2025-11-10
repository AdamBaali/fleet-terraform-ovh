# Fleet on OVH Public Cloud - Terraform Configuration

This Terraform configuration deploys [Fleet](https://fleetdm.com) on OVH Public Cloud using OpenStack infrastructure. Fleet is an open-source device management platform that helps you manage your fleet of computers and devices.

## Architecture Overview

This configuration deploys the following infrastructure:

- **Network Infrastructure**:
  - Private network and subnet (10.0.0.0/24)
  - Router with external network connectivity
  - Security groups for application, database, and Redis layers

- **Compute Resources**:
  - Load balancer with floating IP for high availability
  - Multiple Fleet application instances (configurable count)
  - Redis instance for session management and caching

- **Database**:
  - MySQL 8.0 database instance (OVH managed database service)

- **Optional DNS**:
  - Automatic DNS record creation with OVH DNS (if enabled)

### Architecture Diagram

```
                                    ┌─────────────┐
                                    │  Internet   │
                                    └──────┬──────┘
                                           │
                                    ┌──────▼──────┐
                                    │ Floating IP │
                                    └──────┬──────┘
                                           │
                    ┌──────────────────────▼──────────────────────┐
                    │          Load Balancer (HTTP)               │
                    └──────────┬──────────────────────┬───────────┘
                               │                      │
                    ┌──────────▼──────────┐  ┌────────▼─────────┐
                    │  Fleet Instance 1   │  │ Fleet Instance N │
                    │    (Docker)         │  │   (Docker)       │
                    └──────────┬──────────┘  └────────┬─────────┘
                               │                      │
                    ┌──────────┴──────────────────────┴───────────┐
                    │                                              │
              ┌─────▼─────┐                              ┌────────▼────────┐
              │   MySQL   │                              │      Redis      │
              │ Database  │                              │     Cache       │
              └───────────┘                              └─────────────────┘
```

## Prerequisites

Before you begin, ensure you have:

1. **OVH Account**: An active OVH account with a Public Cloud project
2. **OVH Credentials**: API credentials for OVH (application key, application secret, consumer key)
3. **Terraform**: Terraform >= 1.0 installed on your local machine
4. **SSH Key Pair**: An SSH key pair created in your OVH Public Cloud project
5. **Domain Name** (optional): A domain name for accessing Fleet via HTTPS

### Setting up OVH API Credentials

1. Go to [https://eu.api.ovh.com/createToken/](https://eu.api.ovh.com/createToken/)
2. Log in with your OVH account
3. Grant the necessary permissions:
   - GET, POST, PUT, DELETE on `/cloud/*`
   - GET, POST, PUT, DELETE on `/domain/*` (if using OVH DNS)
4. Save your credentials:
   ```bash
   export OVH_ENDPOINT="ovh-eu"
   export OVH_APPLICATION_KEY="your_app_key"
   export OVH_APPLICATION_SECRET="your_app_secret"
   export OVH_CONSUMER_KEY="your_consumer_key"
   ```

### Setting up OpenStack Credentials

For OpenStack provider authentication, you can either:

1. **Use OVH API credentials** (recommended): The OpenStack provider will automatically use your OVH credentials
2. **Use OpenStack RC file**: Download the OpenStack RC file from your OVH Public Cloud project and source it:
   ```bash
   source openrc.sh
   ```

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/AdamBaali/fleet-terraform-ovh.git
cd fleet-terraform-ovh
```

### 2. Configure Variables

Copy the example variables file and edit it with your settings:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your preferred editor and fill in the required values:

```hcl
project_id            = "your-project-id"
region                = "GRA11"
database_password     = "your-secure-password"
fleet_instance_count  = 2
fleet_instance_flavor = "s1-4"
key_pair_name         = "your-ssh-key"
domain_name           = "fleet.example.com"
use_ovh_dns           = false
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

Review the planned changes to ensure everything looks correct.

### 5. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to create the resources.

### 6. Get the Outputs

After successful deployment, Terraform will output important information:

```bash
terraform output
```

You'll see:
- `fleet_url`: The URL to access Fleet
- `load_balancer_ip`: The load balancer's public IP
- `dns_configuration_instructions`: Instructions for DNS configuration (if not using OVH DNS)

### 7. Access Fleet

1. If you're not using automatic DNS, configure your domain's DNS to point to the load balancer IP
2. Wait a few minutes for Fleet to fully start up
3. Navigate to your Fleet URL in a browser
4. Complete the Fleet setup wizard

## Configuration Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project_id` | OVH Public Cloud project ID | `"abc123def456"` |
| `region` | OVH region for deployment | `"GRA11"` |
| `database_password` | MySQL database password | `"SecurePass123!"` |
| `fleet_instance_flavor` | Instance size for Fleet servers | `"s1-4"` |
| `key_pair_name` | SSH key pair name | `"my-ssh-key"` |
| `domain_name` | Domain name for Fleet | `"fleet.example.com"` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `fleet_instance_count` | Number of Fleet instances | `1` |
| `use_ovh_dns` | Use OVH DNS for automatic DNS | `false` |
| `domain_zone` | DNS zone (if using OVH DNS) | `""` |
| `fleet_license_key` | Fleet Premium license key | `""` |

### Available Regions

Common OVH Public Cloud regions:
- `GRA11` - Gravelines, France
- `SBG5` - Strasbourg, France
- `BHS5` - Beauharnois, Canada
- `DE1` - Frankfurt, Germany
- `UK1` - London, United Kingdom
- `WAW1` - Warsaw, Poland

### Instance Flavors

Common instance flavors for Fleet:
- `s1-2`: 1 vCore, 2GB RAM - Suitable for testing
- `s1-4`: 1 vCore, 4GB RAM - Minimum for small production
- `s1-8`: 1 vCore, 8GB RAM - Recommended for production
- `b2-7`: 2 vCores, 7GB RAM - Better for larger deployments
- `b2-15`: 4 vCores, 15GB RAM - High performance

## Post-Deployment Configuration

### Setting Up Fleet

1. Navigate to your Fleet URL
2. Create the first admin user
3. Configure organization settings
4. Add hosts by installing the Fleet agent (osquery)

### Enabling HTTPS

For production use, you should enable HTTPS:

1. **Option 1: Use a reverse proxy**
   - Deploy a reverse proxy (nginx, Caddy) in front of the load balancer
   - Configure SSL/TLS certificates (Let's Encrypt recommended)

2. **Option 2: Use OVH Load Balancer with SSL**
   - Modify the load balancer listener to use HTTPS
   - Upload your SSL certificate to OVH

### Backup Strategy

Important data to backup:
- **MySQL Database**: Configure regular backups through OVH's backup service
- **Fleet Configuration**: Export Fleet configuration periodically

## Monitoring and Maintenance

### Accessing Instances

SSH into any Fleet instance using your SSH key:

```bash
ssh ubuntu@<instance-ip> -i /path/to/your/key.pem
```

### Viewing Fleet Logs

On any Fleet instance:

```bash
sudo journalctl -u fleet -f
```

Or view Docker logs:

```bash
sudo docker logs -f fleet
```

### Scaling Fleet Instances

To scale the number of Fleet instances:

1. Update `fleet_instance_count` in `terraform.tfvars`
2. Run `terraform apply`
3. The load balancer will automatically add new instances

### Database Maintenance

The MySQL database is managed by OVH. You can manage it through the OVH console:
- View metrics and performance
- Configure backups
- Scale resources
- Apply updates

## Troubleshooting

### Fleet instances not starting

Check the user-data script execution:

```bash
sudo cat /var/log/cloud-init-output.log
```

### Cannot connect to Fleet

1. Verify the load balancer is running: `terraform show | grep fleet_lb`
2. Check security groups allow traffic on port 80/443
3. Verify DNS is correctly configured
4. Check Fleet container status: `sudo docker ps`

### Database connection issues

1. Verify database is running: Check OVH console
2. Check database credentials in Fleet configuration
3. Verify security groups allow MySQL traffic (port 3306)
4. Check Fleet logs for specific error messages

### Performance issues

1. Check instance sizes - may need to increase `fleet_instance_flavor`
2. Increase `fleet_instance_count` for more capacity
3. Review database performance metrics in OVH console
4. Check Redis instance is running properly

## Cost Estimation

Approximate monthly costs (prices may vary):

| Resource | Specification | Estimated Cost |
|----------|--------------|----------------|
| Fleet Instances (x2) | s1-4 | ~€20/month |
| MySQL Database | db1-7 | ~€40/month |
| Redis Instance | s1-2 | ~€10/month |
| Load Balancer | Standard | ~€10/month |
| Floating IP | 1 IP | ~€4/month |
| Network Traffic | Typical usage | ~€5/month |
| **Total** | | **~€89/month** |

*Note: Prices are estimates and may vary by region and usage.*

## Security Considerations

1. **Database Password**: Use a strong, randomly generated password
2. **SSH Keys**: Keep your SSH private keys secure and never commit them to version control
3. **Network Isolation**: The database and Redis are only accessible from Fleet instances
4. **Regular Updates**: Keep Fleet and system packages updated
5. **HTTPS**: Enable HTTPS for production deployments
6. **Firewall Rules**: Security groups restrict access to necessary ports only

## Upgrading Fleet

To upgrade Fleet to a newer version:

1. Update the `fleet_image` in `main.tf` locals (line 53):
   ```hcl
   fleet_image = "fleetdm/fleet:v4.xx.x"
   ```
2. Run `terraform apply`
3. Terraform will recreate the instances with the new version

## Cleanup

To destroy all resources created by this configuration:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources, including the database. Make sure you have backups of any important data.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

- **Fleet Documentation**: [https://fleetdm.com/docs](https://fleetdm.com/docs)
- **OVH Documentation**: [https://docs.ovh.com/](https://docs.ovh.com/)
- **Issues**: Please report issues on the GitHub repository

## License

This Terraform configuration is provided as-is for deploying Fleet on OVH Public Cloud.

## Acknowledgments

- [Fleet](https://fleetdm.com) - Open-source device management
- [OVH](https://www.ovh.com) - Cloud infrastructure provider
- Inspired by Fleet's official Terraform examples for AWS and GCP

