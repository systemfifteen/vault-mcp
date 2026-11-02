# vault-mcp

Read-only remote [MCP](https://modelcontextprotocol.io) server over Peter's Obsidian vault, so Claude
(claude.ai connector, Claude Code, Hermes) can look things up in the vault instead of asking Peter to
re-explain his projects. Deliberately separate from `zdroje-mcp`: its own token, its own connector,
personal data only here.

## Tools

| Tool | What it does |
|---|---|
| `vault_start(recent?)` | start note `AGENTS.md`, project overview `00 - Prehľad projektov`, folder tree, recently modified notes |
| `vault_search(query, folder?, limit?)` | case/diacritics-insensitive AND search over notes with line snippets; `incomplete: true` if not everything could be read |
| `vault_read(path, start_line?, end_line?, max_chars?)` | one note by path or wikilink name, with outgoing links and backlinks |

## Security model

- **Read-only**: nothing writes; the vault is bind-mounted read-only and the container runs as uid 1000.
- **Sandbox**: relative paths only, no `.`/`..`/empty/hidden segments; **symlinks are never served or
  traversed**; every read re-walks from a root directory descriptor with `O_NOFOLLOW` per component, so a
  file swapped for a symlink between listing and reading fails instead of escaping; only regular `.md`
  files (fstat), opened `O_NONBLOCK`.
- **Limits**: 1 MB per note, 30 MB per request, query ≤ 300 chars / 12 words, ≤ 200 links/backlinks;
  results that hit a limit are flagged (`incomplete`, `backlinks_incomplete`, `truncated`, `*_truncated`).
- **Errors** never contain absolute paths. Unicode NFC/NFD twin names → `ambiguous`, never a silent pick.
- `VAULT_EXCLUDE` hides folders/notes entirely (production: `Medrio`).
- Server instructions tell clients that note text is data, never authorization.
- Reviewed by Hermes 2026-11-02 (first review FAIL → fixes → re-review WARN, remaining items fixed here).

## Configuration

| Variable | Purpose |
|---|---|
| `MCP_TOKEN` | required; own long random secret. Production value: 1Password trezor `kocka`, rotated by `secret-rotation` (id `vault-mcp`) |
| `VAULT_DIR` | vault path inside the container, `/vault` |
| `VAULT_EXCLUDE` | comma-separated folders/notes to hide, e.g. `Medrio` |
| `PUBLIC_HOST` | allowed Host header (DNS-rebinding protection), default `vault.system15.win` |

Client URL: `https://vault.system15.win/mcp/<MCP_TOKEN>` (claude.ai custom connector) or
`https://vault.system15.win/mcp` with `Authorization: Bearer <MCP_TOKEN>`.

## Deploy (Coolify on kocka)

Coolify build pack **Docker Compose** (`docker-compose.yml`), domain `https://vault.system15.win` on service
`vault-mcp`, port 8000. The compose file bind-mounts the vault **read-only** (`:ro`), runs with a read-only
root filesystem, `cap_drop: ALL` and `no-new-privileges`. `MCP_TOKEN` is a runtime-only Coolify variable
managed by `secret-rotation` (id `vault-mcp`); Traefik access logging is disabled on the app's routers so the
token-in-path URL is never logged.

## Run locally

```bash
uv sync --extra dev
VAULT_DIR=/path/to/vault MCP_TOKEN=dev PUBLIC_HOST=localhost:8000 \
  uv run uvicorn vault_mcp.server:app --port 8000 --no-access-log
uv run pytest -q
```
