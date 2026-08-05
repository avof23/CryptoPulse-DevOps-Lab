#!/bin/bash
set -euxo pipefail

# ==========================================
# 1. Переменные
# ==========================================
APP_DIR="/opt/cryptapp"
GIT_REPO_URL="https://github.com/your-org/your-project.git"

# Имена параметров в AWS SSM Parameter Store
SSM_DB_USER_PARAM="/project/db/username"
SSM_DB_PASS_PARAM="/project/db/password"

AWS_REGION="us-east-1" # Замените на ваш регион AWS

# ==========================================
# 2. Установка пакетов (Debian)
# ==========================================
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
# Для работы venv и сборки некоторых C-библиотек (например, psycopg2) нужны python3-venv, python3-pip, gcc
apt-get install -y python3 python3-venv python3-pip git awscli build-essential libpq-dev

# ==========================================
# 3. Выкачивание кода из Git (Sparse Checkout)
# ==========================================
# Выкачиваем root-файлы (requirements.txt, env и т.д.) И папку с приложением
mkdir -p /tmp/git_app
cd /tmp/git_app

git init
git config core.sparseCheckout true
git remote add origin "${GIT_REPO_URL}"

# Указываем, что нам нужен requirements.txt, alembic и сама папка приложения
cat <<EOF >> .git/info/sparse-checkout
requirements.txt
alembic.ini
alembic/
app/
EOF

git pull --depth 1 origin main

# Переносим всё в директорию приложения
mkdir -p ${APP_DIR}
cp -r /tmp/git_app/* ${APP_DIR}/
cd /
rm -rf /tmp/git_app

# ==========================================
# 4. Инициализация Python Virtualenv
# ==========================================
python3 -m venv ${APP_DIR}/venv

# Активируем venv и обновляем pip
source ${APP_DIR}/venv/bin/activate
pip install --upgrade pip

# Устанавливаем зависимости из requirements.txt
pip install -r ${APP_DIR}/requirements.txt

# ==========================================
# 5. Генерация .env из SSM Parameter Store
# ==========================================
# Вытягиваем логин и пароль с дешифрацией SecureString
DB_USER=$(aws ssm get-parameter --name "${SSM_DB_USER_PARAM}" --with-decryption --region "${AWS_REGION}" --query "Parameter.Value" --output text)
DB_PASS=$(aws ssm get-parameter --name "${SSM_DB_PASS_PARAM}" --with-decryption --region "${AWS_REGION}" --query "Parameter.Value" --output text)

# Формируем .env файл в директории приложения
cat <<EOF > ${APP_DIR}/.env
DB_HOST=db.projectname.internal
DB_PORT=5432
DB_NAME=cryptdb
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
EOF

# Ограничиваем права на .env
chmod 600 ${APP_DIR}/.env

# ==========================================
# 6. Подготовка директорий и логов
# ==========================================
mkdir -p ${APP_DIR}/logs
# Создаем системного пользователя без прав sudo для запуска приложения
useradd -r -s /bin/false appuser || true
chown -R appuser:appuser ${APP_DIR}

# ==========================================
# 7. Скрипт миграции базы (Alembic)
# ==========================================
# Создаем отдельный скрипт, который будет пытаться накатить миграции
cat <<'EOF' > ${APP_DIR}/run_migrations.sh
#!/bin/bash
source /opt/cryptapp/venv/bin/activate
cd /opt/cryptapp

echo "Ожидание готовности базы данных..."
# Пробуем накатить миграции с повторными попытками (до 30 раз с паузой 10 сек)
MAX_RETRIES=30
COUNT=0

until alembic upgrade head || [ $COUNT -eq $MAX_RETRIES ]; do
    echo "База данных недоступна или миграция завершилась ошибкой. Повтор через 10 секунд... ($COUNT/$MAX_RETRIES)"
    sleep 10
    ((COUNT++))
done

if [ $COUNT -eq $MAX_RETRIES ]; then
    echo "Не удалось применить миграции Alembic. База данных недоступна."
    exit 1
fi

echo "Миграции базы данных успешно применены!"
EOF

chmod +x ${APP_DIR}/run_migrations.sh
chown appuser:appuser ${APP_DIR}/run_migrations.sh

# Запускаем скрипт миграции в фоне (он будет ждать базу, не блокируя старт инстанса)
nohup su -s /bin/bash appuser -c "${APP_DIR}/run_migrations.sh" > ${APP_DIR}/logs/migration.log 2>&1 &

# ==========================================
# 8. Создание Systemd Service для Gunicorn
# ==========================================
cat <<EOF > /etc/systemd/system/cryptapp.service
[Unit]
Description=Gunicorn Application Server for CryptApp
After=network.target

[Service]
User=appuser
Group=appuser
WorkingDirectory=${APP_DIR}
Environment="PATH=${APP_DIR}/venv/bin"
# Автоматическая загрузка переменных из .env файла
EnvironmentFile=${APP_DIR}/.env

ExecStart=${APP_DIR}/venv/bin/gunicorn \
    -w 4 \
    -b 127.0.0.1:8000 \
    --access-logfile ${APP_DIR}/logs/access.log \
    --error-logfile ${APP_DIR}/logs/error.log \
    app.wsgi:cryptapp

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ==========================================
# 9. Перезапуск systemd и запуск приложения
# ==========================================
systemctl daemon-reload
systemctl enable cryptapp
systemctl start cryptapp