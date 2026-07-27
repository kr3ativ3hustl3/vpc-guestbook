# VPC Guestbook — Three-Tier AWS Architecture

A small guestbook web app deployed on a real three-tier AWS
architecture — VPC with public/private/database subnets across 2
Availability Zones, an Application Load Balancer, an Auto Scaling
Group of EC2 instances, and RDS Postgres — built entirely in
Terraform, with CI/CD via GitHub Actions.

This is project 2 in a portfolio series. Where the
[Cloud Resume Challenge](https://github.com/kr3ativ3hustl3/cloud-resume-challenge)
(project 1) demonstrates serverless architecture, this project
demonstrates core AWS networking and traditional compute — VPCs,
subnets, security groups, load balancing, and Auto Scaling — the
things most cloud engineering interviews ask about directly.

**Status:** ✅ Complete (Phases 0-6).

## Architecture

```
                         Internet
                            │
                    ┌───────▼────────┐
                    │  Application    │   (public subnets, 2 AZs)
                    │  Load Balancer  │
                    └───────┬────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
      ┌───────▼───────┐           ┌───────▼───────┐
      │  EC2 instance  │           │  EC2 instance  │   (private subnets,
      │  (Auto Scaling)│           │  (Auto Scaling)│    2 AZs)
      └───────┬───────┘           └───────┬───────┘
              │                           │
              └─────────────┬─────────────┘
                             │
                     ┌───────▼────────┐
                     │  RDS Postgres   │   (isolated private subnet,
                     │  (single-AZ,     │    no internet access)
                     │   free tier)     │
                     └────────────────┘
```

Admin access via AWS Systems Manager Session Manager — no SSH keys,
no bastion host, no open port 22 anywhere. Full reasoning behind every
architectural decision in [`docs/architecture.md`](docs/architecture.md).

## Tech stack

- **Networking:** VPC, public/private/DB subnets across 2 AZs, NAT gateway, route tables
- **Compute:** EC2 + Auto Scaling Group, Flask guestbook app, no SSH
- **Load balancing:** Application Load Balancer, target group, health checks
- **Database:** RDS Postgres, isolated subnet, security-group-scoped access only
- **Secrets:** SSM Parameter Store (SecureString), never in code or user-data
- **IaC:** Terraform, modular (networking, database, compute, load-balancer, github-cicd)
- **CI/CD:** GitHub Actions via OIDC, rolling deploys via ASG instance refresh
- **Admin access:** SSM Session Manager (no SSH)

## What this project actually demonstrates

- **Real least-privilege IAM at every tier** — the EC2 role can read
  exactly one SSM parameter path and nothing else; the CI/CD role can
  trigger a refresh on exactly one Auto Scaling Group.
- **Security groups added incrementally, never pre-opened** — RDS and
  the app tier were both created with zero inbound rules, only gaining
  access when the specific resource on the other end actually existed
  to reference (Phase 4), not before.
- **A genuinely resolved circular dependency** — connecting the Auto
  Scaling Group to the load balancer's target group would naturally
  create a circular reference between two Terraform modules;
  `aws_autoscaling_attachment` breaks that cleanly. Documented in
  detail in [`docs/architecture.md`](docs/architecture.md).
- **Real cost awareness** — unlike a serverless project, this
  architecture bills ~$45-55/month regardless of traffic (NAT Gateway
  + ALB), and that tradeoff is documented, not glossed over.
- **Cross-project debugging pattern reuse** — a GitHub OIDC pitfall
  discovered the hard way in project 1 (the subject-claim format
  issue) was applied proactively here from the start, instead of
  being rediscovered.

## Cost

Roughly **$45-55/month** while running (NAT Gateway ~$32/mo + ALB
~$16-20/mo are the two pieces that bill regardless of traffic; EC2 and
RDS are free-tier eligible for 12 months). Run `terraform destroy`
between active work sessions to avoid ongoing charges — full teardown
and rebuild takes about 15-20 minutes end to end (RDS is the slow
part). Full breakdown in [`docs/architecture.md`](docs/architecture.md).

## Repo structure

```
vpc-guestbook/
├── docs/                    # architecture decisions, troubleshooting log
├── app/guestbook/           # Flask guestbook app source
├── terraform/
│   └── modules/             # networking, database, compute, load-balancer, github-cicd
└── .github/workflows/       # CI/CD pipelines
```

## Build log (phases)

- [x] **Phase 0** — Project scaffold, Terraform state (reusing project 1's backend)
- [x] **Phase 1** — Networking: VPC, subnets, NAT gateway, route tables
- [x] **Phase 2** — Database: RDS Postgres in isolated subnet
- [x] **Phase 3** — Compute: launch template, Auto Scaling Group, guestbook app
- [x] **Phase 4** — Load balancer + security groups (least-privilege between tiers)
- [x] **Phase 5** — CI/CD via GitHub Actions + OIDC (rolling ASG deploys)
- [x] **Phase 6** — Final polish & write-up (this README)

Detailed walkthroughs for each phase live alongside the Terraform
code: `terraform/PHASE0-setup.md` through `PHASE5-cicd.md`.

## Troubleshooting

Every real issue hit during the build — with root cause and fix — is
logged in [`docs/troubleshooting.md`](docs/troubleshooting.md),
including an AWS-specific gotcha (security group descriptions must be
plain ASCII) and a macOS-specific one (the SSM Session Manager plugin
requiring a newer macOS than this project's dev machine had, solved by
using the browser-based Session Manager instead).

## Security notes

- No SSH keys anywhere — all admin access via SSM Session Manager
- Database password stored as an SSM SecureString, never in code,
  user-data, or version control
- Every tier's security group accepts traffic ONLY from the specific
  tier in front of it — no tier is reachable except through the one
  meant to reach it
- CI/CD authenticates via OIDC with short-lived tokens, scoped to
  exactly one Auto Scaling Group's refresh action
- Full posture, updated per phase, in [`docs/architecture.md`](docs/architecture.md)
