"""Token auth and wiring of the vault MCP server (offline, via ASGI)."""

from __future__ import annotations

import asyncio
import json

from vault_mcp.server import TokenAuth


async def _ok_app(scope, receive, send):
    await send({"type": "http.response.start", "status": 200, "headers": []})
    await send({"type": "http.response.body", "body": scope["path"].encode()})


def _call(app, path, headers=()):
    sent = []

    async def receive():
        return {"type": "http.request", "body": b""}

    async def send(msg):
        sent.append(msg)

    scope = {"type": "http", "path": path, "raw_path": path.encode(), "headers": list(headers)}
    asyncio.run(app(scope, receive, send))
    return sent[0]["status"], sent[1]["body"]


def test_healthz_open_and_token_required():
    app = TokenAuth(_ok_app, "s3cret")
    status, body = _call(app, "/healthz")
    assert status == 200 and json.loads(body)["service"] == "vault-mcp"
    assert _call(app, "/mcp")[0] == 404
    assert _call(app, "/mcp/wrong")[0] == 404
    assert _call(app, "/mcp", [(b"authorization", b"Bearer wrong")])[0] == 404
    assert _call(app, "/other")[0] == 404


def test_token_in_path_is_stripped_and_bearer_works():
    app = TokenAuth(_ok_app, "s3cret")
    assert _call(app, "/mcp/s3cret") == (200, b"/mcp")
    assert _call(app, "/mcp", [(b"authorization", b"Bearer s3cret")]) == (200, b"/mcp")


def test_missing_token_refuses_everything():
    assert _call(TokenAuth(_ok_app, ""), "/mcp")[0] == 503
