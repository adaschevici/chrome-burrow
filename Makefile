SHELL := /bin/bash
ENV_FILE ?= .env
STEALTH ?= basic
MODE ?= headless
DISTRO ?= debian

# Container name (adjust to match your docker-compose service name)
CONTAINER_NAME ?= chromium
COMPOSE_FILE ?= docker-compose.yml

.PHONY: up down logs rebuild ps health wsurl

# ============================================
# Configuration
# ============================================
CHROME_IMAGE_PREFIX := chrome-cdp
CHROME_IMAGES := \
	$(CHROME_IMAGE_PREFIX):debian-headless-stealth-basic \
	$(CHROME_IMAGE_PREFIX):debian-headless-stealth-advanced \
	$(CHROME_IMAGE_PREFIX):debian-gui-stealth-basic \
	$(CHROME_IMAGE_PREFIX):debian-gui-stealth-advanced \
	$(CHROME_IMAGE_PREFIX):alpine-headless-stealth-basic \
	$(CHROME_IMAGE_PREFIX):alpine-headless-stealth-advanced \
	$(CHROME_IMAGE_PREFIX):alpine-gui-stealth-basic \
	$(CHROME_IMAGE_PREFIX):alpine-gui-stealth-advanced

# Build docker filter arguments
DOCKER_FILTERS := $(foreach img,$(CHROME_IMAGES),--filter "ancestor=$(img)")

# Command to get container
GET_CONTAINER = docker ps $(DOCKER_FILTERS) -q | head -1

# Command to get all containers
GET_ALL_CONTAINERS = docker ps $(DOCKER_FILTERS) -q

# ============================================
# Helper Functions
# ============================================
# Check if container exists and set CONTAINER variable
define require_container
	$(eval CONTAINER := $(shell $(GET_CONTAINER)))
	@if [ -z "$(CONTAINER)" ]; then \
		echo "❌ No $(CHROME_IMAGE_PREFIX) container running"; \
		echo "Available images: $(CHROME_IMAGES)"; \
		exit 1; \
	fi
	@echo "✓ Using container: $(CONTAINER)"
endef

# ============================================
# Targets
# ============================================
help:
	@echo "Chrome Container Management"
	@echo ""
	@echo "Available targets:"
	@echo "  make list-containers    - List all running chrome containers"
	@echo "  make verify-chrome-flags - Verify stealth flags in Chrome"
	@echo "  make stats              - Show container stats"
	@echo "  make stats-all          - Show stats for all chrome containers"
	@echo "  make logs               - Show container logs"
	# @echo "  make exec CMD=<cmd>     - Execute command in container"
	@echo "  make shell              - Open shell in container"

list-containers:
	@echo "Running chrome-cdp containers:"
	@docker ps $(DOCKER_FILTERS) --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

up:
	@echo "Building and starting chromium container in $(MODE) mode with $(DISTRO) (stealth: $(STEALTH))"
	DISTRO=$(DISTRO) MODE=$(MODE) STEALTH=$(STEALTH) docker compose --env-file $(ENV_FILE) up chrome-$(MODE) -d --build

down:
	docker compose --env-file $(ENV_FILE) down

logs:
	$(call require_container)
	@docker logs -f $(CONTAINER)

shell:
	$(call require_container)
	@docker exec -it $(CONTAINER) bash

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


# ============================================
# Chrome-specific commands
# ============================================
chrome-version:
	$(call require_container)
	@docker exec $(CONTAINER) chromium --version

chrome-tabs:
	$(call require_container)
	@CHROME_PORT=$$(docker port $(CONTAINER) | grep -E '9222|9223|9224' | head -1 | awk -F' -> ' '{print $$2}'); \
	if [ -z "$$CHROME_PORT" ]; then \
		echo "❌ Chrome DevTools port not found"; \
		exit 1; \
	fi; \
	echo "Fetching tabs from http://$$CHROME_PORT/json"; \
	curl -s "http://$$CHROME_PORT/json" | jq -r '.[] | "\(.id): \(.title) - \(.url)"'

chrome-health:
	$(call require_container)
	@CHROME_PORT=$$(docker port $(CONTAINER) | grep -E '9222|9223|9224' | head -1 | awk -F' -> ' '{print $$2}'); \
	if [ -z "$$CHROME_PORT" ]; then \
		echo "❌ Chrome DevTools port not found"; \
		exit 1; \
	fi; \
	echo "=== Chrome DevTools Health Check ==="; \
	echo "Endpoint: http://$$CHROME_PORT"; \
	echo ""; \
	if curl -sf "http://$$CHROME_PORT/json/version" >/dev/null 2>&1; then \
		echo "✅ Chrome DevTools is responding"; \
		echo ""; \
		curl -s "http://$$CHROME_PORT/json/version" | jq -r '"Browser: \(.Browser)\nProtocol Version: \(."Protocol-Version")\nUser Agent: \(."User-Agent")"'; \
	else \
		echo "❌ Chrome not responding"; \
		exit 1; \
	fi

verify-chrome-flags:
	$(call require_container)
	@echo "Verifying Chrome flags in container $(CONTAINER)..."
	@docker exec $(CONTAINER) sh -c \
		"cat /proc/\$$(pgrep -o chromium)/cmdline | tr '\0' '\n' | grep -E 'disable-blink-features|user-agent'" \
		&& echo "✅ Stealth flags detected" \
		|| echo "❌ No stealth flags"

stats:
	$(call require_container)
	@echo "Container stats:"
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}" $(CONTAINER)

stats-all:
	@CONTAINERS=$$($(GET_ALL_CONTAINERS)); \
	if [ -z "$$CONTAINERS" ]; then \
		echo "❌ No $(CHROME_IMAGE_PREFIX) containers running"; \
		exit 1; \
	fi; \
	echo "Stats for all chrome containers:"; \
	docker stats --no-stream --format "table {{.Container}}\t{{.Image}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" $$CONTAINERS

stats-live:
	@CONTAINERS=$$($(GET_ALL_CONTAINERS)); \
	if [ -z "$$CONTAINERS" ]; then \
		echo "❌ No $(CHROME_IMAGE_PREFIX) containers running"; \
		exit 1; \
	fi; \
	docker stats $$CONTAINERS

top:
	@CONTAINER=$$($(GET_CONTAINER))
	@echo "=== Top Processes in Container ==="
	@docker top $$(docker-compose -f $(COMPOSE_FILE) ps -q $$CONTAINER)

# ============================================
# Bulk operations
# ============================================
restart-all:
	@CONTAINERS=$$($(GET_ALL_CONTAINERS)); \
	if [ -z "$$CONTAINERS" ]; then \
		echo "❌ No containers to restart"; \
		exit 1; \
	fi; \
	echo "Restarting all chrome containers..."; \
	docker restart $$CONTAINERS

stop-all:
	@CONTAINERS=$$($(GET_ALL_CONTAINERS)); \
	if [ -z "$$CONTAINERS" ]; then \
		echo "❌ No containers to stop"; \
		exit 1; \
	fi; \
	echo "Stopping all chrome containers..."; \
	docker stop $$CONTAINERS

# Show port mappings for a single container
ports:
	$(call require_container)
	@echo "=== Port Mappings for Container $(CONTAINER) ==="
	@echo ""
	@docker port $(CONTAINER) | awk -F' -> ' '{print $$1 "\t→\t" $$2}' | column -t -s $$'\t'

# Show port mappings for all chrome containers in a table
ports-all:
	@CONTAINERS=$$($(GET_ALL_CONTAINERS)); \
	if [ -z "$$CONTAINERS" ]; then \
		echo "❌ No $(CHROME_IMAGE_PREFIX) containers running"; \
		exit 1; \
	fi; \
	echo "=== Port Mappings for All Chrome Containers ==="; \
	echo ""; \
	printf "%-15s %-40s %-20s %-20s\n" "CONTAINER ID" "IMAGE" "CONTAINER PORT" "HOST BINDING"; \
	printf "%-15s %-40s %-20s %-20s\n" "---------------" "----------------------------------------" "--------------------" "--------------------"; \
	for container in $$CONTAINERS; do \
		IMAGE=$$(docker inspect --format='{{.Config.Image}}' $$container); \
		SHORT_ID=$$(echo $$container | cut -c1-12); \
		docker port $$container | while IFS= read -r line; do \
			CONTAINER_PORT=$$(echo "$$line" | awk -F' -> ' '{print $$1}'); \
			HOST_BINDING=$$(echo "$$line" | awk -F' -> ' '{print $$2}'); \
			printf "%-15s %-40s %-20s %-20s\n" "$$SHORT_ID" "$$IMAGE" "$$CONTAINER_PORT" "$$HOST_BINDING"; \
		done; \
	done

# Detailed port information with service names
ports-detailed:
	$(call require_container)
	@echo "=== Detailed Port Information for Container $(CONTAINER) ==="; \
	echo ""; \
	IMAGE=$$(docker inspect --format='{{.Config.Image}}' $(CONTAINER)); \
	echo "Container: $(CONTAINER)"; \
	echo "Image: $$IMAGE"; \
	echo ""; \
	printf "%-35s %-20s %-25s %-15s\n" "SERVICE" "CONTAINER PORT" "HOST BINDING" "PROTOCOL"; \
	printf "%-35s %-20s %-25s %-15s\n" "----------------------------------" "--------------------" "-------------------------" "---------------"; \
	docker port $(CONTAINER) | while IFS= read -r line; do \
		CONTAINER_PORT=$$(echo "$$line" | awk -F' -> ' '{print $$1}' | cut -d'/' -f1); \
		PROTOCOL=$$(echo "$$line" | awk -F' -> ' '{print $$1}' | cut -d'/' -f2); \
		HOST_BINDING=$$(echo "$$line" | awk -F' -> ' '{print $$2}'); \
		case $$CONTAINER_PORT in \
			9222|9223|9224) SERVICE="Chrome DevTools Socat Proxy" ;; \
			5900) SERVICE="VNC Server" ;; \
			6080) SERVICE="noVNC Web" ;; \
			*) SERVICE="Unknown" ;; \
		esac; \
		printf "%-35s %-20s %-25s %-15s\n" "$$SERVICE" "$$CONTAINER_PORT" "$$HOST_BINDING" "$$PROTOCOL"; \
	done

# View Chrome startup script logs
logs-chrome:
	$(call require_container)
	@echo "=== Supervisor Chrome Program Logs ==="
	@docker exec $(CONTAINER) cat /var/log/supervisor/chrome.log 2>/dev/null || \
		echo "Chrome log file not found"

# Live tail of Chrome logs
logs-chrome-live:
	$(call require_container)
	@echo "=== Live Chrome Logs (Ctrl+C to exit) ==="
	@docker logs -f $(CONTAINER) 2>&1 | grep --line-buffered "CHROMIUM\|chromium\|Chrome"

