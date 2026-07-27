# Phase 1 — Networking

Creates: a VPC with public, private, and database subnets across 2
Availability Zones, an Internet Gateway, a NAT Gateway, and the route
tables connecting them.

**This is where the NAT Gateway cost (~$32/month) begins.** Nothing
before this phase cost anything.

---

## 1. Review the plan carefully before applying

```bash
cd ~/projects/vpc-guestbook/terraform
export AWS_PROFILE=cloud-resume
terraform plan
```

You should see **19 resources to add**:
- 1 VPC
- 1 Internet Gateway
- 6 subnets (2 public, 2 private, 2 database — one of each per AZ)
- 1 Elastic IP + 1 NAT Gateway
- 3 route tables (public, private, database)
- 6 route table associations

Nothing should show as "to change" or "to destroy."

## 2. Apply

```bash
terraform apply
```

Type `yes` to confirm. The NAT Gateway typically takes 1-2 minutes to
provision — this is normal, not stuck.

## 3. Verify

```bash
terraform output vpc_id
terraform output public_subnet_ids
terraform output private_subnet_ids
terraform output database_subnet_ids
```

All four should return real values (not empty).

Optionally, look at it in the AWS Console: **VPC → Your VPCs**, find
the one tagged `vpc-guestbook-vpc`, and click through to see the
subnets, route tables, and NAT Gateway all laid out.

---

## Verification checklist before moving to Phase 2

- [ ] `terraform apply` completed with 19 resources added, no errors
- [ ] All 4 `terraform output` values return real IDs
- [ ] You can see the VPC and its subnets in the AWS Console

Once confirmed, we'll move to **Phase 2: the database tier** — RDS
Postgres deployed into the isolated database subnets, with a security
group that (for now) allows nothing in — we'll open it up specifically
to the app tier in Phase 4 once that tier exists.

**Reminder:** this infrastructure is now costing money (~$32/month for
the NAT Gateway alone). If you need to pause for an extended period,
`terraform destroy` is safe — Phase 1 has no data to lose yet.
