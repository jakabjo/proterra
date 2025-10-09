variable "region" {
  type        = string
  description = "AWS region for all resources"
  default     = "us-west-2"
}

variable "project" {
  type        = string
  description = "Project/name prefix used for tags and resource names"
  default     = "sql-hybrid"
}

variable "vpc_cidr" {
  type        = string
  description = "Primary VPC CIDR"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR (e.g., 10.0.0.0/16)."
  }
}

variable "private_subnet_cidr" {
  type        = string
  description = "Private subnet for SQL nodes"
  default     = "10.0.10.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_subnet_cidr))
    error_message = "private_subnet_cidr must be a valid IPv4 CIDR (e.g., 10.0.10.0/24)."
  }
}

variable "onprem_cidr" {
  type        = string
  description = "On-prem network CIDR reachable over VPN/TGW"
  default     = "192.168.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.onprem_cidr))
    error_message = "onprem_cidr must be a valid IPv4 CIDR (e.g., 192.168.0.0/16)."
  }
}

variable "customer_gateway_ip" {
  type        = string
  description = "Public IP of the on-prem Customer Gateway"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for SQL nodes"
  default     = "r6i.xlarge"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name (optional)"
  default     = null
}

variable "sql_port" {
  type        = number
  description = "SQL Server listener port"
  default     = 1433

  validation {
    condition     = var.sql_port >= 1 && var.sql_port <= 65535
    error_message = "sql_port must be between 1 and 65535."
  }
}

variable "health_port" {
  type        = number
  description = "Custom TCP health port used by the NLB to detect the AG primary"
  default     = 59999

  validation {
    condition     = var.health_port >= 1 && var.health_port <= 65535 && var.health_port != var.sql_port
    error_message = "health_port must be 1–65535 and must not equal sql_port."
  }
}

variable "hosted_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID for the AG listener DNS record"
}

variable "listener_dns_name" {
  type        = string
  description = "AG listener FQDN (e.g., prodaglistener.example.com)"
}

variable "onprem_listener_ip" {
  type        = string
  description = "On-prem AG listener IP used as Route 53 SECONDARY A record"
}

variable "ad_domain_name" {
  type        = string
  description = "AD domain name (e.g., corp.example.com)"
}

variable "ad_join_user" {
  type        = string
  # Escape backslashes to be safe in HCL and editors
  description = "Domain join user (e.g., corp\\\\svc-join)"
}

variable "ad_join_password_ssm_param" {
  type        = string
  description = "SSM SecureString parameter name for the domain-join user's password (e.g., /corp/joinsvc/password)"
}

variable "ad_target_ou" {
  type        = string
  description = "Optional OU distinguished name for computer accounts (e.g., OU=Servers,DC=corp,DC=example,DC=com)"
  default     = ""
}
