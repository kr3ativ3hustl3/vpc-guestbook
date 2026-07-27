# Phase 3 — Compute Tier

Creates: SSM Parameter Store entries for DB credentials, an IAM role
(SSM Session Manager + read access to those specific parameters only),
a security group (still no inbound rules — Phase 4 adds those), a
launch template, and an Auto Scaling Group running the Flask
guestbook app.

**The app will NOT be reachable or fully working at the end of this
phase** — there's no load balancer yet (Phase 4), and the security
group still blocks all inbound traffic, including from anything.
That's expected. This phase proves the compute + IAM + secrets pieces
work; Phase 4 connects them to the outside world.

---

## ⚠️ Critical ordering: push app code to GitHub FIRST

The EC2 instances fetch `app.py`, `requirements.txt`, and
`templates/index.html` directly from this repo's `main` branch on
GitHub when they boot (see `terraform/modules/compute/user_data.sh`).
If you `terraform apply` before pushing the `app/` folder, instances
will boot with a failed startup script (404 on the `curl` calls) and
never run the app.

```bash
cd ~/projects/vpc-guestbook
git add app/
git commit -m "Add Flask guestbook app"
git push
```

Confirm it's really there before continuing:

```bash
curl -I https://raw.githubusercontent.com/kr3ativ3hustl3/vpc-guestbook/main/app/guestbook/app.py
```

Should return `HTTP/2 200`, not 404.

## 1. Plan and apply

```bash
cd terraform
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect roughly **13 resources to add**: 5 SSM parameters, an IAM role
+ policy attachment + inline policy + instance profile, a security
group, a launch template, and an Auto Scaling Group.

```bash
terraform apply
```

This should be noticeably faster than Phase 2's RDS wait — a minute
or two.

## 2. Verify instances are actually running the app

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names vpc-guestbook-asg \
  --profile cloud-resume \
  --query "AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]" \
  --output table
```

You should see 2 instances, both `Healthy` and `InService`. (Give it
a couple minutes after apply — instances need time to boot and run
the startup script.)

## 3. Connect via SSM Session Manager (no SSH!) to check the app directly

Pick one instance ID from the output above:

```bash
aws ssm start-session --target <instance-id> --profile cloud-resume
```

This opens an interactive shell on the instance — with no SSH key,
no open port 22, no bastion host. Once connected:

```bash
sudo systemctl status guestbook
curl -s localhost:8080/health
```

The service should show `active (running)`, and the health check
should return `OK`.

Try the real page too — it should render, but show a friendly
"Couldn't reach the database" message, since the RDS security group
doesn't allow this app tier in yet (that's Phase 4):

```bash
curl -s localhost:8080/ | head -30
```

Exit the session with `exit` when done.

---

## Verification checklist before moving to Phase 4

- [ ] App code pushed to GitHub `main` BEFORE applying this phase
- [ ] `terraform apply` completed with no errors
- [ ] Both ASG instances show `Healthy` / `InService`
- [ ] SSM Session Manager connects successfully (no SSH needed)
- [ ] `guestbook` systemd service is `active (running)` on the instance
- [ ] `/health` returns `OK`; `/` renders with a graceful DB-error message (expected at this point)

Once confirmed, we'll move to **Phase 4: load balancer + security
groups** — the Application Load Balancer, target group, and the
specific security group rules that finally let the ALB reach the app
tier and the app tier reach RDS. That's when the site actually becomes
reachable and fully functional.
