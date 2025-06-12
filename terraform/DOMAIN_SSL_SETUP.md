# Domain & SSL Configuration Guide

## Overview
This guide will help you configure your custom domain `flomny.com` with SSL certificates using AWS Route53 and Certificate Manager (ACM).

## Prerequisites

### 1. Domain Registration
- Ensure `flomny.com` is registered and you have access to DNS management
- You'll need to update nameservers to point to AWS Route53

### 2. AWS Account Setup
- Ensure you have proper AWS credentials configured
- The terraform configuration will create all necessary resources

## Configuration Steps

### Step 1: Verify Domain Configuration
The terraform configuration has been updated with:
- `domain_name = "flomny.com"`
- `create_hosted_zone = false` (assuming you already have the domain)
- SSL certificates will be auto-generated using AWS ACM

### Step 2: Apply Terraform Configuration
```bash
# Navigate to terraform directory
cd terraform

# Initialize and plan the changes
terraform init
terraform plan

# Apply the configuration
terraform apply
```

### Step 3: Update Domain Nameservers
After terraform applies successfully, you'll need to update your domain registrar to use AWS Route53 nameservers.

**Get the nameservers:**
```bash
terraform output route53_nameservers
```

**Update your domain registrar** (wherever flomny.com is registered) to use these Route53 nameservers.

## What Will Be Created

### 1. Route53 Hosted Zone
- Main hosted zone for `flomny.com`
- DNS records for various subdomains

### 2. SSL Certificates (ACM)
- Wildcard certificate for `*.flomny.com`
- Subject Alternative Names (SANs) for:
  - `flomny.com` (root domain)
  - `app.flomny.com` (main application)
  - `bi.flomny.com` (BI/Metabase)
  - `api.flomny.com` (API endpoints)
  - `admin.flomny.com` (Admin interface)

### 3. DNS Records
- **A Records** pointing to your Application Load Balancer:
  - `flomny.com` → ALB
  - `app.flomny.com` → ALB
  - `bi.flomny.com` → ALB
  - `api.flomny.com` → ALB
  - `admin.flomny.com` → ALB

### 4. Health Checks
- Route53 health checks for application availability
- CloudWatch alarms for monitoring

### 5. Security Records
- SPF record for email security
- DMARC record for email authentication

## Load Balancer SSL Configuration

### HTTPS Enforcement
The load balancer is configured to:
- Accept HTTP traffic on port 80
- Redirect all HTTP traffic to HTTPS (port 443)
- Serve HTTPS traffic with the ACM certificate
- Use TLS 1.2 policy for security

### SSL Policy
Current SSL policy: `ELBSecurityPolicy-TLS-1-2-2017-01`
- Supports TLS 1.2 and higher
- Strong cipher suites only
- Perfect Forward Secrecy (PFS)

## Accessing Your Applications

Once configured, your applications will be available at:

- **Main Application**: `https://app.flomny.com`
- **BI Dashboard (Metabase)**: `https://bi.flomny.com`
- **API Endpoints**: `https://api.flomny.com`
- **Admin Interface**: `https://admin.flomny.com`
- **Root Domain**: `https://flomny.com` (redirects to app)

## SSL Certificate Validation

### Automatic DNS Validation
- ACM certificates use DNS validation
- Terraform automatically creates validation records
- Certificate issuance happens automatically

### Manual Steps (if needed)
If DNS validation doesn't complete automatically:
1. Check Route53 hosted zone for validation records
2. Ensure nameservers are properly updated
3. Wait up to 30 minutes for DNS propagation

## Security Best Practices

### 1. HTTPS Enforcement
- All HTTP traffic redirects to HTTPS
- Strong SSL/TLS configuration
- Perfect Forward Secrecy enabled

### 2. DNS Security
- SPF records configured
- DMARC policy enabled
- Health checks monitor availability

### 3. Access Control
- Load balancer security groups control access
- CloudWatch monitoring and alerting
- Access logs stored in S3

## Monitoring & Alerts

### Health Checks
- Application health monitoring via Route53
- CloudWatch alarms for failed health checks
- SNS notifications (if configured)

### SSL Certificate Monitoring
- ACM automatically renews certificates
- 60 days before expiration warnings
- Automatic certificate rotation

## Troubleshooting

### Common Issues

**1. Certificate Not Validating**
- Check nameservers are updated
- Verify DNS propagation: `dig flomny.com NS`
- Check validation records in Route53

**2. Domain Not Resolving**
- Verify nameserver configuration
- Check DNS propagation: `dig app.flomny.com`
- Ensure A records point to ALB

**3. HTTPS Not Working**
- Check certificate status in ACM
- Verify load balancer listener configuration
- Check security group rules

### Useful Commands

```bash
# Check DNS propagation
dig flomny.com NS
dig app.flomny.com A

# Test HTTPS connectivity
curl -I https://app.flomny.com

# Check certificate details
openssl s_client -connect app.flomny.com:443 -servername app.flomny.com

# Terraform outputs
terraform output
```

## Cost Optimization

### Free Tier Usage
- Route53 hosted zone: $0.50/month
- ACM certificates: Free
- DNS queries: First 1 billion/month free

### Monitoring Costs
- CloudWatch alarms: $0.10/alarm/month
- Route53 health checks: $0.50/health check/month

## Next Steps

1. **Apply Terraform Configuration**
   ```bash
   terraform apply
   ```

2. **Update Domain Nameservers**
   - Get nameservers from terraform output
   - Update at your domain registrar

3. **Verify SSL Certificate**
   - Wait for certificate validation (5-30 minutes)
   - Test HTTPS access to your applications

4. **Configure Application URLs**
   - Update application configurations to use HTTPS URLs
   - Update any hardcoded HTTP references

5. **Test All Endpoints**
   - Verify all subdomains work correctly
   - Test HTTP to HTTPS redirection
   - Confirm SSL certificate is valid

## Security Compliance

This configuration meets industry standards for:
- ✅ TLS 1.2+ encryption
- ✅ Strong cipher suites
- ✅ Perfect Forward Secrecy
- ✅ Automatic certificate renewal
- ✅ DNS-based email security (SPF/DMARC)
- ✅ Health monitoring and alerting
- ✅ Access logging and audit trails 