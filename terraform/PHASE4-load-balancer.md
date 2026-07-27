# Phase 4 — Load Balancer & Security Group Rules

Creates: the Application Load Balancer, its target group and listener,
the attachment connecting Phase 3's Auto Scaling Group to that target
group, and the two security group rules deferred since Phase 2/3 —
ALB → app tier, and app tier → RDS.

**This is the payoff phase — the site becomes reachable and fully
functional (database included) for the first time.**

---

## 1. Plan and apply

```bash
cd ~/projects/vpc-guestbook/terraform
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect:
- **7 resources to add**: ALB security group, the ALB itself, target
  group, listener, the ASG attachment, and 2 security group rules
- **1 resource to change**: the Auto Scaling Group (switching from
  `EC2` to `ELB` health checks, and adding the grace period) — this is
  expected, not an error

```bash
terraform apply
```

Give it a few minutes — ALB provisioning and the first round of
target health checks both take a little time.

## 2. Get the site URL

```bash
terraform output site_url
```

Open that URL in a browser. **It can take 1-3 minutes after apply
finishes** for targets to pass their first health check and register
as healthy — if you see a 503 immediately after apply, that's normal;
wait and refresh.

## 3. Verify target health directly

```bash
terraform output -raw autoscaling_group_name
```

Then, using that name, find the target group and check target health
in the console: **EC2 → Target Groups → vpc-guestbook-tg → Targets
tab** — both instances should show `healthy`.

Or via CLI:

```bash
aws elbv2 describe-target-groups --names vpc-guestbook-tg --profile cloud-resume --query "TargetGroups[0].TargetGroupArn" --output text
```

Copy that ARN, then:

```bash
aws elbv2 describe-target-health --target-group-arn <arn-from-above> --profile cloud-resume
```

Look for `"State": "healthy"` on both targets.

## 4. Actually use the app

Open the site URL, fill in the guestbook form (name + message), and
submit. Refresh — your entry should now appear, proving the full
chain works: browser → ALB → EC2 → RDS.

---

## Verification checklist — project complete

- [ ] `terraform apply` completed with no errors
- [ ] `terraform output site_url` returns a real ALB DNS name
- [ ] Visiting that URL loads the guestbook page (allow a few minutes
      for targets to register as healthy)
- [ ] Both targets show `healthy` in the target group
- [ ] Submitting the guestbook form actually saves and displays an entry

Once confirmed, this is functionally a complete three-tier
architecture. **Phase 5 (SSM/CI-CD polish) and Phase 6 (final write-up)
are optional refinements from here** — the core architecture goal of
this project is achieved at this point.

**Cost reminder:** with the ALB now added, you're at roughly
**$45-55/month total** (NAT Gateway + ALB; EC2 and RDS still free-tier
eligible for 12 months). If you're done actively working on this for
a while, `terraform destroy` is the right move to stop the billing —
just re-apply everything from Phase 1 forward when you want it back
(the state file remembers everything, so it's a clean rebuild).
