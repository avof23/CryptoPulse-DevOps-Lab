PYTHON = .venv/bin/python3.11

req:
	pip freeze > requirements.txt
prepare:
	pip install -r requirements.txt
run:
	gunicorn -w 4 -b 0.0.0.0:8000 --access-logfile logs/access.log --error-logfile logs/error.log app.wsgi:cryptapp
