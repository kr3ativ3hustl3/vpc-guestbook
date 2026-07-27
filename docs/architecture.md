# Architecture Notes

## Overview

A three-tier web application on AWS: load balancer tier (public),
application tier (private, Auto Scaling), and database tier (private,
isolated). Built to demonstrate core AWS networking and traditional
compute patterns, as a companion to the serverless Cloud Resume
Challenge project.

## Design decisions & tradeoffs

### Reusing project 1's Terraform state backend, with a separate key
Rather than provisioning a new S3 bucket + DynamoDB table for this
project's state, it reuses the existing backend from the Cloud Resume
Challenge with a different `key` (effectively a different file path
within the same bucket). This avoids repeating Phase 0 account-setup
work while keeping the two projects' state completely independent —
Terraform tracks state per-key, so there's no risk of one project's
`apply` affecting the other's resources.

### EC2 + Auto Scaling Group, not ECS/Fargate
Containers are arguably the more "modern" choice, but they add a real
abstraction layer over the underlying networking. Building the raw
EC2/ASG version first means actually working through what the ALB,
target groups, subnets, and security groups are doing without a
container orchestrator managing it — the fundamentals most interviews
ask about directly. A natural project 3 would be containerizing this
same app and migrating it to ECS Fargate, with the contrast between
the two approaches becoming its own talking point.

### SSM Session Manager, not a bastion host
The traditional pattern for reaching private-subnet instances is a
"bastion host" — a small EC2 instance in the public subnet with SSH
open, that you hop through. AWS's current recommendation is Session
Manager instead: no open inbound ports anywhere, no SSH key
management, and every session is logged in CloudTrail. It requires an
IAM role and the SSM agent (pre-installed on Amazon Linux 2023 AMIs)
rather than a security group rule, which is a worthwhile tradeoff.

### RDS in an isolated subnet with no route to the internet
The database subnet has no NAT gateway route and no internet gateway
route at all — only the application tier's security group is allowed
to reach it, on the database port only. This is stricter than many
tutorials, which put the database in a "private" subnet that still has
outbound internet access via NAT. For a database that never needs to
call out to the internet, that access is pure unnecessary attack
surface.

### Single NAT Gateway, not one per AZ
A NAT Gateway per AZ is the textbook highly-available answer, but each
one bills separately (~$32/mo each — doubling to ~$64/mo for two).
For a portfolio project not serving real production traffic, a single
NAT Gateway is a reasonable, explainable tradeoff: if that AZ has an
issue, private-subnet instances in the other AZ temporarily lose
outbound internet access, but their inbound availability through the
ALB is unaffected. Worth stating explicitly if asked in an interview
— it shows awareness of the tradeoff, not just a default choice.

### Security group created empty, ingress added later in a separate resource
The RDS security group is created in Phase 2 with zero inbound rules
— not even a placeholder. The rule allowing the app tier to connect
gets added as a separate `aws_security_group_rule` resource in
Phase 4, once the app tier's own security group actually exists to
reference. This means the database is genuinely unreachable from
anything between Phase 2 and Phase 4, which is the correct default
state for a resource with no legitimate reason to accept connections
yet — rather than opening it prematurely and tightening it later.

### Single-AZ RDS, not Multi-AZ
Multi-AZ RDS roughly doubles the cost by running a synchronously
replicated standby instance for automatic failover. That's the right
call for a database serving real users, but not justified for a
portfolio project's database, where an hour of downtime during a
rebuild has no real consequence. Worth being able to name this
tradeoff and explain when Multi-AZ *would* be justified.

### `skip_final_snapshot = true`
Normally risky — it means `terraform destroy` deletes the database
with no final backup. For a real production database this would be a
serious mistake. Here, the data is disposable test/demo content with
no real value to preserve, and skipping the snapshot avoids leftover
manual snapshots silently costing money after a `destroy`. Worth
stating this is a deliberate exception, not an oversight.

### App fetches its own code from GitHub at boot, not baked into the AMI or user-data
The launch template's startup script (`user_data.sh`) pulls
`app.py`/`requirements.txt`/`templates/index.html` directly from this
repo's `main` branch via `curl`, rather than embedding the app code
inside the Terraform-managed user-data itself, or building a custom
AMI with the code pre-installed. Tradeoff: a genuine dependency on the
GitHub repo being reachable and the code already being pushed before
instances boot (documented explicitly in the Phase 3 walkthrough,
since getting the order wrong silently breaks every new instance). In
exchange, a code change doesn't require rebuilding the launch
template or an AMI — a new instance simply pulls whatever's on `main`
at boot. A more production-grade version of this pattern would build
a versioned AMI (via Packer) or pull from a private artifact store
rather than a public GitHub raw URL.

### DB credentials via SSM Parameter Store, not embedded in user-data
Putting the database password directly in a launch template's
user-data means it's retrievable by anyone with permission to
describe that launch template or instance — a broader exposure
surface than necessary. Instead, the password lives in SSM Parameter
Store as a SecureString (encrypted with AWS's managed SSM key), and
the instance's IAM role is scoped to read only that one specific
parameter path — nothing else in SSM, no other AWS service.

### user_data.sh is a plain file, not run through Terraform's `templatefile()`
`templatefile()` requires escaping every bash `${VAR}` as `$${VAR}` to
stop Terraform from trying to interpret them as its own
interpolations — a fragile, error-prone pattern once a script has more
than a couple of variables (this exact class of bug caused real,
time-consuming problems in project 1's Terraform heredocs). Since
nothing in this script actually needs a value substituted in by
Terraform (the region is fetched dynamically from instance metadata,
the SSM parameter path is a fixed string), keeping it as a plain file
referenced via `file()` avoids the entire problem.

## Cost breakdown (expected)

| Service | Free tier | Expected usage | Expected cost |
|---|---|---|---|
| VPC, subnets, route tables | Always free | N/A | $0 |
| NAT Gateway | **Not free** | 1 gateway, low traffic | ~$32/mo + data |
| EC2 (t3.micro or t2.micro) | 750 hrs/mo (12mo) | 2 instances | $0 (within free tier, first 12mo) |
| Application Load Balancer | **Not free** | 1 ALB | ~$16-20/mo |
| RDS (db.t3.micro or db.t4g.micro) | 750 hrs/mo (12mo) | 1 instance | $0 (within free tier, first 12mo) |

**Important cost note, unlike project 1:** this architecture is
**not** free-tier-friendly the way the serverless project was. The
NAT Gateway and Application Load Balancer both bill hourly regardless
of traffic — expect roughly **$45-55/month** while this is running.
Plan to `terraform destroy` when not actively using it for demos or
interviews, and budget accordingly. This cost reality is itself worth
understanding and being able to explain — it's exactly the kind of
tradeoff a junior cloud engineer needs to reason about.

## Security posture (running list, updated per phase)

- Phase 0: Terraform state reuses project 1's encrypted, versioned,
  private S3 backend.
- Phase 1: database subnets have zero route to the internet (not even
  via NAT) — only reachable from inside the VPC. Public subnets host
  only the load balancer (added Phase 4); no compute lives there
  directly.
- Phase 2: RDS security group created with zero inbound rules — the
  database is unreachable from anything until Phase 4 explicitly
  grants the app tier access. Not publicly accessible; sits in
  subnets with no internet route at all.
- Phase 3: no SSH keys anywhere — admin access is via SSM Session
  Manager only, through an IAM role. DB password stored as an SSM
  SecureString, never in the launch template or user-data in
  plaintext; the instance role can read only that one parameter path.
  App tier security group also created with zero inbound rules.

## Observability posture (running list, updated per phase)

- (To be added in a later phase.)
