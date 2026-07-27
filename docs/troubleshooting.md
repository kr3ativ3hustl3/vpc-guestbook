# Troubleshooting Log

Real issues hit while building this project, with root cause and fix.
Format: symptom → cause → fix.

---

## Phase 0 — Project Scaffold & State

*(No issues — clean setup, reused project 1's backend without any
changes needed.)*

## Phase 1 — Networking

*(No issues — VPC, subnets, and NAT gateway applied cleanly on the
first attempt.)*

## Phase 2 — Database Tier

### `terraform apply` fails: "Cannot find version X.Y for postgres"
**Cause:** RDS periodically deprecates old minor versions. The
`engine_version` pinned in `modules/database/main.tf` may no longer
be available by the time you apply.
**Fix:** check what's currently valid before planning:
```bash
aws rds describe-db-engine-versions --engine postgres \
  --query "DBEngineVersions[?EngineVersion.starts_with(@, '16.')].EngineVersion" \
  --output table --profile cloud-resume
```
Update `engine_version` in the module to any version that's listed.

### `terraform apply` takes much longer than other phases
**Cause:** not a bug — RDS instance provisioning genuinely takes
5-10 minutes, much longer than VPC/subnet resources. This is normal
AWS behavior, not something wrong with the configuration.

### `terraform apply` fails: "InvalidParameterValue: ... Character sets beyond ASCII are not supported"
**Cause:** AWS security group descriptions only accept plain ASCII
characters. An em dash (`—`) in the description string — used
throughout this project's Terraform comments and docs for readability
— triggered this when it ended up inside an actual `description`
field rather than just a code comment.
**Fix:** replace any em dash or other non-ASCII character in security
group `description` fields with a plain hyphen (`-`). Comments in the
Terraform files themselves can still use em dashes freely; only
string values that AWS actually validates (like `description`) are
affected.

---

*(Phase 3+ troubleshooting entries will be added as we build them.)*
