# X4G Next - Railway Deployment

## Quick Start

1. Go to [railway.app](https://railway.app) → New Project → Deploy from GitHub
2. Select this repo/folder
3. Set environment variables:
   - `DOMAIN` = your Railway domain (e.g., `x4g-production.up.railway.app`)
   - `UUID` = (optional, auto-generated if empty)
   - `WS_PATH` = `/ws` (default)
4. Deploy!

## How It Works

```
Client (V2RayNG)
    │
    ▼
wss://x4g-production.up.railway.app/ws (Railway Edge: TLS)
    │
    ▼
Container:$PORT (Xray WS, security=none)
    │
    ▼
Internet (freedom outbound)
```

Railway handles TLS termination at the edge, so Xray runs with `security=none` internally.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | - | Railway domain or custom domain |
| `UUID` | No | auto | VLESS UUID (auto-generated if empty) |
| `WS_PATH` | No | `/ws` | WebSocket path |
| `PORT` | Auto | 10000 | Set by Railway automatically |

## After Deploy

Check logs in Railway dashboard. You'll see:

```
[INFO] ======================================
[INFO]   X4G Next - Railway Deployment Ready
[INFO] ======================================
[INFO] Domain: x4g-production.up.railway.app
[INFO] UUID: 550e8400-e29b-41d4-a716-446655440000
[INFO] Subscription Link:
vless://550e8400-...@x4g-production.up.railway.app:443?type=ws&security=tls...
```

Copy the VLESS URL into V2RayNG / Shadowrocket to connect.

## Custom Domain

In Railway dashboard → Settings → Networking → Add custom domain.

Update `DOMAIN` env var to match.

## Limitations

- **No persistent storage**: UUID changes on redeploy if not set in env vars
- **No API access**: Xray API (gRPC) not exposed (internal only)
- **Single config**: One VLESS inbound per container
- **No speed limiting**: Freedom outbound, no policy enforcement

## Files

| File | Description |
|------|-------------|
| `Dockerfile` | Container image definition |
| `entrypoint.sh` | Config generator + Xray starter |
| `railway.json` | Railway deployment config |
