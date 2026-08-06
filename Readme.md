# Project structure
```
CryptoPulse-DevOps-Lab/
├── app/                  # Исходный код приложения на Python
│   ├── main.py           # Flask/FastAPI приложение
│   ├── requirements.txt  # Зависимости Python
│   └── templates/        # HTML-шаблоны
├── terraform/            # Инфраструктура как код (IaC)
│   ├── main.tf           # VPC, Subnets, Security Groups
│   ├── ec2.tf            # Инстансы для Web и App
│   ├── rds.tf            # База данных PostgreSQL
│   ├── alb.tf            # Балансировщик нагрузки
│   └── outputs.tf        # Вывод IP-адресов и DNS
├── ansible/              # Управление конфигурацией
│   ├── inventory.ini     # Динамический или статический список хостов
│   ├── playbook.yml      # Главный playbook
│   └── roles/            # Роли для Nginx, App, Python
└── .github/
    └── workflows/        # CI/CD пайплайны (GitHub Actions)
```

Порядок деплоя на терраформ
0. source envsetup.sh , прописать все .tfvars
1. global vars - local state
2. S3 - local state
3. Move global vars to remote state `terraform init -migrate-state -backend-config=$TF_BACKEND_CONFIG`
4. Move S3 to remote state `terraform init -migrate-state -backend-config=$TF_BACKEND_CONFIG`
5. Network 
6. route53
7. bastion
8. mz_rds
9. ec2_app_asg
10. ec2_web_asg
