# EdgeInfer / Service convenience targets
# Default goal shows help
.DEFAULT_GOAL := help

# Compose files and common vars
COMPOSE_FILES = -f docker-compose.yml -f docker-compose.model.yml
COMPOSE       = docker compose $(COMPOSE_FILES)

# Models location (override with `make check-models MODELS_DIR=...`)
MODELS_DIR ?= appdata/models/tcn_vae

# API convenience (override at call-site if needed)
BASE_URL ?= http://localhost:8080
# If you use bearer auth: TOKEN=xxxxx make session SID=...
HDR     ?= Authorization: Bearer $(TOKEN)

.PHONY: help init test up down ps logs build run stop restart rebuild shell inspect health \
        sessions session results smoke worker-status worker-restart worker-logs check-models

help: ## Show this help
	@printf "Targets:\n"
	@awk 'BEGIN{FS":.*##"} /^[a-zA-Z0-9_-]+:.*##/{printf "  \033[1m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ---------- Dev / CI helpers ----------
init: ## Init submodules and verify model artifacts exist
	@git submodule update --init --recursive
	@./scripts/check-models.sh $(MODELS_DIR)

test: ## Run Swift tests in Docker (uses cache volumes) or scripts/test-docker.sh if present
	@bash -lc 'if [ -x scripts/test-docker.sh ]; then bash scripts/test-docker.sh; \
	else \
	  docker volume create swiftpm-cache >/dev/null; \
	  docker volume create swiftpm-config >/dev/null; \
	  docker run --rm -v "$$PWD":/app -w /app \
	    -v swiftpm-cache:/root/.cache -v swiftpm-config:/root/.swiftpm \
	    swift:6.0.2-jammy bash -lc "swift package resolve && swift test --parallel"; \
	fi'

check-models: ## Validate required model artifacts exist
	@./scripts/check-models.sh $(MODELS_DIR)

# ---------- Docker Compose lifecycle ----------
up: ## Bring up app + model sidecar (build if needed)
	@$(COMPOSE) up -d --build

down: ## Bring down services
	@$(COMPOSE) down

ps: ## Show compose services
	@$(COMPOSE) ps

logs: ## Tail logs for web and model-runner
	@$(COMPOSE) logs -f web model-runner

build: ## Build images only
	@$(COMPOSE) build

run: ## Alias for 'up'
	@$(COMPOSE) up -d --build

stop: ## Stop services without removing resources
	@$(COMPOSE) stop

restart: ## Restart services
	@$(COMPOSE) restart

rebuild: ## Recreate with fresh build
	@$(COMPOSE) up -d --build --force-recreate

shell: ## Open a bash shell in the web container
	@$(COMPOSE) exec web bash || $(COMPOSE) run --rm web bash

inspect: ## Inspect current containers (basic)
	@$(COMPOSE) ps

health: ## Show health/status summary
	@$(COMPOSE) ps

# ---------- API convenience calls ----------
sessions: ## GET /sessions
	@test -n "$(BASE_URL)"
	@curl -sSf -H "$(HDR)" $(BASE_URL)/sessions | jq

session: ## GET /sessions/{SID} (usage: make session SID=<uuid>)
	@test -n "$(SID)"
	@test -n "$(BASE_URL)"
	@curl -sSf -H "$(HDR)" $(BASE_URL)/sessions/$(SID) | jq

results: ## HEAD /sessions/{SID}/results (200 means present)
	@test -n "$(SID)"
	@test -n "$(BASE_URL)"
	@curl -sS -o /dev/null -w "HTTP %{http_code}\n" -H "$(HDR)" $(BASE_URL)/sessions/$(SID)/results

smoke: ## Minimal upload smoke-test (creates 1-byte mp4 + tiny imu json)
	@echo '{"dummy":"imu"}' > imu.json
	@dd if=/dev/zero of=sample.mp4 bs=1 count=1 2>/dev/null
	@curl -sSf -F video=@sample.mp4 -F imu=@imu.json -F meta='{"dog":"Olive"}' \
		$(BASE_URL)/sessions/upload | jq

# ---------- Systemd worker shortcuts (for server hosts) ----------
worker-status: ## systemctl status data-dogs-worker
	@systemctl status data-dogs-worker --no-pager

worker-restart: ## Restart worker and show status
	@sudo systemctl restart data-dogs-worker
	@systemctl status data-dogs-worker --no-pager

worker-logs: ## Tail recent worker logs
	@journalctl -u data-dogs-worker -n 100 --no-pager
