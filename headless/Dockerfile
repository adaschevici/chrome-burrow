FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install Chromium and dependencies
RUN apt-get update && apt-get install -y \
  chromium \
  socat \
  fonts-liberation \
  fonts-noto-color-emoji \
  libasound2 \
  libatk-bridge2.0-0 \
  libatk1.0-0 \
  libatspi2.0-0 \
  libcups2 \
  libdbus-1-3 \
  libdrm2 \
  libgbm1 \
  libgtk-3-0 \
  libnspr4 \
  libnss3 \
  libwayland-client0 \
  libxcomposite1 \
  libxdamage1 \
  libxfixes3 \
  libxkbcommon0 \
  libxrandr2 \
  xdg-utils \
  procps \
  curl \
  net-tools \
  iproute2 \
  && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -s /bin/bash chrome

# Create directory for user data
RUN mkdir -p /home/chrome/data && chown -R chrome:chrome /home/chrome

# Create startup script
RUN cat > /usr/local/bin/start-chrome.sh << 'EOF'
#!/bin/bash
# Start Chromium in background (it will bind to 127.0.0.1:9222)
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
  --disable-background-networking &

# Wait for Chromium to start
sleep 2

# Use socat to proxy 127.0.0.1:9222 to 0.0.0.0:9223
# This makes it accessible from outside the container
exec socat TCP-LISTEN:9223,fork,reuseaddr TCP:127.0.0.1:9222
EOF


RUN chmod +x /usr/local/bin/start-chrome.sh && \
  chown chrome:chrome /usr/local/bin/start-chrome.sh


USER chrome
WORKDIR /home/chrome

# Expose the debugging port
EXPOSE 9223

CMD ["/usr/local/bin/start-chrome.sh"]

# # CRITICAL: Added --disable-features=IsolateOrigins,site-per-process to allow remote debugging
# # This is necessary for external connections to work properly
# CMD ["chromium", \
#   "--no-sandbox", \
#   "--disable-setuid-sandbox", \
#   "--disable-dev-shm-usage", \
#   "--disable-gpu", \
#   "--headless=new", \
#   "--remote-debugging-port=9222", \
#   "--remote-debugging-address=0.0.0.0", \
#   "--disable-features=IsolateOrigins,site-per-process", \
#   "--disable-site-isolation-trials", \
#   "--user-data-dir=/home/chrome/data", \
#   "--disable-software-rasterizer", \
#   "--disable-extensions", \
#   "--no-first-run", \
#   "--disable-background-networking"]
