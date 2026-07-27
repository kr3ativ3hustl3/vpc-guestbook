# Phase 2 — Database Tier

Creates: a DB subnet group, an RDS Postgres instance in the isolated
database subnets, and a security group that (deliberately) allows no
inbound traffic yet.

---

## 1. Set a real database password

```bash
cd ~/projects/vpc-guestbook/terraform
```

Edit `terraform.tfvars` (open with `nano terraform.tfvars`) and replace
the placeholder password with a real, strong one:

```
db_password = "something-long-and-random-not-a-dictionary-word"
```

RDS requires at least 8 characters. Save and exit.

## 2. Check the Postgres version is still valid

RDS periodically deprecates old minor versions. Before planning,
confirm `16.4` (or whatever's currently in `modules/database/main.tf`)
is still available in your region:

```bash
aws rds describe-db-engine-versions \
  --engine postgres \
  --query "DBEngineVersions[?EngineVersion.starts_with(@, '16.')].EngineVersion" \
  --output table \
  --profile cloud-resume
```

If `16.4` isn't in that list, pick any version that is, and update it
in `modules/database/main.tf` (`engine_version = "..."`) before
continuing.

## 3. Plan and apply

```bash
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

You should see **4 resources to add**: the DB subnet group, the
security group, and the RDS instance itself (the `terraform {}`
config block doesn't count as a real resource). Phase 1's networking
should show no changes.

```bash
terraform apply
```

**This takes longer than anything so far — expect 5-10 minutes.**
RDS instance creation is genuinely slow; this is normal, not stuck.

## 4. Verify

```bash
terraform output db_endpoint
```

Should return a real hostname like
`vpc-guestbook-db.xxxxxxxxxx.us-east-1.rds.amazonaws.com:5432`.

At this point, nothing can actually connect to it yet — the security
group has zero inbound rules, on purpose. That's correct, not a bug;
Phase 4 adds the rule allowing the app tier in, once that tier exists
to reference.

---

## Verification checklist before moving to Phase 3

- [ ] `terraform apply` completed with no errors (allow extra time for RDS)
- [ ] `terraform output db_endpoint` returns a real hostname
- [ ] You can see the RDS instance in the AWS Console (RDS → Databases)
      showing status "Available"

Once confirmed, we'll move to **Phase 3: the compute tier** — a launch
template, Auto Scaling Group, and the actual Flask guestbook app,
deployed into the private subnets.

**Cost reminder:** RDS (db.t3.micro) is free-tier eligible for your
first 12 months on this AWS account. Combined with the NAT Gateway
from Phase 1, you're still at roughly ~$32/month total so far.
