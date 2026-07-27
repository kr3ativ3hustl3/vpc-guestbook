# Phase 0 — Project Scaffold & Terraform State

No new AWS account setup needed — this reuses the state backend and
IAM credentials from the Cloud Resume Challenge project.

---

## ⚠️ Important cost note before we go further

Unlike project 1, **this architecture is not free-tier-friendly.**
Two pieces bill by the hour regardless of traffic:

- **NAT Gateway:** ~$32/month + data processing charges
- **Application Load Balancer:** ~$16-20/month

Combined with free-tier EC2 and RDS, expect roughly **$45-55/month**
while this infrastructure exists. Plan to run `terraform destroy` when
you're not actively demoing or working on it, and set a budget alert
(similar to Phase 0 of project 1) if you haven't already. This is a
real, worthwhile tradeoff to understand and be able to explain — not
a mistake, just a different cost model than serverless.

---

## 1. Get the project onto your machine

You'll receive this as a zip, same as project 1. Unzip it somewhere
alongside your Cloud Resume Challenge folder — NOT inside it:

```bash
unzip -o ~/Downloads/vpc-guestbook.zip -d ~/projects
cd ~/projects/vpc-guestbook/terraform
```

## 2. Set up tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
cat terraform.tfvars
```

Default values should work fine as-is for now (`aws_region =
"us-east-1"`, `project_name = "vpc-guestbook"`).

## 3. Init

```bash
export AWS_PROFILE=cloud-resume
terraform init
```

This connects to the **same S3 bucket** as project 1, but a different
state file path (`vpc-guestbook/terraform.tfstate` instead of
`global/terraform.tfstate`), so the two projects' infrastructure can
never collide.

You should see `Terraform has been successfully initialized!`. Since
there are no resources defined yet (Phase 1 adds the first ones),
`terraform plan` at this point would show "No changes" — that's
expected, nothing to verify beyond a clean init.

---

## Verification checklist before moving to Phase 1

- [ ] `terraform init` completes with no errors
- [ ] Budget alert exists or you're comfortable monitoring costs manually
- [ ] You understand this project costs real money while it exists (see cost note above)

Once confirmed, we'll move to **Phase 1: networking** — the VPC,
public/private/database subnets across two Availability Zones, NAT
gateway, and route tables.
