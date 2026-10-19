#!/usr/bin/env bash
set -euo pipefail

: "${TTYD_USER:?TTYD_USER is required}"
: "${TTYD_PASSWORD:?TTYD_PASSWORD is required}"

# ttyd terminates HTTP basic auth and gives the Warp TUI a writable pty.
exec ttyd \
  --port 7681 \
  --interface 0.0.0.0 \
  --writable \
  --max-clients "${TTYD_MAX_CLIENTS:-4}" \
  --credential "${TTYD_USER}:${TTYD_PASSWORD}" \
  --client-option disableLeaveAlert=true \
  /opt/warp/warp-tui-oss
