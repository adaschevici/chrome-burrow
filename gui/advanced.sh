#!/bin/bash
set -ex # Exit on error, print commands

echo "========================================="
echo "=== CHROMIUM STARTUP SCRIPT DEBUG ==="
echo "========================================="
echo "Timestamp: $(date)"
echo "User: $(whoami)"
echo "UID: $(id -u)"
echo "Working directory: $(pwd)"
echo "HOME: $HOME"
echo "DISPLAY: $DISPLAY"
echo "PATH: $PATH"
echo "========================================="

# Set DISPLAY explicitly
export DISPLAY=:99
echo "Set DISPLAY to: $DISPLAY"

# Test if xdpyinfo is available
# Show X server details
echo "X server details:"
xdpyinfo -display $DISPLAY | head -10

# Check if chromium exists
if ! command -v chromium &>/dev/null; then
  echo "ERROR: chromium command not found!"
  echo "Looking for chromium binary..."
  find /usr -name "chromium*" -type f 2>/dev/null | head -5
  exit 1
fi

CHROMIUM_BIN=$(which chromium)
echo "Using Chromium at: $CHROMIUM_BIN"

# Create data directory if it doesn't exist
mkdir -p /home/chrome/data
echo "Data directory ready: /home/chrome/data"

echo ""
echo "========================================="
echo "=== LAUNCHING CHROMIUM ==="
echo "========================================="
echo ""
echo "Starting Chromium in STEALTH mode on port ${CHROME_PORT}..."
echo "Socat will proxy to port ${SOCAT_PORT}..."

# Start Chromium with stealth flags
exec $CHROMIUM_BIN \
  --test-type \
  --no-sandbox \
  --disable-setuid-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --remote-debugging-port="${CHROME_PORT}" \
  --exclude-switches=enable-automation \
  --user-data-dir=/home/chrome/data \
  \
  `# Stealth: Disable automation detection` \
  --disable-blink-features=AutomationControlled \
  --disable-features=IsolateOrigins,site-per-process \
  \
  `# Stealth: Pretend to be a real browser` \
  --window-size=1920,1080 \
  --start-maximized \
  --disable-infobars \
  --no-first-run \
  --no-default-browser-check \
  \
  `# Stealth: Enable features that real browsers have` \
  --enable-features=NetworkService,NetworkServiceInProcess \
  \
  `# Stealth: Disable suspicious features` \
  --disable-extensions \
  --disable-plugins \
  --disable-plugins-discovery \
  --disable-component-extensions-with-background-pages \
  --disable-default-apps \
  --disable-breakpad \
  --disable-component-update \
  --disable-client-side-phishing-detection \
  --disable-sync \
  --disable-background-networking \
  --disable-background-timer-throttling \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disable-field-trial-config \
  --disable-back-forward-cache \
  --disable-hang-monitor \
  --disable-ipc-flooding-protection \
  --disable-popup-blocking \
  --disable-prompt-on-repost \
  --metrics-recording-only \
  --mute-audio \
  --no-pings \
  --password-store=basic \
  --use-mock-keychain \
  --force-color-profile=srgb \
  \
  `# Stealth: User agent and platform` \
  --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  \
  `# Stealth: WebRTC and privacy` \
  --force-webrtc-ip-handling-policy=default_public_interface_only \
  --enforce-webrtc-ip-permission-check \
  \
  `# Start with blank page` \
  https://2captcha.com/demo/cloudflare-turnstile \
  http://www.example.com &

CHROME_PID=$!
echo "Chromium started with PID $CHROME_PID"

# Wait for Chromium to be ready
echo "Waiting for Chromium to start..."
for _ in {1..30}; do
  if curl -s "http://127.0.0.1:${CHROME_PORT}/json/version" >/dev/null 2>&1; then
    echo "Chromium is ready in STEALTH mode!"
    break
  fi
  sleep 0.5
done

# Start socat proxy
echo "Starting socat proxy: 0.0.0.0:${SOCAT_PORT} -> 127.0.0.1:${CHROME_PORT}"
exec socat "TCP-LISTEN:${SOCAT_PORT},fork,reuseaddr" "TCP:127.0.0.1:${CHROME_PORT}"
