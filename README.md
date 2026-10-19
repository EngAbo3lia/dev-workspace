# dev-workspace

Browser development workspace for the Aboalia estate: **code-server** plus the
open-source **Warp TUI** client, sharing one persistent workspace directory.

Both run on the Dokploy host (`192.168.8.200`) behind the `Aboalia Server`
Cloudflare Tunnel, with Cloudflare Access in front.

| Service | Hostname | Port | Source |
|---------|----------|------|--------|
| `code-server` | `code.aboalia.com` | 8080 | `codercom/code-server` image |
| `warp-terminal` | `warp.aboalia.com` | 7681 | image built by GitHub Actions |

Shared workspace: `/srv/dev-workspace` on the host, mounted at `/workspace` in
both containers. Both run as uid 1000.

## Layout

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | code-server stack |
| `warp/docker-compose.yml` | Warp stack, pulls `ghcr.io/engabo3lia/dev-workspace-warp` |
| `warp/Dockerfile` | builds `warp-tui-oss` from a pinned `warpdotdev/warp` commit |
| `warp/entrypoint.sh` | starts `ttyd` with basic auth around the Warp TUI |
| `.github/workflows/warp-image.yml` | builds/pushes the Warp image on GitHub runners |

The Warp image is built in CI on purpose: compiling the Warp workspace on the
Dokploy host exhausted it and restarted the Dokploy panel once.

## What "hosting Warp" means

Warp has no server edition. The desktop app and the WASM web client depend on
Warp's own backend; the web client also expects a `warpUserHandoff()` Firebase
token from Warp's host React app, so it cannot be self-hosted. The only
hostable part is the OSS terminal front-end (`warp_tui`, binary
`warp-tui-oss`), served through `ttyd`.

Login uses Warp's device-authorization flow: the TUI prints a URL and code,
you approve it on any machine, and the session lands inside the container.
Agent runs and model calls still go through Warp's services.

## Environment

code-server stack:

| Variable | Required | Default |
|----------|----------|---------|
| `CODE_SERVER_PASSWORD` | yes | — |
| `CODE_SERVER_VERSION` | no | `4.141.0` |
| `TZ` | no | `Africa/Cairo` |

Warp stack:

| Variable | Required | Default |
|----------|----------|---------|
| `TTYD_PASSWORD` | yes | — |
| `TTYD_USER` | no | `warp` |
| `TTYD_MAX_CLIENTS` | no | `4` |
| `WARP_IMAGE_TAG` | no | `latest` |
| `TZ` | no | `Africa/Cairo` |

## Deploy

Dokploy project `AI - Home Lab`, repository `EngAbo3lia/dev-workspace`, branch
`main`.

- Compose `dev-workspace` (code-server): compose path `./docker-compose.yml`,
  domain `code.aboalia.com` → `code-server:8080`.
- Compose `warp-terminal`: compose path `./warp/docker-compose.yml`, domain
  `warp.aboalia.com` → `warp-terminal:7681`.

Both domains use `https: false`, `certificateType: none`, `path: /`; TLS
terminates at Cloudflare and the tunnel speaks plain HTTP to Traefik.

Tunnel ingress for both hostnames targets `http://192.168.8.200`.

## Building the Warp image

Push to `main` touching `warp/**`, or run the `warp-image` workflow manually.
The workflow pushes `ghcr.io/engabo3lia/dev-workspace-warp:latest` and
`:<commit-sha>`. The GHCR package must be public so Dokploy can pull it without
registry credentials.

`WARP_REF` pins the upstream commit. Bump it, rebuild, then redeploy the Warp
compose.

## Access

1. Cloudflare Access self-hosted apps gate both hostnames (owner email, 24h).
2. `code.aboalia.com` asks for the code-server password.
3. `warp.aboalia.com` asks for the ttyd basic-auth credentials.

## Operations

```bash
docker logs -f <stack>-code-server-1
docker logs -f <stack>-warp-terminal-1
docker restart <stack>-warp-terminal-1
```

Data:

- `/srv/dev-workspace` — shared files, the only irreplaceable data. Back it up.
- `code_data` volume — editor settings and extensions.
- `warp_home` volume — Warp credentials and session state.

## Limits

- `ttyd` serves one shared terminal process; no per-user isolation.
- No Docker socket and no host bind mounts other than the workspace directory.
- `warp-tui-oss` is the OSS channel build; some desktop Warp features are absent.
