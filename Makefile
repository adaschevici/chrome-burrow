SHELL := /bin/bash
ENV_FILE ?= .env
STEALTH ?= basic

.PHONY: up down logs rebuild ps health wsurl

up:
	STEALTH=$(STEALTH) docker compose --env-file $(ENV_FILE) up -d --build

down:
	docker compose --env-file $(ENV_FILE) down

logs:
	docker compose --env-file $(ENV_FILE) logs -f

rebuild-headless-bot:
	@cp headless/start-chrome-bot.sh headless/start-chrome.sh
	docker compose --env-file $(ENV_FILE) build --no-cache
	@rm	headless/start-chrome.sh

ps:
	docker compose --env-file $(ENV_FILE) ps

health:
	@echo "Headless:" && curl -fsS http://127.0.0.1:$$(grep ^CDP_HOST_PORT $(ENV_FILE) | cut -d= -f2)/json/version | jq -r .Browser || true
	@echo "GUI:" && curl -fsS http://127.0.0.1:$$(grep ^CDP_PORT_GUI $(ENV_FILE) | cut -d= -f2)/json/version | jq -r .Browser || true

# Quick helper to print a page websocketDebuggerUrl (requires jq)
wsurl:
	@curl -s "http://127.0.0.1:$$(grep ^CDP_PORT_HEADLESS $(ENV_FILE) | cut -d= -f2)/json/new?about:blank" | jq -r .webSocketDebuggerUrl
	@curl -s "http://127.0.0.1:$$(grep ^CDP_PORT_GUI $(ENV_FILE) | cut -d= -f2)/json/new?about:blank" | jq -r .webSocketDebuggerUrl

verify-chrome-flags:
	@CONTAINER=$$(docker ps --filter "ancestor=chrome-cdp:headless-stealth-basic" --filter "ancestor=chrome-cdp:headless-stealth-advanced" -q | head -1); \
	if [ -z "$$CONTAINER" ]; then \
		echo "❌ No chrome-cdp:headless-* container running"; \
		exit 1; \
	fi; \
	echo "Checking container: $$CONTAINER"; \
	docker exec $$CONTAINER sh -c \
		"cat /proc/\$$(pgrep -o chromium)/cmdline | tr '\0' '\n' | grep -E 'disable-blink-features|user-agent'" \
		&& echo "✅ Stealth flags detected" \
		|| echo "❌ No stealth flags"
