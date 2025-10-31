FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Default ports
ENV CHROME_PORT=9222
ENV SOCAT_PORT=9223

# Install Chromium, socat, and dependencies
RUN apt-get update && apt-get install -y \
  chromium \
  socat \
  curl \
  net-tools \
  iproute2 \
  fonts-liberation \
  fonts-noto-color-emoji \
  fonts-roboto \
  fonts-noto \
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
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -m -s /bin/bash chrome

# Create directory for user data
RUN mkdir -p /home/chrome/data && chown -R chrome:chrome /home/chrome

ARG STEALTH=basic
# Copy the startup script from host
COPY ${STEALTH}.sh /usr/local/bin/start-chrome.sh

# Make it executable and set ownership
RUN chmod +x /usr/local/bin/start-chrome.sh && \
  chown chrome:chrome /usr/local/bin/start-chrome.sh

USER chrome
WORKDIR /home/chrome

EXPOSE ${SOCAT_PORT}

CMD ["/usr/local/bin/start-chrome.sh"]
