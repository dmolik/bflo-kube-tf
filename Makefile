AWS_ACCESS_KEY_ID ?=
AWS_SECRET_ACCESS_KEY ?=
AWS_DEFAULT_REGION ?=
EXTERNAL_DNS ?=

default: all

all: packer terraform

access: export AWS_ACCESS_KEY_ID     = $(shell while [ -z "$$AWS_ACCESS_KEY_ID" ];     do read -r -p "AWS access key id not found [AWS_ACCESS_KEY_ID]: "  AWS_ACCESS_KEY_ID;      done; echo $$AWS_ACCESS_KEY_ID)
secret: export AWS_SECRET_ACCESS_KEY = $(shell while [ -z "$$AWS_SECRET_ACCESS_KEY" ]; do read -r -p "AWS secret key not found [AWS_SECRET_ACCESS_KEY]: " AWS_SECRET_ACCESS_KEY; done ; echo $$AWS_SECRET_ACCESS_KEY)
region: export AWS_DEFAULT_REGION    = $(shell while [ -z "$$AWS_DEFAULT_REGION" ];    do read -r -p "AWS Default region not set [AWS_DEFAULT_REGION]: "  AWS_DEFAULT_REGION;    done ; echo $$AWS_DEFAULT_REGION)

terraform:
	terraform apply -auto-approve \
		$(shell if [ ! -z $$EXTERNAL_DNS ]; then EXTERNAL_DNS="-var 'external_dns=$$EXTERNAL_DNS'"; echo $$EXTERNAL_DNS; fi ) \
		$(shell if [ ! -z $$GITHUB_ID ]; then GITHUB_ID="-var 'github_id=$$GITHUB_ID'"; echo $$GITHUB_ID; fi ) \
		$(shell if [ ! -z $$GITHUB_SECRET ]; then GITHUB_SECRET="-var 'github_secret=$$GITHUB_SECRET'"; echo $$GITHUB_SECRET; fi ) \
		$(shell if [ ! -z $$GITHUB_ORG ]; then GITHUB_ORG="-var 'github_org=$$GITHUB_ORG'"; echo $$GITHUB_ORG; fi )

packer:
	packer build ami.json

clean:
	terraform destroy -auto-approve -var 'github_secret=a' -var 'github_id=a'
