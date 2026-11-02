#!/usr/bin/env sh
set -eu
# --no-access-log: token-in-path variant (/mcp/<token>) sa nesmie zapisovať do access logu.
exec uvicorn vault_mcp.server:app --host 0.0.0.0 --port "${PORT:-8000}" --proxy-headers --forwarded-allow-ips='*' --no-access-log
