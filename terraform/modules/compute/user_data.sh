#!/bin/bash
# EC2 startup script for the guestbook app instances.
#
# Deliberately a plain, non-templated file (not run through
# Terraform's templatefile()) — that function requires escaping every
# bash ${VAR} as $${VAR} to avoid Terraform trying to interpret them
# as its own variables, which is fragile and easy to get wrong. Since
# nothing here actually needs a Terraform-side value substituted in
# (the region is fetched dynamically, the parameter path is a fixed
# string), a plain file avoids that whole class of bug.
set -euo pipefail

# Get this instance's region dynamically via IMDSv2 (the current,
# more secure way to query instance metadata — IMDSv1 is being
# phased out across AWS).
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

dnf update -y
dnf install -y python3 python3-pip git

mkdir -p /opt/guestbook/templates
cd /opt/guestbook

# Pull the app straight from the public GitHub repo. Requires the app
# code to already be pushed to `main` before this instance boots.
curl -fsSL -o app.py https://raw.githubusercontent.com/kr3ativ3hustl3/vpc-guestbook/main/app/guestbook/app.py
curl -fsSL -o requirements.txt https://raw.githubusercontent.com/kr3ativ3hustl3/vpc-guestbook/main/app/guestbook/requirements.txt
curl -fsSL -o templates/index.html https://raw.githubusercontent.com/kr3ativ3hustl3/vpc-guestbook/main/app/guestbook/templates/index.html

pip3 install -r requirements.txt

# Fetch DB connection details from SSM Parameter Store — all five
# parameters are now SecureString (encrypted at rest with no extra
# cost, previously only the password was), so all five need
# --with-decryption. This requires the IAM role attached to this
# instance to have ssm:GetParameter permission, scoped to exactly
# this parameter path.
DB_HOST=$(aws ssm get-parameter --name "/vpc-guestbook/db/host" --with-decryption --region "$REGION" --query Parameter.Value --output text)
DB_PORT=$(aws ssm get-parameter --name "/vpc-guestbook/db/port" --with-decryption --region "$REGION" --query Parameter.Value --output text)
DB_NAME=$(aws ssm get-parameter --name "/vpc-guestbook/db/name" --with-decryption --region "$REGION" --query Parameter.Value --output text)
DB_USER=$(aws ssm get-parameter --name "/vpc-guestbook/db/username" --with-decryption --region "$REGION" --query Parameter.Value --output text)
DB_PASSWORD=$(aws ssm get-parameter --name "/vpc-guestbook/db/password" --with-decryption --region "$REGION" --query Parameter.Value --output text)

cat > /opt/guestbook/.env << ENVEOF
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
ENVEOF

chmod 600 /opt/guestbook/.env

cat > /etc/systemd/system/guestbook.service << 'SVCEOF'
[Unit]
Description=Guestbook Flask App
After=network.target

[Service]
EnvironmentFile=/opt/guestbook/.env
WorkingDirectory=/opt/guestbook
ExecStart=/usr/local/bin/gunicorn -w 2 -b 0.0.0.0:8080 app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable guestbook
systemctl start guestbook
