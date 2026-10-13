#!/bin/bash
# X4G Next - Railway Entrypoint
# Generates Xray config from environment variables and starts Xray

set -euo pipefail

# Environment variables (set in Railway dashboard)
# DOMAIN: your Railway domain (e.g., x4g-production.up.railway.app)
# UUID: optional, auto-generated if not set
# WS_PATH: WebSocket path (default: /ws)
# API_PORT: Xray API port (default: 10085)

DOMAIN="${DOMAIN:-}"
UUID="${UUID:-}"
WS_PATH="${WS_PATH:-/ws}"
API_PORT="${API_PORT:-10085}"
PORT="${PORT:-10000}"  # Railway sets this automatically

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check required variables
if [[ -z "$DOMAIN" ]]; then
    log_error "DOMAIN environment variable is required"
    exit 1
fi

# Generate UUID if not provided
if [[ -z "$UUID" ]]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
    log_info "Generated UUID: $UUID"
else
    log_info "Using provided UUID: $UUID"
fi

# Create config directory
mkdir -p /etc/xray

# Generate Xray config
# Note: On Railway, TLS is handled by Railway Edge, so Xray runs with security=none
cat > /etc/xray/config.json << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "email": "user@$DOMAIN",
            "level": 0,
            "flow": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "$WS_PATH",
          "headers": {
            "Host": "$DOMAIN"
          }
        }
      },
      "tag": "vless-ws-in",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "domain": ["geosite:category-ads-all"],
        "outboundTag": "block"
      }
    ]
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true,
        "bufferSize": 10240
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "api": {
    "tag": "api",
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ]
  },
  "stats": {}
}
EOF

log_ok "Config generated at /etc/xray/config.json"

# Test config
log_info "Testing Xray config..."
if /usr/local/bin/xray -test -config /etc/xray/config.json 2>/dev/null; then
    log_ok "Config test PASSED"
else
    log_error "Config test FAILED"
    /usr/local/bin/xray -test -config /etc/xray/config.json
    exit 1
fi

# Generate subscription link
# On Railway: wss://DOMAIN/ws (Railway handles TLS)
VLESS_URL="vless://$UUID@$DOMAIN:443?type=ws&security=tls&path=$(echo -n "$WS_PATH" | sed 's/\//%2F/g')&host=$DOMAIN&sni=$DOMAIN&fp=chrome#X4G-Railway"

log_info "======================================"
log_info "  X4G Next - Railway Deployment Ready"
log_info "======================================"
log_info "Domain: $DOMAIN"
log_info "UUID: $UUID"
log_info "Port: $PORT (Railway sets this)"
log_info "WS Path: $WS_PATH"
log_info "API Port: $API_PORT"
log_info ""
log_info "Subscription Link:"
echo "$VLESS_URL"
log_info ""
log_info "Base64 (for /sub endpoint):"
echo "$VLESS_URL" | base64 -w 0
log_info "======================================"

# Save for reference
cat > /etc/xray/connection_info.txt << EOF
DOMAIN=$DOMAIN
UUID=$UUID
WS_PATH=$WS_PATH
PORT=$PORT
API_PORT=$API_PORT
VLESS_URL=$VLESS_URL
SUB_B64=$(echo "$VLESS_URL" | base64 -w 0)
EOF

# Start Xray
log_info "Starting Xray..."
exec /usr/local/bin/xray run -config /etc/xray/config.json