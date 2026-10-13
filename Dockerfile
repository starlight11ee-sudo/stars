# X4G Next - Railway Deployment
# Dockerfile for Railway.app

FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Xray Core (direct binary download - more reliable)
ENV XRAY_VERSION=v25.7.26
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then ARCH="64"; fi && \
    if [ "$ARCH" = "aarch64" ]; then ARCH="arm64-v8a"; fi && \
    curl -L -o /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/Xray-linux-${ARCH}.zip" && \
    unzip /tmp/xray.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/xray && \
    rm /tmp/xray.zip && \
    xray version

# Create non-root user
RUN useradd -r -s /bin/false -u 1000 xray \
    && mkdir -p /etc/xray /var/log/xray \
    && chown -R xray:xray /etc/xray /var/log/xray

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch to non-root
USER xray

# Expose port (Railway sets $PORT)
EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:$PORT/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]