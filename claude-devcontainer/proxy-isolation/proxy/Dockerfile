# Squid Proxy for AI Agent Network Isolation
# Lightweight proxy that enforces domain allowlist

FROM ubuntu:22.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install Squid proxy and utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    squid \
    ca-certificates \
    curl \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create log, spool, and pid directories with proper permissions
RUN mkdir -p /var/log/squid /var/spool/squid /var/run/squid && \
    chown -R proxy:proxy /var/log/squid /var/spool/squid /var/run/squid

# Copy configuration files
COPY squid.conf /etc/squid/squid.conf
COPY allowlist.txt /etc/squid/allowlist.txt

# Initialize cache directory
RUN squid -z --foreground 2>/dev/null || true

# Expose Squid port
EXPOSE 3128

# Health check - verify squid process is running and port is open
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD nc -z localhost 3128 || exit 1

# Run Squid in foreground
CMD ["squid", "-N", "-d", "1"]
