# VPC Guestbook — Three-Tier AWS Architecture

A small guestbook web app (visitors leave a name + message) deployed
on a real three-tier AWS architecture — VPC with public/private
subnets, an Application Load Balancer, an Auto Scaling Group of EC2
instances, and RDS Postgres — built entirely in Terraform.

This is project 2 in a portfolio series. Where the
[Cloud Resume Challenge](https://github.com/kr3ativ3hustl3/cloud-resume-challenge)
(project 1) demonstrates serverless architecture, this project
demonstrates core AWS networking and traditional compute — the pieces
most cloud engineering interviews ask about directly: VPCs, subnets,
security groups, load balancing, and Auto Scaling.

**Status:** 🚧 In progress — Phase 2 of 6 complete (RDS Postgres in
isolated subnets). Reminder: RDS is free-tier eligible for 12 months;
NAT Gateway from Phase 1 continues billing ~$32/month — see cost note
in docs/architecture.md.

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
no bastion host, no open port 22 to the internet.

## Tech stack

- **Networking:** VPC, public/private/DB subnets across 2 AZs, NAT gateway, route tables
- **Compute:** EC2 + Auto Scaling Group (Python/Flask guestbook app)
- **Load balancing:** Application Load Balancer
- **Database:** RDS Postgres, isolated subnet
- **IaC:** Terraform, reusing the state backend from project 1 with a separate state key
- **Admin access:** SSM Session Manager (no SSH)

## Repo structure

```
vpc-guestbook/
├── docs/                    # architecture notes, troubleshooting log
├── app/guestbook/           # Flask guestbook app source
└── terraform/
    └── modules/             # networking, database, compute, load-balancer
```

## Build log (phases)

- [x] **Phase 0** — Project scaffold, Terraform state (reusing project 1's backend)
- [x] **Phase 1** — Networking: VPC, subnets, NAT gateway, route tables. See [`terraform/PHASE1-networking.md`](terraform/PHASE1-networking.md).
- [x] **Phase 2** — Database: RDS Postgres in isolated subnet. See [`terraform/PHASE2-database.md`](terraform/PHASE2-database.md).
- [ ] **Phase 3** — Compute: launch template, Auto Scaling Group, guestbook app
- [ ] **Phase 4** — Load balancer + security groups (least-privilege between tiers)
- [ ] **Phase 5** — SSM Session Manager access, CI/CD
- [ ] **Phase 6** — Final polish & write-up

## Troubleshooting

Real issues hit while building this are logged in
[`docs/troubleshooting.md`](docs/troubleshooting.md).
