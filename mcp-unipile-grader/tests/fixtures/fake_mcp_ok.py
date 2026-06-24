#!/usr/bin/env python3
# Faux serveur MCP stdio CONFORME pour tester test-conformite.sh.
# - lit l'account_id en arg CLI (--account-id)
# - parle JSON-RPC newline-delimited sur stdout, logs sur stderr
# - get_current_account renvoie l'account_id SANS appeler le reseau
import sys, json, argparse


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def send(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--account-id", required=True)
    args = ap.parse_args()
    account_id = args.account_id
    log("fake_mcp_ok demarre")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            log("ligne non-JSON ignoree")
            continue
        method = msg.get("method")
        mid = msg.get("id")
        if method == "initialize":
            send({"jsonrpc": "2.0", "id": mid, "result": {
                "protocolVersion": "2025-06-18",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "fake-mcp-ok", "version": "1.0.0"}}})
        elif method == "notifications/initialized":
            pass  # notification, pas de reponse
        elif method == "tools/list":
            send({"jsonrpc": "2.0", "id": mid, "result": {"tools": [
                {"name": "get_current_account",
                 "description": "Always call this first. Renvoie l'account_id de la session.",
                 "inputSchema": {"type": "object", "properties": {}}}]}})
        elif method == "tools/call":
            name = (msg.get("params") or {}).get("name")
            if name == "get_current_account":
                send({"jsonrpc": "2.0", "id": mid, "result": {
                    "content": [{"type": "text",
                                 "text": json.dumps({"account_id": account_id})}]}})
            else:
                send({"jsonrpc": "2.0", "id": mid,
                      "error": {"code": -32601, "message": "outil inconnu"}})
        else:
            if mid is not None:
                send({"jsonrpc": "2.0", "id": mid,
                      "error": {"code": -32601, "message": "methode inconnue"}})


if __name__ == "__main__":
    main()
