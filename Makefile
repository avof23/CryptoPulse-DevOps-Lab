PYTHON = .venv/bin/python3.11

req:
	pip freeze > requirements.txt
prepare:
	pip install -r requirements.txt
run:
	export PYTHONPATH=$$PWD && $(PYTHON) main.py
