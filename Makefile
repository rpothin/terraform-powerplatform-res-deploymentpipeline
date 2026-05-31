.PHONY: fmt validate init init-unit init-integration test test-unit test-integration docs lint security-scan check-all

fmt:
	terraform fmt -recursive

validate: init
	terraform validate

init:
	terraform init -backend=false

init-unit:
	terraform init -backend=false -test-directory=tests/unit

init-integration:
	terraform init -backend=false -test-directory=tests/integration

test: test-unit test-integration

test-unit: init-unit
	terraform test -test-directory=tests/unit

test-integration: init-integration
	terraform test -test-directory=tests/integration

docs:
	terraform-docs .
	for dir in examples/*/; do terraform-docs "$$dir"; done

lint:
	terraform fmt -check -recursive

security-scan:
	trivy config --config .trivy.yaml .

check-all: fmt validate docs lint security-scan test-unit
