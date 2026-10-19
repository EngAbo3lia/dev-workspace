# dev-workspace

Browser development workspace for the Aboalia estate: the open-source **Warp TUI**
client served through `ttyd`, plus **code-server**, sharing one persistent
`/workspace` volume.

Deployed by Dokploy (project `AI - Home Lab`) behind the `Aboalia Server`
Cloudflare Tunnel, with Cloudflare Access in front of both hostnames.

## What "hosting Warp" means here

Warp has no server edition. The desktop app and the WASM web client both talk to
Warp's own backend, and the web client additionally expects a `warpUserHandoff()`
Firebase token from Warp's host React app, so it cannot be self-hosted. The only
piece that runs on your own infrastructure is the open-source terminal
front-end from [`warpdotdev/warp`](https://github.com/warpdotdev/warp):
`warp_tui` (crate `warp_tui`, binary `warp-tui-oss`).

This image builds that binary from a pinned commit, stages its bundled resources
(`script/prepare_bundled_resources`), and exposes it as a browser terminal.
Login uses Warp's device-authorization flow: the TUI prints a URL and code, you
open it on any machine, approve, and the session lands inside the container.

Agent runs and model calls still travel through Warp's services; only the shell
and workspace live on this host.

## Services

| Service | Port | Hostname | Auth |
|---------|------|----------|------|
| `warp-terminal` | 7681 | `warp.majra.dev` | ttyd basic auth + Cloudflare Access |
| `code-server` | 8080 | `code.majra.dev` | code-server password + Cloudflare Access |

Both containers run as uid 1000 and share the `dev_workspace` volume mounted at
`/workspace`, so a file created in the Warp shell is visible in the editor.

`workspace-init` runs once per deploy to set volume ownership, then exits; both
services wait for it (`service_completed_successfully`).

## Environment

| Variable | Required | Default | Notes |
|----------|----------|---------|-------|
| `TTYD_PASSWORD` | yes | — | ttyd basic-auth password |
| `CODE_SERVER_PASSWORD` | yes | — | code-server login password |
| `TTYD_USER` | no | `warp` | ttyd basic-auth user |
| `TTYD_MAX_CLIENTS` | no | `4` | concurrent terminal clients |
| `WARP_REF` | no | pinned commit | Git ref built from `warpdotdev/warp`; bump to upgrade |
| `CARGO_BUILD_JOBS` | no | `4` | limits build parallelism/RAM |
| `CODE_SERVER_VERSION` | no | `4.141.0` | image tag |
| `TZ` | no | `Africa/Cairo` | container timezone |

## Deploy

Dokploy compose `dev-workspace` in project `AI - Home Lab`, built from this
repository (`main`), compose path `./docker-compose.yml`.

Domain rules (Traefik behind the tunnel must serve plain HTTP):

| Host | Service | Port | https | certificateType |
|------|---------|------|-------|-----------------|
| `warp.majra.dev` | `warp-terminal` | `7681` | `false` | `none` |
| `code.majra.dev` | `code-server` | `8080` | `false` | `none` |

The Warp image build compiles the Warp workspace from source. Expect a long
first deploy (tens of minutes) and keep in mind Dokploy runs one build at a time.

## Access

1. Cloudflare Access self-hosted apps gate both hostnames (owner email, 24h
   session).
2. `warp.majra.dev` then asks for the ttyd basic-auth credentials.
3. `code.majra.dev` then asks for the code-server password.

## Operations

```bash
# logs
docker logs -f <stack>-warp-terminal-1
docker logs -f <stack>-code-server-1

# restart one service without rebuilding
docker restart <stack>-warp-terminal-1

# upgrade Warp: bump WARP_REF to a new commit on warpdotdev/warp, then redeploy
# upgrade code-server: bump CODE_SERVER_VERSION, then redeploy
```

Volumes:

- `dev_workspace` — shared files. Back this up; it is the only irreplaceable data.
- `warp_home` — Warp settings, credentials, session state.
- `code_data` — code-server settings and extensions.

Deleting `warp_home` logs the TUI out; deleting `code_data` resets the editor
and extensions.

## Limits

- ttyd serves a single shared terminal process; there is no per-user isolation.
  Treat both hostnames as single-owner tools.
- No Docker socket and no host bind mounts. The containers are unprivileged.
- `warp-tui-oss` is the OSS channel build; some Warp cloud features in the
  desktop app are not available in the TUI.
