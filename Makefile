SHELL := /bin/bash
ENV_FILE ?= .env
STEALTH ?= basic
MODE ?= headless
DISTRO ?= debian

.PHONY: up down logs rebuild ps health wsurl

up:
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

verify-chrome-flags:
	@CONTAINER=$$(docker ps --filter "ancestor=chrome-cdp:debian-headless-stealth-basic" --filter "ancestor=chrome-cdp:debian-headless-stealth-advanced" --filter "ancestor=chrome-cdp:debian-gui-stealth-basic" --filter "ancestor=chrome-cdp:debian-gui-stealth-advanced" -q | head -1); \
	if [ -z "$$CONTAINER" ]; then \
		echo "❌ No chrome-cdp:headless-* container running"; \
		exit 1; \
	fi; \
	echo "Checking container: $$CONTAINER"; \
	docker exec $$CONTAINER sh -c \
		"cat /proc/\$$(pgrep -o chromium)/cmdline | tr '\0' '\n' | grep -E 'disable-blink-features|user-agent'" \
		&& echo "✅ Stealth flags detected" \
		|| echo "❌ No stealth flags"
