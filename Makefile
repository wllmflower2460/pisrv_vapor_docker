# EdgeInfer convenience targets

.PHONY: init test up down ps logs help

MODELS_DIR ?= appdata/models/tcn_vae
COMPOSE_FILES = -f docker-compose.yml -f docker-compose.model.yml

init:
@git submodule update --init --recursive
@./scripts/check-models.sh $(MODELS_DIR)

test:
@bash -lc 'if [ -x scripts/test-docker.sh ]; then bash scripts/test-docker.sh; else docker volume create swiftpm-cache >/dev/null; docker volume create swiftpm-config >/dev/null; docker run --rm -v "$$PWD":/app -w /app -v swiftpm-cache:/root/.cache -v swiftpm-config:/root/.swiftpm swift:6.0.2-jammy bash -lc "swift package resolve && swift test --parallel"; fi'

up:
@docker compose $(COMPOSE_FILES) up -d --build

down:
@docker compose down

ps:
@docker compose ps

logs:
@docker compose logs -f web model-runner

help:
@echo "Targets:"
@echo "  init  - init submodules and verify model artifacts exist"
@echo "  test  - run tests in Docker with SPM cache (or scripts/test-docker.sh if present)"
@echo "  up    - bring up app + sidecar with compose override"
@echo "  down  - bring down services"
@echo "  ps    - show compose services"
@echo "  logs  - tail logs for web and model-runner"
