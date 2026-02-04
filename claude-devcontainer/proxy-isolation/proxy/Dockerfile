# Squid Proxy for AI Agent Network Isolation
# Lightweight proxy that enforces domain allowlist

FROM ubuntu:22.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install Squid proxy
RUN apt-get update && apt-get install -y --no-install-recommends \
    squid \
    ca-certificates \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create log directory with proper permissions
RUN mkdir -p /var/log/squid /var/spool/squid && \
    chown -R proxy:proxy /var/log/squid /var/spool/squid

# Copy configuration files
COPY squid.conf /etc/squid/squid.conf
COPY allowlist.txt /etc/squid/allowlist.txt

# Initialize cache directory
RUN squid -z --foreground 2>/dev/null || true

# Expose Squid port
EXPOSE 3128

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD squid -k check || exit 1

# Run Squid in foreground
CMD ["squid", "-N", "-d", "1"]
