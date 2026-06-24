#!/usr/bin/env bash
#
# test-conformite.sh — Tests automatiques de conformité d'un serveur MCP Unipile.
#
# Deux transports supportés :
#   - HTTP (VPS, OAuth) : vérifications SANS authentification (santé, 401,
#     métadonnées OAuth, rejet PKCE plain).
#   - stdio (local, account_id en arg CLI) : handshake MCP sur stdin/stdout +
#     outil synthétique get_current_account, non-fuite de la clé org, flux propre.
#
# Les tests nécessitant une session authentifiée / de vraies creds Unipile
# (isolation de l'account_id, blocage DELETE, persistance des tokens) sont
# rappelés à la fin et doivent être faits manuellement ou par revue de code.
#
# Usage :
#   ./test-conformite.sh --http <URL>
#   ./test-conformite.sh --stdio "<commande>" [--account-id <id>]
#   ./test-conformite.sh <URL>                 # rétrocompat = --http <URL>
#
# Dépendances : bash ; curl + jq (mode HTTP) ; python3 (mode stdio).

set -u

MODE=""; TARGET=""; EXPECT_ACCOUNT_ID=""
usage() {
  echo "Usage :" >&2
  echo "  $0 --http <URL>                                # serveur MCP en HTTP (VPS)" >&2
  echo "  $0 --stdio \"<commande>\" [--account-id <id>]     # serveur MCP local en stdio" >&2
  echo "  $0 <URL>                                       # rétrocompat = --http <URL>" >&2
  exit 2
}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --http)  MODE="http";  TARGET="${2:-}"; shift 2 ;;
    --stdio) MODE="stdio"; TARGET="${2:-}"; shift 2 ;;
    --account-id) EXPECT_ACCOUNT_ID="${2:-}"; shift 2 ;;
    http://*|https://*) MODE="http"; TARGET="$1"; shift ;;  # rétrocompat URL nue
    -h|--help) usage ;;
    *) echo "Argument inconnu : $1" >&2; usage ;;
  esac
done
[[ -z "$MODE" || -z "$TARGET" ]] && usage

PASS=0
FAIL=0
GREEN=$'\e[32m'; RED=$'\e[31m'; YEL=$'\e[33m'; RST=$'\e[0m'

ok()   { echo "${GREEN}[PASS]${RST} $1"; PASS=$((PASS+1)); }
ko()   { echo "${RED}[FAIL]${RST} $1"; FAIL=$((FAIL+1)); }
warn() { echo "${YEL}[INFO]${RST} $1"; }

# ---------------------------------------------------------------------------
# Mode HTTP (comportement historique, inchangé)
# ---------------------------------------------------------------------------
run_http_tests() {
  for dep in curl jq; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      echo "Dépendance manquante : $dep (requis en mode HTTP)" >&2
      exit 2
    fi
  done
  echo "== Tests de conformité MCP Unipile (mode HTTP) =="
  echo "Cible : $BASE"
  echo

  # --- 4.2 / 10.2 : GET /health ---
  health="$(curl -s -m 10 "$BASE/health" 2>/dev/null)"
  if echo "$health" | jq -e '.status == "ok"' >/dev/null 2>&1; then
    ok "(4.2) GET /health répond status=ok"
  else
    ko "(4.2) GET /health ne répond pas status=ok (reçu : ${health:-<vide>})"
  fi

  # --- 3.10 : appel MCP sans auth -> 401 + WWW-Authenticate ---
  hdrs="$(curl -s -m 10 -D - -o /dev/null \
    -X POST "$BASE/" \
    -H 'Content-Type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' 2>/dev/null)"
  code="$(printf '%s' "$hdrs" | head -n1 | grep -oE '[0-9]{3}' | head -n1)"
  if [[ "$code" == "401" ]]; then
    ok "(3.10) Appel MCP sans auth -> 401"
    if printf '%s' "$hdrs" | grep -iq '^www-authenticate:.*[Bb]earer'; then
      ok "(3.10) En-tête WWW-Authenticate: Bearer présent"
    else
      ko "(3.10) En-tête WWW-Authenticate: Bearer ABSENT (la ré-auth auto de Claude ne se déclenchera pas)"
    fi
  else
    ko "(3.10) Appel MCP sans auth -> code $code attendu 401 (l'endpoint MCP est peut-être /mcp ; relancer en adaptant)"
  fi

  # --- 3.4 : métadonnées OAuth ---
  asmeta="$(curl -s -m 10 "$BASE/.well-known/oauth-authorization-server" 2>/dev/null)"
  if echo "$asmeta" | jq -e '.authorization_endpoint and .token_endpoint' >/dev/null 2>&1; then
    ok "(3.4) /.well-known/oauth-authorization-server expose authorization_endpoint + token_endpoint"
  else
    ko "(3.4) /.well-known/oauth-authorization-server incomplet ou absent"
  fi

  prmeta="$(curl -s -m 10 "$BASE/.well-known/oauth-protected-resource" 2>/dev/null)"
  if echo "$prmeta" | jq -e '.authorization_servers' >/dev/null 2>&1; then
    ok "(3.4) /.well-known/oauth-protected-resource présent"
  else
    ko "(3.4) /.well-known/oauth-protected-resource absent ou invalide"
  fi

  # --- 3.2 : PKCE S256 obligatoire (plain rejeté / non annoncé) ---
  methods="$(echo "$asmeta" | jq -r '.code_challenge_methods_supported // [] | join(",")' 2>/dev/null)"
  if [[ "$methods" == *"S256"* && "$methods" != *"plain"* ]]; then
    ok "(3.2) Métadonnées : S256 annoncé, plain NON annoncé"
  elif [[ "$methods" == *"plain"* ]]; then
    ko "(3.2) Métadonnées : 'plain' annoncé dans code_challenge_methods_supported -> non conforme"
  else
    warn "(3.2) code_challenge_methods_supported = '${methods:-<absent>}' — vérifier manuellement que S256 est requis"
  fi

  # Tentative active : /authorize avec method=plain doit être refusé
  plain_code="$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
    "$BASE/oauth/authorize?response_type=code&client_id=test&redirect_uri=http://localhost/cb&code_challenge=abc&code_challenge_method=plain&state=x" 2>/dev/null)"
  if [[ "$plain_code" =~ ^4 ]]; then
    ok "(3.2) /oauth/authorize avec code_challenge_method=plain rejeté (HTTP $plain_code)"
  else
    warn "(3.2) /oauth/authorize avec plain -> HTTP $plain_code (un client_id invalide peut aussi causer ce code ; vérifier manuellement)"
  fi
}

# ---------------------------------------------------------------------------
# Mode stdio (local, account_id en arg CLI)
# ---------------------------------------------------------------------------
run_stdio_tests() {
  local cmd="$1"; local expect_id="$2"
  echo "== Tests de conformité MCP Unipile (mode stdio) =="
  echo "Commande : $cmd"
  echo
  if ! command -v python3 >/dev/null 2>&1; then
    ko "(stdio) python3 requis pour le test stdio est absent"; return
  fi
  local summary
  summary="$(UNIPILE_API_KEY='SENTINEL_ORG_KEY_DO_NOT_LEAK' \
             UNIPILE_BASE_URL='http://127.0.0.1:1' \
             GRADER_CMD="$cmd" GRADER_EXPECT_ID="$expect_id" \
             python3 - <<'PY'
import os, sys, json, shlex, subprocess, threading

cmd = os.environ["GRADER_CMD"]
expect_id = os.environ.get("GRADER_EXPECT_ID", "")
sentinel = os.environ["UNIPILE_API_KEY"]
res = {"s1": False, "s2": False, "s3": False, "s3_value": "",
       "s4": True, "s5": True, "error": None}
try:
    proc = subprocess.Popen(shlex.split(cmd), stdin=subprocess.PIPE,
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
except Exception as e:
    res["error"] = "lancement impossible: %s" % e
    print(json.dumps(res)); sys.exit(0)

def writemsg(obj):
    proc.stdin.write(json.dumps(obj) + "\n"); proc.stdin.flush()

lines = []
def reader():
    for ln in proc.stdout:
        lines.append(ln.rstrip("\n"))
t = threading.Thread(target=reader, daemon=True); t.start()

try:
    writemsg({"jsonrpc":"2.0","id":1,"method":"initialize",
              "params":{"protocolVersion":"2025-06-18","capabilities":{},
                        "clientInfo":{"name":"grader","version":"1.0"}}})
    writemsg({"jsonrpc":"2.0","method":"notifications/initialized"})
    writemsg({"jsonrpc":"2.0","id":2,"method":"tools/list"})
    writemsg({"jsonrpc":"2.0","id":3,"method":"tools/call",
              "params":{"name":"get_current_account","arguments":{}}})
except Exception as e:
    res["error"] = "ecriture impossible: %s" % e
    print(json.dumps(res)); sys.exit(0)

t.join(timeout=10)
try: proc.terminate()
except Exception: pass

byid = {}
for ln in lines:
    s = ln.strip()
    if not s:
        continue
    try:
        obj = json.loads(s)
    except json.JSONDecodeError:
        res["s5"] = False  # bruit non-JSON sur stdout
        continue
    if isinstance(obj, dict) and "id" in obj:
        byid[obj["id"]] = obj

res["s1"] = 1 in byid and "result" in byid[1]
tools = (((byid.get(2) or {}).get("result")) or {}).get("tools") or []
res["s2"] = any(t.get("name") == "get_current_account" for t in tools)
call = byid.get(3) or {}
acc = ""
content = ((call.get("result") or {}).get("content")) or []
for c in content:
    if c.get("type") == "text":
        try: acc = json.loads(c["text"]).get("account_id", "") or acc
        except Exception:
            if c["text"].strip(): acc = c["text"].strip()
res["s3_value"] = acc
res["s3"] = bool(acc) and (expect_id == "" or acc == expect_id)
if sentinel in "\n".join(lines):
    res["s4"] = False

def b(v):
    return "true" if v else "false"
# Sortie clé=valeur (pas de dépendance jq côté bash). s3_value sur une seule ligne.
out = ["s1=" + b(res["s1"]), "s2=" + b(res["s2"]), "s3=" + b(res["s3"]),
       "s3_value=" + res["s3_value"].replace("\n", " "),
       "s4=" + b(res["s4"]), "s5=" + b(res["s5"]),
       "error=" + (res["error"] or "")]
print("\n".join(out))
PY
)"
  _stdio_report "$summary" "$expect_id"
}

_stdio_report() {
  local summary="$1"; local expect_id="$2"
  local s1="" s2="" s3="" s3v="" s4="" s5="" err="" k v
  while IFS='=' read -r k v; do
    case "$k" in
      s1) s1="$v" ;; s2) s2="$v" ;; s3) s3="$v" ;;
      s3_value) s3v="$v" ;; s4) s4="$v" ;; s5) s5="$v" ;; error) err="$v" ;;
    esac
  done <<< "$summary"
  if [[ -z "$summary" || -n "$err" ]]; then
    ko "(stdio) dialogue MCP échoué : ${err:-aucune sortie du serveur}"
    return
  fi
  [[ "$s1" == "true" ]] && ok "(S.C/10.2) Le serveur répond à initialize sur stdio" \
                         || ko "(S.C/10.2) Pas de réponse valide à initialize"
  [[ "$s2" == "true" ]] && ok "(1.5) tools/list contient l'outil get_current_account" \
                         || ko "(1.5) get_current_account absent de tools/list"
  if [[ "$s3" == "true" ]]; then
    ok "(1.5) get_current_account renvoie un account_id ('${s3v}') hors-ligne (pas d'appel Unipile)"
  elif [[ -n "$s3v" && -n "$expect_id" ]]; then
    ko "(1.5) get_current_account renvoie '${s3v}' au lieu de l'attendu '${expect_id}'"
  else
    ko "(1.5) get_current_account ne renvoie pas d'account_id exploitable hors-ligne"
  fi
  [[ "$s4" == "true" ]] && ok "(1.4/8.3) La clé org n'apparaît pas dans les réponses stdout" \
                         || ko "(1.4/8.3) La clé org FUIT dans les réponses stdout"
  [[ "$s5" == "true" ]] && ok "(S.B) stdout ne contient que du JSON-RPC (logs sur stderr)" \
                         || ko "(S.B) stdout pollué par du non-JSON (logs à mettre sur stderr)"
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
if [[ "$MODE" == "http" ]]; then
  BASE="${TARGET%/}"
  run_http_tests
else
  run_stdio_tests "$TARGET" "$EXPECT_ACCOUNT_ID"
fi

echo
echo "== Résultat automatique : ${GREEN}$PASS PASS${RST} / ${RED}$FAIL FAIL${RST} =="
echo

if [[ "$MODE" == "http" ]]; then
echo "== À vérifier MANUELLEMENT (non couvert par ce script) =="
cat <<'EOF'
  [ ] (1.4) La clé d'API de l'org n'est JAMAIS renvoyée au client (inspecter les réponses d'outils)
  [ ] (1.5) Outil synthétique get_current_account présent et répond sans appeler Unipile
  [ ] (2.2) account_id FORCÉ : passer un account_id étranger -> doit être écrasé par celui de la session
  [ ] (2.3) GET /api/v1/accounts réécrit vers le seul compte de la session
  [ ] (2.4) DELETE /api/v1/accounts... bloqué
  [ ] (2.5) Garde SSRF sur l'hôte Unipile (UNIPILE_BASE_URL validé)
  [ ] (3.6) Vérification de l'account_id auprès d'Unipile avant émission du code
  [ ] (3.11) Header X-Unipile-Account-Id supporté (mode Claude Desktop)
  [ ] (3.13-3.16) Tokens TTL 30j, persistés sur disque, rechargés/purgés
  [ ] (5.2) Purge des sessions MCP inactives
  [ ] (8.1) Limite de payload ; (8.3) secrets jamais loggés
EOF
else
echo "== À vérifier MANUELLEMENT en stdio (nécessite de vraies creds Unipile) =="
cat <<'EOF'
  [ ] (2.2) account_id FORCÉ : un account_id étranger dans un appel doit être écrasé
  [ ] (2.3) liste des comptes réécrite vers le seul compte de session
  [ ] (2.4) DELETE compte bloqué
  [ ] (2.5) garde SSRF sur l'hôte Unipile (UNIPILE_BASE_URL validé)
  [ ] (1.2/1.3) relais réel tools/list + tools/call vers Unipile
  [ ] (6.1/6.2) séquence d'init MCP upstream + parsing SSE/JSON
EOF
fi

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
