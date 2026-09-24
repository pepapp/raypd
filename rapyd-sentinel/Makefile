# Local developer workflow. CI runs the same checks; `apply` is CI-only by design.
SHELL        := /bin/bash
AWS_PROFILE  ?= sentinel
export AWS_PROFILE
STACKS       := bootstrap terraform/envs/poc
TFLINT_CFG   := $(CURDIR)/.tflint.hcl

.PHONY: help fmt fmt-check local-backend init validate lint plan-bootstrap plan-poc check clean

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "  %-16s %s\n", $$1, $$2}'

fmt: ## Format all Terraform
	terraform fmt -recursive

fmt-check: ## Fail if formatting is off (CI gate)
	terraform fmt -recursive -check -diff

local-backend: ## Use local state for dev plans (writes git-ignored backend_override.tf)
	@for s in $(STACKS); do \
	  [ -f $$s/backend_override.tf ] || cp $$s/backend_override.tf.example $$s/backend_override.tf; \
	  echo "local backend override -> $$s"; done

init: local-backend ## terraform init every stack (local backend)
	@for s in $(STACKS); do echo "== init $$s"; terraform -chdir=$$s init -input=false -reconfigure || exit 1; done

validate: ## terraform validate every stack
	@for s in $(STACKS); do echo "== validate $$s"; terraform -chdir=$$s validate || exit 1; done

lint: ## tflint every stack (incl. local modules)
	tflint --init --config $(TFLINT_CFG)
	@for s in $(STACKS); do echo "== tflint $$s"; tflint --chdir=$$s --config $(TFLINT_CFG) || exit 1; done

plan-bootstrap: ## Plan the bootstrap stack (read-only against AWS)
	terraform -chdir=bootstrap plan -input=false -out=tfplan

plan-poc: ## Plan the poc stack (read-only against AWS)
	terraform -chdir=terraform/envs/poc plan -input=false -out=tfplan

check: fmt-check init validate lint ## Everything CI checks before plan

clean: ## Remove local .terraform dirs, plans and local state
	@for s in $(STACKS); do rm -rf $$s/.terraform $$s/tfplan $$s/terraform.tfstate*; done
