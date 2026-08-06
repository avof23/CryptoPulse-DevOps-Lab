#!/bin/bash
set -euxo pipefail

APP_DIR="/opt/cryptopulse"
GIT_REPO_URL="https://github.com/avof23/CryptoPulse-DevOps-Lab.git"


SSM_DB_NAME_PARAM="/${project}/${env}/vpc/databases/mz_rds/rds_dbname"
SSM_DB_USER_PARAM="/${project}/${env}/vpc/databases/mz_rds/rds_user"
SSM_DB_SECRET_ARN_PARAM="/${project}/${env}/vpc/databases/mz_rds/secret_arn"
AWS_REGION="${region}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3 python3-venv python3-pip git awscli build-essential libpq-dev

# Git
mkdir -p /tmp/git_app
cd /tmp/git_app

git init
git config core.sparseCheckout true
git remote add origin "${GIT_REPO_URL}"

cat <<EOF >> .git/info/sparse-checkout
requirements.txt
app/
EOF

git pull --depth 1 origin main

mkdir -p ${APP_DIR}
cp -r /tmp/git_app/* ${APP_DIR}/
cd /
rm -rf /tmp/git_app

python3 -m venv ${APP_DIR}/venv
source ${APP_DIR}/venv/bin/activate
pip install --upgrade pip
pip install -r ${APP_DIR}/requirements.txt


DB_NAME=$(aws ssm get-parameter --name "${SSM_DB_NAME_PARAM}" --region "${AWS_REGION}" --query "Parameter.Value" --output text)
DB_USER=$(aws ssm get-parameter --name "${SSM_DB_USER_PARAM}" --region "${AWS_REGION}" --query "Parameter.Value" --output text)
DB_SECRET_ARN=$(aws ssm get-parameter --name "${SSM_DB_SECRET_ARN_PARAM}" --region "${AWS_REGION}" --query "Parameter.Value" --output text)

SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "${DB_SECRET_ARN}" --query "SecretString" --output text --region "${AWS_REGION}")
DB_PASS=$(echo "${SECRET_JSON}" | jq -r .password)

# Generate .env
cat <<EOF > ${APP_DIR}/.env
DB_HOST=db.${project}.internal
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
EOF

chmod 600 ${APP_DIR}/.env
mkdir -p ${APP_DIR}/logs
useradd -r -s /bin/false appuser || true
chown -R appuser:appuser ${APP_DIR}

# Systemd Service for Gunicorn
cat <<EOF > /etc/systemd/system/cryptopulse.service
[Unit]
Description=Gunicorn Application Server for CryptoPulse
After=network.target

[Service]
User=appuser
Group=appuser
WorkingDirectory=${APP_DIR}
Environment="PATH=${APP_DIR}/venv/bin"
EnvironmentFile=${APP_DIR}/.env

ExecStart=${APP_DIR}/venv/bin/gunicorn \
    -w 4 \
    -b 0.0.0.0:8000 \
    --access-logfile ${APP_DIR}/logs/access.log \
    --error-logfile ${APP_DIR}/logs/error.log \
    app.wsgi:cryptapp

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cryptopulse
systemctl start cryptopulse