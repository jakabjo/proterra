
# AWS Web Application Stack – Terraform

This project provisions a minimal, production-style AWS web application environment using Terraform, built with best practices in mind: private workloads, least-privilege security, no hard-coded secrets, IAM-based access, and CI/CD-ready structure.

---

## Prerequisites & Setup

Before deploying, ensure the following tools are installed:

* **Terraform:** `>= 1.6.0`
* **AWS CLI:** `>= 2.0` (configured with credentials: `aws configure`)
* **Git** (to clone and manage this repo)

### Environment Variables (Optional)

If you want to avoid storing secrets in `terraform.tfvars`, export them:

```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

---

## How to Run

Clone the repository and navigate into it:

```bash
git clone https://github.com/jakabjo/proterra.git
cd Proterra/aws-webstack
```

Initialize Terraform and download providers:

```bash
terraform init
```

Create a `terraform.tfvars` file or pass variables inline. Example:

```hcl
name        = "webapp"
project     = "InternalTools"
env         = "dev"
region      = "us-east-1"
instance_type = "t3.micro"
asg_min     = 2
asg_max     = 4
asg_desired = 2
db_instance_class = "db.t3.micro"
db_multi_az = false
```

Run plan and apply:

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

---

## Architecture Overview

This stack creates a **secure 3-tier web application architecture** in AWS:

* **VPC** – Custom VPC with CIDR (default: `10.0.0.0/16`)
* **Subnets** – 2× public (for ALB), 2× private (for app + DB)
* **NAT Gateway** – Allows private instances outbound internet access
* **Security Groups** – Strict, least-privilege ingress/egress rules
* **Auto Scaling Group (ASG)** – Private EC2 instances (no public IPs), bootstrapped with Nginx web app
* **Application Load Balancer (ALB)** – Public entrypoint, forwards traffic to ASG
* **PostgreSQL (RDS)** – Private database subnet, only accessible by app SG
* **S3 Bucket** – Stores application artifacts and ALB access logs
* **IAM + SSM** – Instances use Session Manager (no SSH) and retrieve credentials from Secrets Manager/SSM

### High-Level Diagram

```
                        ┌──────────────────────────────┐
                        │        Internet Users        │
                        └──────────────┬───────────────┘
                                       │
                              ┌────────▼────────┐
                              │  Application    │
                              │ Load Balancer   │
                              │ (Public Subnet) │
                              └────────┬────────┘
                                       │
                        ┌──────────────▼───────────────┐
                        │      Auto Scaling Group      │
                        │  EC2 (Private Subnet, Nginx) │
                        └──────────────┬───────────────┘
                                       │
                          ┌────────────▼────────────┐
                          │   Amazon RDS (Postgres) │
                          │  Private DB Subnet      │
                          └─────────────────────────┘
                                       │
                              ┌────────▼────────┐
                              │   NAT Gateway   │
                              │  Internet Egress│
                              └─────────────────┘
```

---

## Module Layout

| Module        | Description                                                              |
| ------------- | ------------------------------------------------------------------------ |
| **network/**  | VPC, subnets, internet/NAT gateways, route tables                        |
| **security/** | Security groups with least-privilege inbound/outbound rules              |
| **iam/**      | IAM roles, instance profiles, SSM access, secrets/parameter policies     |
| **storage/**  | S3 buckets for artifacts and ALB access logs                             |
| **compute/**  | Launch Template, ASG, ALB, Target Group, health checks, scaling policies |
| **data/**     | RDS (PostgreSQL), Secrets Manager, SSM Parameter Store                   |

---

## Expected Outputs

After `terraform apply`, you’ll see key outputs:

```bash
alb_dns_name        = "webapp-alb-1234567890.us-east-1.elb.amazonaws.com"
vpc_id             = "vpc-0abcd1234ef567890"
asg_name           = "webapp-asg"
rds_endpoint       = "webapp-pg.abcdefghij.us-east-1.rds.amazonaws.com"
s3_bucket          = "webapp-dev-ab12cd"
alb_logs_bucket    = "webapp-dev-alb-logs-ef34gh"
db_secret_arn      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:webapp/db/creds"
```

**Verification tips:**

* Visit `http://<alb_dns_name>` in your browser – you should see the Nginx “It works 🎉” page.
* Verify RDS endpoint connectivity from inside the VPC.
* Check S3 for ALB logs after traffic hits the load balancer.

---

## Design Choices & Trade-Offs

This stack is designed to strike a balance between production-grade patterns, security best practices, cost awareness, and simplicity (to keep the code understandable for a take-home assignment). Below is a deeper explanation of the key architectural decisions and trade-offs made.

### **Private Subnets by Default**

Decision: All EC2 application instances and the PostgreSQL RDS database live in private subnets without public IPs.

Why: This significantly reduces the exposed attack surface — workloads cannot be directly accessed from the internet. All traffic flows through controlled entry points (ALB or Session Manager).

Trade-Off:

Pros: Stronger security posture, prevents lateral movement from public networks, aligns with AWS Well-Architected Framework.

Cons: Requires additional components (e.g., NAT Gateway for egress, ALB for ingress), which add cost and complexity.

### **NAT Gateway vs. Instance-Level Egress**

Decision: Use a managed NAT Gateway to allow outbound internet access from private subnets.

Why: NAT Gateway is highly available, fully managed, automatically scales, and requires zero maintenance.

Trade-Off:

Pros: Managed, fault-tolerant, highly available by design.

Cons: Adds ~$30–$35/month per AZ plus data transfer costs.

Alternative: A NAT Instance (EC2 configured for IP masquerading) reduces cost but introduces operational overhead and a single point of failure. For production environments, NAT Gateway is the preferred choice.

### **RDS Multi-AZ**

Decision: Multi-AZ is disabled by default for cost and simplicity but easily enabled with a variable toggle.

Why: Many dev/staging or non-critical workloads don’t require HA. Multi-AZ is recommended for production to support automatic failover and high availability.

Trade-Off:

Pros: Enabling Multi-AZ improves durability, RPO/RTO, and fault tolerance.

Cons: It doubles database costs and introduces additional failover considerations.

### **Secrets Management**

Decision: No plaintext credentials or passwords are stored in Terraform code or state. All sensitive data is dynamically generated and stored in Secrets Manager and SSM Parameter Store.

Why: This enforces a secure-by-default pattern and aligns with best practices for credential lifecycle management.

Trade-Off:

Pros: Automatic rotation support, granular IAM policies, centralized credential storage.

Cons: Adds a small per-secret cost and requires careful IAM scoping to prevent accidental overexposure.

### **IAM Least-Privilege and SSM Over SSH**

Decision: Instances use an IAM role with the AmazonSSMManagedInstanceCore policy to allow Session Manager access instead of traditional SSH.

Why: Eliminates the need for key pairs, bastion hosts, and exposed port 22, reducing the risk of unauthorized access and key mismanagement.

Trade-Off:

Pros: Stronger security, centralized session logging, easier compliance.

Cons: Requires SSM agent installation and proper IAM configuration (both handled automatically here).

### **Application Load Balancer (ALB) vs. Network Load Balancer (NLB)***

Decision: Use an ALB for HTTP/Layer 7 routing instead of an NLB.

Why: ALB supports content-based routing, health checks, WAF integration, and easier certificate/TLS management — all critical for web apps.

Trade-Off:

Pros: Rich feature set, native TLS termination, better observability.

Cons: Slightly higher cost and latency compared to NLB, unnecessary for simple TCP workloads.

### **Auto Scaling Group with Target Tracking Policies**

Decision: ASG scales automatically based on CPU utilization and ALB request volume.

Why: This allows the stack to handle unpredictable traffic while maintaining cost efficiency.

Trade-Off:

Pros: Pay only for what you use, automatically scale under load, improve availability.

Cons: More complex than a fixed-size deployment, requires thoughtful health check and cooldown configuration.

### **S3 Buckets for Artifact Storage and ALB Access Logs**

Decision: S3 is used for two purposes — storing application artifacts (or uploads) and capturing ALB access logs with a 90-day lifecycle.

Why: S3 provides low-cost, durable, and scalable storage for both operational data and logs. Access logs are critical for troubleshooting, analytics, and auditing.

Trade-Off:

Pros: Centralized log storage, built-in lifecycle management, simple integration with analytics tools.

Cons: Slight added cost and potential log ingestion delay.

### **HTTP vs. HTTPS (TLS Termination)**

Decision: TLS termination is not implemented here by default, but ALB supports it and can be enabled by attaching an ACM certificate.

Why: For interview and demonstration purposes, HTTP simplifies setup and reduces boilerplate. In production, HTTPS with automatic redirect is mandatory.

Trade-Off:

Pros: Faster deployment, less setup complexity.

Cons: No in-transit encryption; should not be used in production.



---

**Author:** Jason Johnson
**License:** MIT
**Version:** 1.0.0

