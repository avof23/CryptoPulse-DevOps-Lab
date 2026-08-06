#!/bin/bash
set -euxo pipefail

APP_DIR="/opt/cryptopulse"
GIT_REPO_URL="https://github.com/avof23/CryptoPulse-DevOps-Lab.git"

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
alembic.ini
alembic/
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


touch /opt/cryptopulse/.provision_done