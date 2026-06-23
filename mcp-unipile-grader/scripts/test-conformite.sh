#!/usr/bin/env bash
#
# test-conformite.sh — Tests automatiques de conformité d'un serveur MCP Unipile.
#
# Couvre les vérifications SANS authentification (santé, 401, métadonnées OAuth,
# rejet PKCE plain). Les tests nécessitant une session authentifiée (isolation de
# l'account_id, blocage DELETE, persistance des tokens) sont rappelés à la fin et
# doivent être faits manuellement ou par revue de code.
#
# Usage :
#   ./test-conformite.sh https://mcp-linkedin.exemple.fr
#   ./test-conformite.sh http://localhost:3101
#
# Dépendances : bash, curl, jq.

set -u

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  echo "Usage : $0 <URL_DE_BASE_DU_SERVEUR>" >&2
  echo "Exemple : $0 http://localhost:3101" >&2
  exit 2
fi
BASE="${BASE%/}"  # retire le slash final éventuel

for dep in curl jq; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "Dépendance manquante : $dep" >&2
    exit 2
  fi
done

PASS=0
FAIL=0
GREEN=$'\e[32m'; RED=$'\e[31m'; YEL=$'\e[33m'; RST=$'\e[0m'

ok()   { echo "${GREEN}[PASS]${RST} $1"; PASS=$((PASS+1)); }
ko()   { echo "${RED}[FAIL]${RST} $1"; FAIL=$((FAIL+1)); }
warn() { echo "${YEL}[INFO]${RST} $1"; }

echo "== Tests de conformité MCP Unipile =="
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

echo
echo "== Résultat automatique : ${GREEN}$PASS PASS${RST} / ${RED}$FAIL FAIL${RST} =="
echo
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

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
