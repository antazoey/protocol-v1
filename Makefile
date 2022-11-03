.PHONY: venv install install-dev test run clean

VENV?=./.venv
PYTHON=${VENV}/bin/python3
PIP=${VENV}/bin/pip

$(VENV)/bin/activate: requirements.txt
	python3 -m venv $(VENV)
	${PIP} install -U pip
	${PIP} install wheel

venv: ${VENV}/bin/activate

install: venv
	${PIP} install -r requirements.txt

install-dev: venv install
	${PIP} install -r requirements-dev.txt

test: venv install-dev
	${VENV}/bin/brownie test -n auto

clean:
	rm -rf ${VENV}