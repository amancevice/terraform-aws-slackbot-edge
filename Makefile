all: test validate

clean:
	make -C functions/edge $@

ipython:
	make -C functions/edge $@

logs:
	aws logs tail --region us-east-1 --follow /aws/lambda/us-east-1.slackbot-edge

test:
	make -C functions/edge $@

validate:
	terraform fmt -check
	make -C example $@

.PHONY: all clean ipython logs test validate
