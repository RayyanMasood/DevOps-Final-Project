# Testing Guide: Domain & Infrastructure

This guide explains how to safely test your infrastructure without breaking domain connectivity.

## The Problem

When using domains with Terraform:
- **Domain nameservers** must point to Route53 for SSL validation
- **Destroying infrastructure** creates new Route53 hosted zones with **different nameservers**
- **Breaking the domain connection** requires re-updating nameservers every time

## Solution Options

### Option 1: Lifecycle Protection (Current Setup)
✅ **Already Implemented** - The Route53 hosted zone has `prevent_destroy = true`

**Pros:**
- Simple, no changes needed
- Protects hosted zone from accidental destruction

**Cons:**
- Still prevents you from fully testing destroy/recreate cycles
- Must manually remove lifecycle protection to actually destroy

**Testing Process:**
```bash
# This will work - destroys everything except hosted zone
terraform destroy

# This will fail due to lifecycle protection
# terraform destroy  # Would error on hosted zone

# To fully destroy (for complete testing):
# 1. Remove lifecycle protection from main.tf
# 2. Run terraform destroy
# 3. Add lifecycle protection back
# 4. Recreate infrastructure
```

### Option 2: Separate Domain State (Recommended for Production)

✅ **Already Created** - See `terraform/environments/domain-only/`

**Pros:**
- Complete separation of domain and infrastructure
- Can destroy/recreate main infrastructure without affecting domain
- Professional approach used in production environments

**Cons:**
- Slightly more complex setup
- Need to manage two terraform states

**Setup Process:**
```bash
# 1. Create domain infrastructure (one-time)
cd terraform/environments/domain-only
terraform init
terraform apply

# 2. Get domain outputs for main infrastructure
terraform output

# 3. Update main terraform to use data sources instead of creating resources
```

### Option 3: Use Existing Hosted Zone

**Pros:**
- References existing infrastructure
- No destruction concerns

**Cons:**
- Requires manual hosted zone creation first

## Recommended Testing Workflow

### For Development/Testing:
1. **Use Option 1** (lifecycle protection) - already implemented
2. When you need to test full destroy/recreate:
   ```bash
   # Temporarily remove lifecycle protection
   # Edit main.tf - comment out the lifecycle block
   terraform apply  # Apply the change
   terraform destroy  # Now it can destroy everything
   terraform apply   # Recreate (will get new nameservers)
   # Update nameservers at domain registrar again
   ```

### For Production:
1. **Use Option 2** (separate domain state)
2. Create domain infrastructure once and never destroy it
3. Main application infrastructure can be destroyed/recreated freely

## Current Status

Your current setup uses **Option 1** with lifecycle protection. This means:

✅ **Safe to run:** `terraform destroy` (will preserve hosted zone)
✅ **Safe to run:** `terraform apply` (will recreate everything except domain)
❌ **Cannot run:** Full destroy without manual intervention

## Next Steps for You

Since you're currently in the middle of setup:

1. **Complete the current deployment:**
   ```bash
   # Update nameservers at your domain registrar first
   # Wait 5-15 minutes for propagation
   terraform apply -auto-approve
   ```

2. **For future testing:**
   - Use the lifecycle protection (already in place)
   - Or migrate to separate domain state when you have time

## Migration to Separate Domain State (Optional)

If you want to use the separate domain approach later:

```bash
# 1. Import existing resources to domain-only state
cd terraform/environments/domain-only
terraform import aws_route53_zone.main Z1234567890ABC  # Use your zone ID
terraform import aws_acm_certificate.main arn:aws:acm:...  # Use your cert ARN

# 2. Update main terraform to use data sources
# 3. Remove domain resources from main state
terraform state rm aws_route53_zone.main
terraform state rm aws_acm_certificate.main
# etc.
```

## Summary

- **Right now:** Use lifecycle protection (already implemented)
- **Complete your deployment:** Update nameservers → wait → terraform apply
- **Future testing:** Main infrastructure can be destroyed/recreated safely
- **Full destroy testing:** Requires temporary lifecycle protection removal 