###############################
# Unified Makefile
# - Single container (vapor app) build/run targets
# - Compose stack (web + model-runner) convenience
# - Model artifacts / submodule init
# - API smoke + helper endpoints
###############################

.DEFAULT_GOAL := help

# -------- Variables --------
IMG            ?= vapor-app:clean
NAME           ?= vapor-app
PORT           ?= 8080
USER_ID_GID    ?= 1000:1000
HOST_SESSIONS  ?= /home/pi/appdata/sessions

# API auth/header (override HDR as needed)
API_KEY        ?= supersecret123
TOKEN          ?=
BASE_URL       ?= http://localhost:$(PORT)
HDR            ?= X-API-Key: $(API_KEY)
# For bearer auth: make ... HDR="Authorization: Bearer $$TOKEN"

# Models and compose
MODELS_DIR     ?= appdata/models/tcn_vae
COMPOSE_FILES   = -f docker-compose.yml
COMPOSE         = docker compose $(COMPOSE_FILES)
COMPOSE_STUB    = docker compose --profile hailo-stub
COMPOSE_DEVICE  = docker compose --profile hailo-device

.PHONY: help \
        init check-models test \
        compose-up compose-down compose-ps compose-logs compose-build \
        hailo-stub hailo-device hailo-down hailo-logs \
        up down ps logs build run stop restart rebuild shell inspect health \
        container-build container-run container-stop container-restart container-rebuild container-logs container-shell container-ps container-inspect container-health \
        sessions session results smoke \
        worker-status worker-restart worker-logs

###############################
# Help
###############################
help: ## Show this help
	@printf "Targets:\n"
	@awk 'BEGIN{FS":.*##"} /^[a-zA-Z0-9_.-]+:.*##/{printf "  \033[1m%-24s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

###############################
# Submodules & model artifacts
###############################
init: ## Init submodules and verify model artifacts exist
	@git submodule update --init --recursive
	@./scripts/check-models.sh $(MODELS_DIR)

check-models: ## Validate required model artifacts exist
	@./scripts/check-models.sh $(MODELS_DIR)

###############################
# Tests (containerized to keep host clean)
###############################
test: ## Run Swift tests in Docker (uses cache volumes) or scripts/test-docker.sh if present
	@bash -lc 'if [ -x scripts/test-docker.sh ]; then bash scripts/test-docker.sh; \
	else \
	  docker volume create swiftpm-cache >/dev/null; \
	  docker volume create swiftpm-config >/dev/null; \
	  docker run --rm -v "$$PWD":/app -w /app \
	    -v swiftpm-cache:/root/.cache -v swiftpm-config:/root/.swiftpm \
	    swift:6.0.2-jammy bash -lc "swift package resolve && swift test --parallel"; \
	fi'

###############################
# Docker Compose (app + model-runner)
###############################
compose-up: ## Bring up stack (web + model-runner)
	@$(COMPOSE) up -d --build

compose-down: ## Bring down stack
	@$(COMPOSE) down

compose-ps: ## Show compose services
	@$(COMPOSE) ps

compose-logs: ## Tail logs for web and model-runner
	@$(COMPOSE) logs -f web model-runner

compose-build: ## Build images only (compose)
	@$(COMPOSE) build

# Short aliases (back-compat)
up: compose-up        ## Alias → compose-up
down: compose-down    ## Alias → compose-down
ps: compose-ps        ## Alias → compose-ps
logs: compose-logs    ## Alias → compose-logs
build: compose-build  ## Alias → compose-build
run: compose-up       ## Alias → compose-up
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

###############################
# Hailo Integration (T2.1a)
###############################
hailo-stub: ## Start EdgeInfer + Hailo stub (development mode)
	@$(COMPOSE_STUB) up -d --build

hailo-device: ## Start EdgeInfer + Hailo device (Pi production mode)  
	@$(COMPOSE_DEVICE) up -d --build

hailo-down: ## Stop all Hailo services
	@$(COMPOSE_STUB) down
	@$(COMPOSE_DEVICE) down

hailo-logs: ## Show logs for all Hailo services
	@$(COMPOSE_STUB) logs -f 2>/dev/null || $(COMPOSE_DEVICE) logs -f

test-health: ## Run cross-service health integration tests
	@./scripts/test-health-integration.sh

test-e2e: ## Run end-to-end integration tests
	@./scripts/test-e2e-integration.sh

test-performance: ## Run standard performance tests (60s, 10 users)
	@./scripts/test-performance.sh

test-performance-quick: ## Run quick performance validation (15s, 5 users)
	@DURATION=15 USERS=5 ./scripts/test-performance.sh quick

test-performance-stress: ## Run stress test with increasing load
	@./scripts/test-performance.sh stress

test-all: ## Run all test suites (unit, health, e2e, performance-quick)
	@echo "🧪 Running complete test suite..."
	@$(MAKE) test
	@$(MAKE) test-health
	@$(MAKE) test-e2e
	@$(MAKE) test-performance-quick

###############################
# Monitoring & Observability (T2.2a)
###############################
monitoring-up: ## Start comprehensive monitoring stack (Prometheus + Grafana)
	@echo "🔍 Starting monitoring stack..."
	@$(COMPOSE_STUB) up -d
	@docker compose -f docker-compose.monitoring.yml up -d
	@echo "📊 Grafana available at: http://localhost:3000 (admin/admin123)"
	@echo "🎯 Prometheus available at: http://localhost:9090"

monitoring-down: ## Stop monitoring stack
	@docker compose -f docker-compose.monitoring.yml down
	@$(COMPOSE_STUB) down

monitoring-logs: ## Show monitoring service logs
	@docker compose -f docker-compose.monitoring.yml logs -f

monitoring-restart: ## Restart monitoring services
	@docker compose -f docker-compose.monitoring.yml restart

monitoring-clean: ## Clean monitoring data (removes volumes)
	@docker compose -f docker-compose.monitoring.yml down -v
	@docker volume rm pisrv_vapor_docker_prometheus_data pisrv_vapor_docker_grafana_data 2>/dev/null || true

###############################
# Single-container lifecycle (vapor app only)
###############################
container-build: ## Build single-container app image
	@docker build -t $(IMG) .

container-run: ## Run single-container app (no model-runner)
	@docker rm -f $(NAME) >/dev/null 2>&1 || true
	@docker run -d --name $(NAME) \
	  -e PORT=$(PORT) \
	  -p $(PORT):8080 \
	  -v $(HOST_SESSIONS):/sessions \
	  --user $(USER_ID_GID) \
	  $(IMG)

container-stop: ## Stop single-container app
	@docker stop $(NAME) || true

container-restart: ## Restart single-container app
	@docker restart $(NAME)

container-rebuild: ## Rebuild + restart single-container app
	@$(MAKE) container-build
	@$(MAKE) container-run

container-logs: ## Tail logs of single-container app
	@docker logs -f $(NAME)

container-shell: ## Shell into single-container app
	@docker exec -it $(NAME) bash || true

container-ps: ## Show single-container status
	@docker ps --filter "name=$(NAME)"

container-inspect: ## Inspect single-container json
	@docker inspect $(NAME)

container-health: ## HTTP health against single-container
	@curl -fsS $(BASE_URL)/health || true

###############################
# API convenience calls
###############################
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

###############################
# Systemd worker shortcuts (for server hosts)
###############################
worker-status: ## systemctl status data-dogs-worker
	@systemctl status data-dogs-worker --no-pager || true

worker-restart: ## Restart worker and show status
	@sudo systemctl restart data-dogs-worker || true
	@systemctl status data-dogs-worker --no-pager || true

worker-logs: ## Tail recent worker logs
	@journalctl -u data-dogs-worker -n 100 --no-pager || true
