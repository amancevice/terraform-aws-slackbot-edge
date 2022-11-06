all: test dist

clean:
	pipenv --rm

ipython:
	PYTHONPATH=src pipenv run ipython

test: src/app/env.py | .venv
	pipenv run black --check src test
	PYTHONPATH=src pipenv run pytest

.PHONY: all clean test

.venv: Pipfile
	mkdir -p $@
	pipenv install --dev

dist: src/**/*.py
	docker container create --entrypoint=pip --name=slackbot public.ecr.aws/lambda/python install boto3 awscrt -t /var/task
	docker container cp functions/edge/src/app slackbot:/var/task/app
	docker container cp functions/edge/src/index.py slackbot:/var/task/index.py
	docker container start --attach slackbot
	docker container cp slackbot:/var/task dist
	docker container rm slackbot


src/app/env.py: src/app/env.py.tpl
	cp $< $@
