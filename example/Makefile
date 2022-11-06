validate:
	terraform fmt -check
	terraform init -backend=false
	AWS_REGION=us-east-1 terraform validate

apply: | .terraform
	terraform apply

.PHONY: validate apply

.terraform:
	terraform init
