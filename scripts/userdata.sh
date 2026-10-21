#!/bin/bash
set -euo pipefail

# Keep the bootstrap output available for troubleshooting.
exec > >(tee -a /var/log/capstone-bootstrap.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

capstone_project_dir=/home/ubuntu/Ondia_aws_capstone
capstone_region=us-east-1
capstone_bucket=yazen-capstone-assets-20261019

# Install the tools and libraries required by the application.
apt-get update
apt-get -o DPkg::Lock::Timeout=300 install -y \
    git curl ca-certificates awscli \
    python3-venv python3-dev \
    build-essential pkg-config default-libmysqlclient-dev

# Download the project from the public GitHub repository.
git clone --depth 1 --branch main \
    https://github.com/yazenAlbu/aws-django-blog-capstone.git \
    "$capstone_project_dir"

# Install the Python packages in a separate virtual environment.
python3 -m venv "$capstone_project_dir/.venv"
"$capstone_project_dir/.venv/bin/pip" install \
    -r "$capstone_project_dir/requirements.txt" \
    gunicorn==26.2.0

# Read the Django secret key from Parameter Store.
capstone_secret_key=$(aws ssm get-parameter \
    --name /yazen/capstone/secret_key \
    --with-decryption \
    --query 'Parameter.Value' \
    --output text \
    --region "$capstone_region")

install -m 600 /dev/null "$capstone_project_dir/src/.env"
printf 'SECRET_KEY=%s\n' "$capstone_secret_key" \
    > "$capstone_project_dir/src/.env"
unset capstone_secret_key

chown -R ubuntu:ubuntu "$capstone_project_dir"
cd "$capstone_project_dir/src"

# Apply the committed database migrations and upload static files.
runuser -u ubuntu -- "$capstone_project_dir/.venv/bin/python" \
    manage.py migrate --noinput

runuser -u ubuntu -- "$capstone_project_dir/.venv/bin/python" \
    manage.py collectstatic --noinput

# Upload the default profile and post images.
aws s3 cp "$capstone_project_dir/src/media_root/avatar.png" \
    "s3://$capstone_bucket/media/avatar.png" \
    --acl public-read --region "$capstone_region"

aws s3 cp "$capstone_project_dir/src/media_root/django.jpg" \
    "s3://$capstone_bucket/media/django.jpg" \
    --acl public-read --region "$capstone_region"

# Run Django on port 80 and start it automatically after a reboot.
cat > /etc/systemd/system/capstone-blog.service <<'SERVICE'
[Unit]
Description=Capstone Django Blog
Wants=network-online.target
After=network-online.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/Ondia_aws_capstone/src
Environment=AWS_DEFAULT_REGION=us-east-1
Environment=PYTHONUNBUFFERED=1
ExecStart=/home/ubuntu/Ondia_aws_capstone/.venv/bin/gunicorn cblog.wsgi:application \
    --bind 0.0.0.0:80 \
    --workers 2 \
    --timeout 120 \
    --forwarded-allow-ips=10.0.1.0/24,10.0.2.0/24 \
    --access-logfile - \
    --error-logfile -
AmbientCapabilities=CAP_NET_BIND_SERVICE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now capstone-blog

# Confirm that the application responds locally.
curl --fail --silent --show-error \
    --retry 10 --retry-connrefused --retry-delay 3 --max-time 10 \
    http://127.0.0.1/ > /dev/null

echo "Capstone bootstrap finished successfully."

