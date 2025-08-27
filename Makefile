IMG            ?= vapor-app:clean
NAME           ?= vapor-app
PORT           ?= 8080
USER_ID_GID    ?= 1000:1000
HOST_SESSIONS  ?= /home/pi/appdata/sessions
API_KEY        ?= supersecret123
BASE_URL       ?= http://localhost:$(PORT)
HDR            ?= X-API-Key: $(API_KEY)

.PHONY: build run stop restart rebuild logs shell ps inspect health sessions session results smoke worker-status worker-restart worker-logs

build:
	docker build -t $(IMG) .

run:
	docker run -d --name $(NAME) \
		--user $(USER_ID_GID) \
		-p $(PORT):8080 \
		-e SESSIONS_DIR=/var/app/sessions \
		-e API_KEY="$(API_KEY)" \
		-v $(HOST_SESSIONS):/var/app/sessions \
		$(IMG)

stop:
	- docker rm -f $(NAME)

restart: stop run

rebuild: stop build run

logs:
	docker logs -f -n 200 $(NAME)

shell:
	docker exec -it $(NAME) bash

ps:
	docker ps --filter name=$(NAME)

inspect:
	docker inspect $(NAME) --format '{{json .Mounts}}'

health:
	curl -sSf $(BASE_URL)/healthz && echo

sessions:
	curl -sSf -H "$(HDR)" $(BASE_URL)/sessions | jq

# Usage: make session SID=<uuid>
session:
	test -n "$(SID)"
	curl -sSf -H "$(HDR)" $(BASE_URL)/sessions/$(SID) | jq

# Usage: make results SID=<uuid>
results:
	test -n "$(SID)"
	curl -sS -o /dev/null -w "HTTP %{http_code}\n" -H "$(HDR)" $(BASE_URL)/sessions/$(SID)/results

smoke:
	echo '{"dummy":"imu"}' > imu.json
	dd if=/dev/zero of=sample.mp4 bs=1 count=1 2>/dev/null
	curl -sSf -F video=@sample.mp4 -F imu=@imu.json -F meta='{"dog":"Olive"}' \
		$(BASE_URL)/sessions/upload | jq

worker-status:
	systemctl status data-dogs-worker --no-pager

worker-restart:
	sudo systemctl restart data-dogs-worker
	systemctl status data-dogs-worker --no-pager

worker-logs:
	journalctl -u data-dogs-worker -n 100 --no-pager
