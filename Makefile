# Run every CI security gate locally: make scan
TF_ENVS := $(wildcard terraform/envs/*)

.PHONY: scan fmt validate tflint checkov trivy ansible-lint

scan: fmt validate tflint checkov trivy ansible-lint
	@echo "All security gates passed"

fmt:
	terraform fmt -check -recursive -diff terraform

validate:
	@for env in $(TF_ENVS); do \
		echo "== validate $$env"; \
		terraform -chdir=$$env init -backend=false -input=false >/dev/null && \
		terraform -chdir=$$env validate || exit 1; \
	done

tflint:
	cd terraform && tflint --init --config $(CURDIR)/.tflint.hcl && tflint --recursive --config $(CURDIR)/.tflint.hcl

checkov:
	checkov -d . --config-file .checkov.yaml

trivy:
	trivy config --severity HIGH,CRITICAL --exit-code 1 terraform

ansible-lint:
	cd ansible && ansible-lint --profile production
