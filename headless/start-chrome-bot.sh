#!/bin/bash
set -e

echo "Starting Chromium..."
# Start Chromium with a page loaded - this makes it accept DevTools connections
chromium \
  --no-sandbox \
  --disable-setuid-sandbox \
  --disable-dev-shm-usage \
  --disable-gpu \
  --headless=new \
  --remote-debugging-port=9222 \
  --user-data-dir=/home/chrome/data \
  --disable-software-rasterizer \
  --disable-extensions \
  --no-first-run \
  --disable-background-networking \
  --disable-breakpad \
  --disable-client-side-phishing-detection \
  --disable-sync \
  --metrics-recording-only \
  --no-default-browser-check \
  --mute-audio \
  --hide-scrollbars \
  about:blank &

CHROME_PID=$!
echo "Chromium started with PID $CHROME_PID"

# Wait for Chromium to be ready
echo "Waiting for Chromium to start..."
for i in {1..30}; do
  if curl -s "http://127.0.0.1:${CHROME_PORT}/json/version" >/dev/null 2>&1; then
    echo "Chromium is ready!"
    break
  fi
  echo "Waiting... ($i/30)"
  sleep 0.5
done

# Verify Chromium is actually responding
echo "Testing Chromium connection..."
curl -v "http://127.0.0.1:${CHROME_PORT}/json/version" || echo "Warning: Chromium not responding"

# Start socat proxy
echo "Starting socat proxy on 0.0.0.0:${SOCAT_PORT}..."
exec socat "TCP-LISTEN:${SOCAT_PORT},fork,reuseaddr" "TCP:127.0.0.1:${CHROME_PORT}"
