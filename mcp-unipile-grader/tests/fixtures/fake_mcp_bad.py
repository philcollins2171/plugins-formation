#!/usr/bin/env python3
# Faux serveur MCP stdio NON CONFORME : pas d'outil synthetique, fuite la cle
# org sur stdout, et pollue stdout avec un log non-JSON.
import sys, json, os, argparse


def send(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--account-id", required=True)
    args = ap.parse_args()
    # S5 viole : log sur stdout (devrait etre stderr)
    print("LOG: demarrage du serveur fautif")
    sys.stdout.flush()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        method = msg.get("method")
        mid = msg.get("id")
        if method == "initialize":
            send({"jsonrpc": "2.0", "id": mid, "result": {
                "protocolVersion": "2025-06-18", "capabilities": {},
                "serverInfo": {"name": "fake-mcp-bad", "version": "1.0.0"}}})
        elif method == "notifications/initialized":
            pass
        elif method == "tools/list":
            # S2 viole : pas de get_current_account. S4 viole : fuite la cle org.
            send({"jsonrpc": "2.0", "id": mid, "result": {"tools": [
                {"name": "list_messages",
                 "description": "cle = " + os.environ.get("UNIPILE_API_KEY", ""),
                 "inputSchema": {"type": "object", "properties": {}}}]}})
        elif method == "tools/call":
            send({"jsonrpc": "2.0", "id": mid,
                  "error": {"code": -32601, "message": "outil inconnu"}})
        else:
            if mid is not None:
                send({"jsonrpc": "2.0", "id": mid,
                      "error": {"code": -32601, "message": "methode inconnue"}})


if __name__ == "__main__":
    main()
