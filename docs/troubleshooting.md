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

## Phase 3 — Compute Tier

### Session Manager plugin fails: "Symbol not found: _SecTrustCopyCertificateChain"
**Cause:** the same class of problem hit repeatedly with other tools
across these projects (AWS CLI v2, several Terraform provider plugins)
— the `session-manager-plugin` binary is compiled targeting a newer
macOS (12.0) than an older Mac may be running (e.g. 10.14 Mojave), so
a required system symbol is missing and the binary can't even start.
**Fix:** skip the local plugin entirely and use the browser-based
Session Manager instead: AWS Console → Systems Manager → Session
Manager → Start session → pick the instance. This runs entirely
server-side/in-browser and needs no local binary at all, sidestepping
the OS compatibility problem completely.

## Phase 4 — Load Balancer & Security Groups

### Targets show "unhealthy" right after apply
**Cause:** normal — the target group's health check needs a couple of
passing checks in a row (`healthy_threshold = 2`, `interval = 30s`)
before marking a target healthy, and the ASG's `health_check_grace_
period` gives new instances 300 seconds before being judged at all.
**Fix:** just wait 1-3 minutes and re-check. If it's still unhealthy
after 5+ minutes, check the target group's health check settings
match the app (`path = /health`, port 8080) and that the security
group rule allowing ALB → app traffic actually applied.

### Site loads over HTTP but there's no HTTPS
**Cause:** this project's ALB listener is HTTP-only (port 80) — there
was no domain name provisioned for this project to get an ACM
certificate for, unlike the Cloud Resume Challenge project. Adding
HTTPS would need a registered domain, an ACM certificate, and a second
listener on port 443.
**Fix:** not a bug, a scope decision. Worth mentioning as a natural
next enhancement if asked.

---

*(Further refinements will be added as they come up.)*
