# Phase 5 — CI/CD (Optional Refinement)

Creates: an IAM role GitHub Actions can assume via OIDC (reusing the
account's existing OIDC provider from the Cloud Resume Challenge
project), scoped to trigger a rolling instance refresh on exactly this
project's Auto Scaling Group — nothing else.

How deploys work here: since instances pull `app.py` fresh from
GitHub's `main` branch at boot (see Phase 3), "deploying a change"
just means replacing running instances with new ones that re-run that
same startup script. `aws autoscaling start-instance-refresh` does
exactly that, one instance at a time, keeping at least half the fleet
healthy throughout (`MinHealthyPercentage: 50`).

---

## 1. Add your GitHub repo and apply

```bash
cd ~/projects/vpc-guestbook/terraform
echo 'github_repo = "kr3ativ3hustl3/vpc-guestbook"' >> terraform.tfvars
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect **3 resources to add**: the IAM role, its inline policy, and
nothing else — this module deliberately does NOT create a new OIDC
provider (see the module comment for why; it would collide with the
one already created in the Cloud Resume Challenge project, in this
same AWS account).

```bash
terraform apply
```

```bash
terraform output github_actions_role_arn
```

Copy that ARN.

## 2. Add the GitHub secret

Go to your repo on GitHub → **Settings → Secrets and variables →
Actions → New repository secret**:

| Secret name | Value |
|---|---|
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | the ARN from step 1 |

## 3. Push the workflow files

```bash
cd ~/projects/vpc-guestbook
git add .github terraform
git commit -m "Add CI/CD: rolling deploy via GitHub Actions + OIDC"
git push
```

## 4. Test it

Make a small, harmless change to the app to trigger a deploy:

```bash
echo "# CI/CD test" >> app/guestbook/app.py
git add app/guestbook/app.py
git commit -m "Test CI/CD deploy"
git push
```

Go to your repo's **Actions** tab. You should see "Deploy App"
running. It can take several minutes — instance refreshes are
deliberately gradual, replacing one instance at a time rather than all
at once, to avoid a moment where the whole fleet is unhealthy.

Verify it worked once it finishes:

```bash
aws autoscaling describe-instance-refreshes --auto-scaling-group-name vpc-guestbook-asg --profile cloud-resume --query "InstanceRefreshes[0].[Status,PercentageComplete]"
```

Should show `["Successful", 100]`.

---

## Verification checklist

- [ ] `terraform apply` succeeded (3 resources, no OIDC provider conflict)
- [ ] GitHub secret is set
- [ ] A push to `app/**` triggers "Deploy App" and it completes successfully
- [ ] A push to `terraform/**` triggers "Terraform Validate" and it passes

Once confirmed, we'll move to **Phase 6: final write-up** — polishing
the README into a finished portfolio piece.
