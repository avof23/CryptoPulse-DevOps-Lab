#!/bin/bash
set -euxo pipefail

APP_ALB_DNS="api.${project}.internal"
GIT_REPO_URL="https://github.com/avof23/CryptoPulse-DevOps-Lab.git"
TARGET_DIR="frontend"
WEB_ROOT="/var/www/html"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y apache2 git

a2enmod proxy
a2enmod proxy_http

cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot ${WEB_ROOT}

    <Directory ${WEB_ROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ProxyPreserveHost On
    ProxyRequests Off

    ProxyPass /api/ http://${APP_ALB_DNS}/api/
    ProxyPassReverse /api/ http://${APP_ALB_DNS}/api/

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

rm -rf ${WEB_ROOT}/*

mkdir -p /tmp/git_checkout
cd /tmp/git_checkout
git init
git config core.sparseCheckout true
git remote add origin "${GIT_REPO_URL}"
echo "${TARGET_DIR}/*" >> .git/info/sparse-checkout
git pull --depth 1 origin main

cp -r ${TARGET_DIR}/* ${WEB_ROOT}/
cd /
rm -rf /tmp/git_checkout

chown -R www-data:www-data ${WEB_ROOT}
chmod -R 755 ${WEB_ROOT}

apachectl configtest
systemctl restart apache2
systemctl enable apache2