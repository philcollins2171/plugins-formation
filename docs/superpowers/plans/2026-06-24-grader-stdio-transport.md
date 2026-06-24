# Grader MCP Unipile - Transport stdio - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre au grader `mcp-unipile-grader` de vérifier un serveur MCP Unipile en transport stdio (local, account_id en arg CLI) en plus du mode HTTP existant, via un flag explicite `--stdio`.

**Architecture:** On étend `scripts/test-conformite.sh` avec un parsing de flags (`--http` / `--stdio` / `--account-id`) ; la branche stdio délègue le dialogue JSON-RPC newline-delimited à un helper `python3` embarqué qui lance le sous-process avec `UNIPILE_BASE_URL` injoignable, fait le handshake MCP, applique les assertions S1-S5 et renvoie un résumé JSON que bash transforme en PASS/FAIL via les fonctions `ok`/`ko` existantes. La doc (commande, spec, SKILL) est mise à jour.

**Tech Stack:** Bash, python3 (dialogue stdio), curl + jq (mode HTTP, inchangé). Tests via une fixture python (faux serveur MCP stdio).

## Global Constraints

- Le mode HTTP existant (`--http <URL>` et la rétrocompat `<URL>` nue) DOIT rester inchangé dans son comportement.
- Dépendances : mode HTTP = bash/curl/jq ; mode stdio = bash/python3. Ne pas introduire d'autre dépendance.
- Pas de tiret cadratin (—) dans le code ou la doc générés (préférence utilisateur).
- Le transport stdio MCP est newline-delimited (un message JSON-RPC par ligne) ; pas de framing Content-Length.
- Sentinelles de test : clé org = `SENTINEL_ORG_KEY_DO_NOT_LEAK`, `UNIPILE_BASE_URL` injoignable = `http://127.0.0.1:1`.
- Les assertions automatiques stdio sont S1 (répond à initialize), S2 (tools/list contient get_current_account), S3 (get_current_account renvoie un account_id non vide hors-ligne, valeur exacte si `--account-id`), S4 (clé org absente de stdout), S5 (stdout = JSON-RPC pur).

---

### Task 1: Fixtures de test (faux serveurs MCP stdio)

Crée les fixtures qui serviront à tester le script. Un serveur "conforme" (passe S1-S5) et un serveur "fautif" (échoue sur des points précis).

**Files:**
- Create: `mcp-unipile-grader/tests/fixtures/fake_mcp_ok.py`
- Create: `mcp-unipile-grader/tests/fixtures/fake_mcp_bad.py`
- Create: `mcp-unipile-grader/tests/run-tests.sh`

**Interfaces:**
- Produces: `fake_mcp_ok.py` et `fake_mcp_bad.py`, lancés via `python3 <fixture> --account-id <id>`. `run-tests.sh` = lanceur de la suite de tests du plugin (sera enrichi en Task 4).

- [ ] **Step 1: Écrire la fixture conforme**

`mcp-unipile-grader/tests/fixtures/fake_mcp_ok.py` : un serveur MCP stdio minimal, conforme.

```python
#!/usr/bin/env python3
# Faux serveur MCP stdio CONFORME pour tester test-conformite.sh.
# - lit l'account_id en arg CLI (--account-id)
# - parle JSON-RPC newline-delimited sur stdout, logs sur stderr
# - get_current_account renvoie l'account_id SANS appeler le réseau
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
```

- [ ] **Step 2: Écrire la fixture fautive**

`mcp-unipile-grader/tests/fixtures/fake_mcp_bad.py` : viole S2 (pas de `get_current_account`), S4 (fuite la clé org sur stdout) et S5 (écrit un log sur stdout).

```python
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
```

- [ ] **Step 3: Créer le lanceur de tests (squelette)**

`mcp-unipile-grader/tests/run-tests.sh` : squelette qui sera complété en Task 4.

```bash
#!/usr/bin/env bash
# Suite de tests du grader mcp-unipile-grader.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/test-conformite.sh"
FIX="$HERE/fixtures"
PASS=0; FAIL=0
check() { # check "<desc>" <expected_exit> "<cmd...>"
  local desc="$1"; shift
  local want="$1"; shift
  "$@" >/tmp/grader_test_out 2>&1; local got=$?
  if [[ "$got" == "$want" ]]; then echo "[OK]   $desc"; PASS=$((PASS+1));
  else echo "[FAIL] $desc (exit $got attendu $want)"; cat /tmp/grader_test_out; FAIL=$((FAIL+1)); fi
}
echo "== Tests grader =="
# (cas de test ajoutes en Task 4)
echo "Resultat : $PASS OK / $FAIL FAIL"
[[ $FAIL -eq 0 ]]
```

- [ ] **Step 4: Rendre exécutables et vérifier la fixture conforme manuellement**

Run:
```bash
cd mcp-unipile-grader
chmod +x tests/fixtures/fake_mcp_ok.py tests/fixtures/fake_mcp_bad.py tests/run-tests.sh
printf '%s\n%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | python3 tests/fixtures/fake_mcp_ok.py --account-id ABC123
```
Expected: deux lignes JSON sur stdout (résultat `initialize` puis `tools/list` contenant `get_current_account`), le log `fake_mcp_ok demarre` sur stderr.

- [ ] **Step 5: Commit**

```bash
git add mcp-unipile-grader/tests
git commit -m "test: fixtures faux serveurs MCP stdio pour le grader"
```

---

### Task 2: Parsing des flags dans test-conformite.sh

Ajoute le parsing `--http` / `--stdio` / `--account-id` avec rétrocompat URL nue, en isolant le mode HTTP existant dans une fonction. Aucune régression du mode HTTP.

**Files:**
- Modify: `mcp-unipile-grader/scripts/test-conformite.sh`

**Interfaces:**
- Produces: variables `MODE` (`http`|`stdio`), `TARGET` (URL ou commande), `EXPECT_ACCOUNT_ID` ; fonction `run_http_tests` contenant les tests curl actuels.

- [ ] **Step 1: Extraire les tests HTTP dans une fonction**

Dans `test-conformite.sh`, envelopper le bloc actuel (lignes des tests 4.2 à 3.2, soit l'actuel corps après le préambule) dans une fonction `run_http_tests` qui utilise la variable `BASE`. Ne pas changer la logique interne des tests.

```bash
run_http_tests() {
  echo "== Tests de conformité MCP Unipile (mode HTTP) =="
  echo "Cible : $BASE"
  echo
  # ... (corps existant inchangé : /health, 401, .well-known, PKCE) ...
}
```

- [ ] **Step 2: Remplacer le parsing d'arguments**

Remplacer le bloc actuel `BASE="${1:-}" ... BASE="${BASE%/}"` par :

```bash
MODE=""; TARGET=""; EXPECT_ACCOUNT_ID=""
usage() {
  echo "Usage :" >&2
  echo "  $0 --http <URL>                       # serveur MCP en HTTP (VPS)" >&2
  echo "  $0 --stdio \"<commande>\" [--account-id <id>]  # serveur MCP local en stdio" >&2
  echo "  $0 <URL>                              # rétrocompat = --http <URL>" >&2
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
```

- [ ] **Step 3: Brancher le dispatch en fin de script**

Remplacer l'appel direct aux tests par un dispatch. En mode http, définir `BASE` puis appeler `run_http_tests` ; en mode stdio, appeler `run_stdio_tests` (définie en Task 3).

```bash
if [[ "$MODE" == "http" ]]; then
  BASE="${TARGET%/}"
  run_http_tests
else
  run_stdio_tests "$TARGET" "$EXPECT_ACCOUNT_ID"
fi

echo
echo "== Résultat automatique : ${GREEN}$PASS PASS${RST} / ${RED}$FAIL FAIL${RST} =="
```
Déplacer aussi le bloc « À vérifier MANUELLEMENT » pour qu'il s'affiche selon le mode (Task 3 fournit la version stdio). Pour cette task, garder le bloc manuel HTTP sous une garde `if [[ "$MODE" == "http" ]]`.

- [ ] **Step 4: Vérifier la non-régression HTTP (usage + rétrocompat)**

Run:
```bash
cd mcp-unipile-grader
bash scripts/test-conformite.sh 2>&1 | head -3        # doit afficher l'usage (exit 2)
bash scripts/test-conformite.sh --http http://127.0.0.1:1 2>&1 | head -2  # mode http, cible injoignable
```
Expected: 1er appel affiche l'usage avec les 3 formes ; 2e appel lance les tests HTTP (des FAIL car injoignable, mais le script s'exécute en mode http).

- [ ] **Step 5: Commit**

```bash
git add mcp-unipile-grader/scripts/test-conformite.sh
git commit -m "feat: parsing flags --http/--stdio dans test-conformite.sh"
```

---

### Task 3: Branche stdio (helper python3 + assertions S1-S5)

Implémente `run_stdio_tests` : lance le serveur via le helper python3 embarqué, fait le handshake MCP, applique S1-S5, et émet PASS/FAIL.

**Files:**
- Modify: `mcp-unipile-grader/scripts/test-conformite.sh`

**Interfaces:**
- Consumes: fonctions `ok`/`ko`/`warn`, variables `PASS`/`FAIL`, `EXPECT_ACCOUNT_ID`.
- Produces: fonction `run_stdio_tests "<commande>" "<expect_account_id>"`. Le helper python écrit sur stdout un JSON `{"s1":bool,"s2":bool,"s3":bool,"s3_value":str,"s4":bool,"s5":bool,"error":str|null}`.

- [ ] **Step 1: Écrire `run_stdio_tests` avec le helper python embarqué**

Ajouter dans `test-conformite.sh` (avant le dispatch) :

```bash
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
print(json.dumps(res))
PY
)"
  _stdio_report "$summary" "$expect_id"
}
```

- [ ] **Step 2: Écrire `_stdio_report` (traduction JSON -> PASS/FAIL)**

Ajouter juste après :

```bash
_stdio_report() {
  local summary="$1"; local expect_id="$2"
  local err; err="$(printf '%s' "$summary" | jq -r '.error // empty' 2>/dev/null)"
  if [[ -z "$summary" || -n "$err" ]]; then
    ko "(stdio) dialogue MCP échoué : ${err:-aucune sortie du serveur}"
    return
  fi
  local s1 s2 s3 s3v s4 s5
  s1="$(printf '%s' "$summary" | jq -r '.s1')"
  s2="$(printf '%s' "$summary" | jq -r '.s2')"
  s3="$(printf '%s' "$summary" | jq -r '.s3')"
  s3v="$(printf '%s' "$summary" | jq -r '.s3_value')"
  s4="$(printf '%s' "$summary" | jq -r '.s4')"
  s5="$(printf '%s' "$summary" | jq -r '.s5')"
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
```

- [ ] **Step 3: Ajouter le rappel manuel stdio**

Dans le dispatch (Task 2 step 3), sous une garde `if [[ "$MODE" == "stdio" ]]`, après le résultat :

```bash
if [[ "$MODE" == "stdio" ]]; then
echo
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
```

- [ ] **Step 4: Test manuel rapide contre les fixtures**

Run:
```bash
cd mcp-unipile-grader
bash scripts/test-conformite.sh --stdio "python3 tests/fixtures/fake_mcp_ok.py --account-id ABC123" --account-id ABC123
echo "---bad---"
bash scripts/test-conformite.sh --stdio "python3 tests/fixtures/fake_mcp_bad.py --account-id ABC123"
```
Expected: la fixture OK donne 5 PASS / 0 FAIL ; la fixture BAD donne au moins 3 FAIL (S2 get_current_account absent, S4 clé qui fuit, S5 stdout pollué).

- [ ] **Step 5: Commit**

```bash
git add mcp-unipile-grader/scripts/test-conformite.sh
git commit -m "feat: branche stdio (handshake MCP + assertions S1-S5) dans le grader"
```

---

### Task 4: Suite de tests automatisée

Complète `run-tests.sh` pour valider les deux fixtures, et l'usage. Donne un filet de sécurité reproductible.

**Files:**
- Modify: `mcp-unipile-grader/tests/run-tests.sh`

**Interfaces:**
- Consumes: `test-conformite.sh`, fixtures de Task 1.

- [ ] **Step 1: Ajouter les cas de test**

Remplacer la ligne `# (cas de test ajoutes en Task 4)` par :

```bash
# Usage sans argument -> exit 2
check "usage sans argument" 2 bash "$SCRIPT"

# Fixture conforme -> 0 FAIL (exit 0)
check "fixture OK = conforme" 0 bash "$SCRIPT" \
  --stdio "python3 $FIX/fake_mcp_ok.py --account-id ABC123" --account-id ABC123

# Fixture fautive -> au moins 1 FAIL (exit 1)
check "fixture BAD = non conforme" 1 bash "$SCRIPT" \
  --stdio "python3 $FIX/fake_mcp_bad.py --account-id ABC123"

# account_id attendu errone -> FAIL (exit 1)
check "account_id errone detecte" 1 bash "$SCRIPT" \
  --stdio "python3 $FIX/fake_mcp_ok.py --account-id ABC123" --account-id WRONG
```

- [ ] **Step 2: Lancer la suite**

Run:
```bash
cd mcp-unipile-grader && bash tests/run-tests.sh
```
Expected: `4 OK / 0 FAIL`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add mcp-unipile-grader/tests/run-tests.sh
git commit -m "test: suite automatisee du grader (usage + fixtures stdio)"
```

---

### Task 5: Documentation (commande, spec, SKILL)

Met à jour la doc utilisateur pour refléter les deux modes.

**Files:**
- Modify: `mcp-unipile-grader/commands/test-mcp.md`
- Modify: `mcp-unipile-grader/skills/verifier-conformite-mcp-unipile/spec-mcp-unipile.md`
- Modify: `mcp-unipile-grader/skills/verifier-conformite-mcp-unipile/SKILL.md`

**Interfaces:**
- Consumes: comportement final de `test-conformite.sh` (Tasks 2-3).

- [ ] **Step 1: Mettre à jour `commands/test-mcp.md`**

- Remplacer l'`argument-hint` par : `--http <URL> | --stdio "<commande>" [--account-id <id>]`.
- Indiquer les deux invocations possibles et l'exécution :
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/test-conformite.sh <args>`.
- Préciser que le rapport doit indiquer **quelle grille** (HTTP ou stdio) a été appliquée, et qu'en stdio il faut rappeler les vérifications manuelles (2.2, 2.3, 2.4, 2.5, 1.2/1.3, 6.1/6.2).
- Pointer vers l'annexe B de `spec-mcp-unipile.md` pour la grille stdio.

- [ ] **Step 2: Ajouter l'« Annexe B - Variante transport stdio » à `spec-mcp-unipile.md`**

À la fin du fichier, ajouter une section qui reprend la grille réduite : exigences qui restent (1.1-1.5, 2.1-2.5, 6.1-6.2, 8.3, 9.1-9.2, 10.1), exigences spécifiques stdio (S.A account_id en arg CLI, S.B logs sur stderr, S.C répond à initialize), exigences caduques (3a OAuth, 3.11-3.16, section 4, 5.x, 8.1/8.2/8.4/8.6, 9.3/9.4, 10.2 remplacée par S.C), et une checklist cochable « stdio » avec la distinction auto (S1-S5) / manuel (2.2-2.5, 1.2/1.3, 6.1/6.2).

- [ ] **Step 3: Mettre à jour `SKILL.md`**

Dans « Procédure de vérification », mentionner les **deux modes de transport** : pour un serveur HTTP/VPS, lancer `/test-mcp --http <URL>` (grille complète) ; pour un serveur stdio local, lancer `/test-mcp --stdio "<commande>"` (grille réduite, annexe B). Renvoyer vers l'annexe B pour savoir quelles exigences s'appliquent.

- [ ] **Step 4: Vérifier la cohérence**

Run:
```bash
cd mcp-unipile-grader
grep -n "stdio" commands/test-mcp.md skills/verifier-conformite-mcp-unipile/SKILL.md
grep -n "Annexe B" skills/verifier-conformite-mcp-unipile/spec-mcp-unipile.md
```
Expected: chaque fichier référence bien le mode stdio / l'annexe B.

- [ ] **Step 5: Commit**

```bash
git add mcp-unipile-grader/commands/test-mcp.md mcp-unipile-grader/skills/verifier-conformite-mcp-unipile
git commit -m "docs: documenter le mode stdio (commande, spec annexe B, SKILL)"
```

---

### Task 6: Validation finale et push

- [ ] **Step 1: Relancer toute la suite**

Run:
```bash
cd mcp-unipile-grader && bash tests/run-tests.sh
```
Expected: `4 OK / 0 FAIL`.

- [ ] **Step 2: Vérifier la non-régression HTTP**

Run:
```bash
cd mcp-unipile-grader && bash scripts/test-conformite.sh --http http://127.0.0.1:1 2>&1 | head -3
```
Expected: le script s'exécute en mode HTTP (FAIL attendus car injoignable, mais aucune erreur de script).

- [ ] **Step 3: Push de la branche**

```bash
git push -u origin feat/grader-stdio-transport
```
Expected: la branche est poussée sur origin.
