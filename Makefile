\
# HR Automation Platform — developer convenience targets.
# Commands are placeholders until the corresponding tooling exists (see CLAUDE.md
# "Validation Commands"). Replace each placeholder as the relevant stack is bootstrapped.

.PHONY: help build test test-backend test-agents test-frontend \
        validate-config validate-openapi security-scan evaluate \
        up down bootstrap

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-18s %s\n", $$1, $$2}'

up: ## Start local dependencies (Postgres, Redis, OTel collector)
	docker compose up -d

down: ## Stop local dependencies
	docker compose down

bootstrap: ## Run the environment bootstrap script for this OS
	./scripts/bootstrap.sh || pwsh ./scripts/bootstrap.ps1

build: ## Build the backend solution
	[COMMAND_TO_BUILD_BACKEND]

test: test-backend test-agents test-frontend ## Run all test suites

test-backend: ## Run backend tests
	[COMMAND_TO_TEST_BACKEND]

test-agents: ## Run agent/AI tests
	[COMMAND_TO_TEST_AGENTS]

test-frontend: ## Run frontend tests
	[COMMAND_TO_TEST_FRONTEND]

validate-openapi: ## Validate OpenAPI/AsyncAPI contracts
	[COMMAND_TO_VALIDATE_OPENAPI]

validate-config: ## Validate config/ against JSON schemas
	./scripts/validate-config.sh || pwsh ./scripts/validate-config.ps1

security-scan: ## Run static/dependency security scans
	[COMMAND_TO_RUN_SECURITY_SCAN]

evaluate: ## Run the AI evaluation suite
	[COMMAND_TO_RUN_EVALUATIONS]
