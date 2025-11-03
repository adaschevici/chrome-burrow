SHELL := /bin/bash
ENV_FILE ?= .env
STEALTH ?= basic
MODE ?= headless
DISTRO ?= debian

# Container name (adjust to match your docker-compose service name)
CONTAINER_NAME ?= chromium
COMPOSE_FILE ?= docker-compose.yml
# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: up down logs rebuild ps health wsurl

up:
	@echo "Building and starting chromium container in $(MODE) mode with $(DISTRO) (stealth: $(STEALTH))"
	DISTRO=$(DISTRO) MODE=$(MODE) STEALTH=$(STEALTH) docker compose --env-file $(ENV_FILE) up chrome-$(MODE) -d --build

down:
	docker compose --env-file $(ENV_FILE) down

logs:
	docker compose --env-file $(ENV_FILE) logs -f

rebuild:
	DISTRO=$(DISTRO) MODE=$(MODE) STEALTH=$(STEALTH) docker compose --env-file $(ENV_FILE) build --no-cache chrome-$(MODE)

ps:
	docker compose --env-file $(ENV_FILE) ps

health:
	@echo "Headless:" && curl -fsS http://127.0.0.1:$$(grep ^CDP_HOST_PORT $(ENV_FILE) | cut -d= -f2)/json/version | jq -r .Browser || true
	@echo "GUI:" && curl -fsS http://127.0.0.1:$$(grep ^CDP_PORT_GUI $(ENV_FILE) | cut -d= -f2)/json/version | jq -r .Browser || true

# Quick helper to print a page websocketDebuggerUrl (requires jq)
wsurl:
	@curl -s "http://127.0.0.1:$$(grep ^CDP_PORT_HEADLESS $(ENV_FILE) | cut -d= -f2)/json/new?about:blank" | jq -r .webSocketDebuggerUrl
	@curl -s "http://127.0.0.1:$$(grep ^CDP_PORT_GUI $(ENV_FILE) | cut -d= -f2)/json/new?about:blank" | jq -r .webSocketDebuggerUrl

# Define the image filter patterns
CHROME_IMAGES := \
	chrome-cdp:debian-headless-stealth-basic \
	chrome-cdp:debian-headless-stealth-advanced \
	chrome-cdp:debian-gui-stealth-basic \
	chrome-cdp:debian-gui-stealth-advanced \
	chrome-cdp:alpine-headless-stealth-basic \
	chrome-cdp:alpine-headless-stealth-advanced \
	chrome-cdp:alpine-gui-stealth-basic \
	chrome-cdp:alpine-gui-stealth-advanced

# Build docker ps filter arguments
DOCKER_FILTERS := $(foreach img,$(CHROME_IMAGES),--filter "ancestor=$(img)")

# Command to get the first running chrome-cdp container
GET_CONTAINER = docker ps $(DOCKER_FILTERS) -q | head -1

verify-chrome-flags:
	@CONTAINER=$$($(GET_CONTAINER)); \
	if [ -z "$$CONTAINER" ]; then \
		echo "❌ No chrome-cdp:*-* container running"; \
		exit 1; \
	fi; \
	echo "Checking container: $$CONTAINER"; \
	docker exec $$CONTAINER sh -c \
		"cat /proc/\$$(pgrep -o chromium)/cmdline | tr '\0' '\n' | grep -E 'disable-blink-features|user-agent'" \
		&& echo "✅ Stealth flags detected" \
		|| echo "❌ No stealth flags"

stats:
	@echo "=== Container Stats Snapshot ==="
	@docker stats --no-stream --format \
		"table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" \
		$$(docker-compose -f $(COMPOSE_FILE) ps -q)


stats-live:
	@echo "=== Live Container Stats (Ctrl+C to exit) ==="
	@docker stats --format \
		"table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" \
		$$(docker-compose -f $(COMPOSE_FILE) ps -q)

top:
	@CONTAINER=$$($(GET_CONTAINER))
	@echo "=== Top Processes in Container ==="
	@docker top $$(docker-compose -f $(COMPOSE_FILE) ps -q $$CONTAINER)
# stats:
# 	@CONTAINER=$$($(GET_CONTAINER)); \
# 	if [ -z "$$CONTAINER" ]; then \
# 		echo "❌ No chrome-cdp:*-* container running"; \
# 		exit 1; \
# 	fi; \
# 	echo "Checking container: $$CONTAINER"; \
