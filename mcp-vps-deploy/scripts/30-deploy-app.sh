#!/usr/bin/env bash
# 30-deploy-app.sh - Récupère le code du MCP depuis GitHub et le met en route avec pm2.
# À exécuter SUR le VPS, EN TANT QUE le compte système dédié (PAS root) :
#   sudo -u "$MCP_ACCOUNT" -i bash 30-deploy-app.sh
# Variables attendues :
#   MCP_REPO   URL GitHub du MCP (ex. https://github.com/groupe3/mon-mcp.git)
#   MCP_PORT   port localhost sur lequel le MCP doit écouter (ex. 3101)
#   APP_NAME   nom court du service pm2 (ex. mcp-unipile-groupe3)
#   START_CMD  (optionnel) commande de démarrage si elle n'est pas déductible
set -euo pipefail

log()  { printf '\n\033[1;34m[DEPLOY]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  [OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  [INFO]\033[0m %s\n' "$*"; }

: "${MCP_REPO:?Il faut fournir MCP_REPO (URL GitHub du MCP)}"
: "${MCP_PORT:?Il faut fournir MCP_PORT (le port localhost, ex. 3101)}"
: "${APP_NAME:?Il faut fournir APP_NAME (le nom du service, ex. mcp-unipile-groupe3)}"

if [ "$(id -u)" = "0" ]; then
  printf '\033[1;31m[STOP]\033[0m Ce script doit tourner sous le compte dédié, pas en root.\n'
  exit 1
fi

app_dir="$HOME/apps/$APP_NAME"
mkdir -p "$HOME/apps"

log "Récupération du code depuis GitHub"
if [ -d "$app_dir/.git" ]; then
  git -C "$app_dir" pull --ff-only
  ok "Code mis à jour dans $app_dir."
else
  git clone "$MCP_REPO" "$app_dir"
  ok "Code cloné dans $app_dir."
fi
cd "$app_dir"

# --- Détection du langage (la "stack") ---
stack="inconnu"
if [ -f package.json ]; then stack="node"; fi
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then stack="python"; fi
log "Langage détecté : $stack"

log "Fichier de configuration (.env)"
if [ ! -f .env ]; then
  if   [ -f .env.example ]; then cp .env.example .env; warn "Créé à partir de .env.example."
  elif [ -f .env.sample  ]; then cp .env.sample  .env; warn "Créé à partir de .env.sample."
  else touch .env; warn ".env vide créé."
  fi
fi
# Force le port d'écoute (en localhost) demandé.
if grep -q '^PORT=' .env; then
  sed -i "s/^PORT=.*/PORT=$MCP_PORT/" .env
else
  printf 'PORT=%s\n' "$MCP_PORT" >> .env
fi
if grep -q '^HOST=' .env; then sed -i "s/^HOST=.*/HOST=127.0.0.1/" .env; fi
ok "Port d'écoute réglé sur $MCP_PORT."
warn "Les clés secrètes (Unipile, etc.) doivent être complétées dans $app_dir/.env"

# --- Installation des dépendances + commande de démarrage ---
run_cmd=""
case "$stack" in
  node)
    log "Installation des dépendances Node"
    if [ -f package-lock.json ]; then npm ci || npm install; else npm install; fi
    ok "Dépendances installées."
    if [ -n "${START_CMD:-}" ]; then
      run_cmd="$START_CMD"
    elif node -e "process.exit(require('./package.json').scripts && require('./package.json').scripts.start ? 0 : 1)" 2>/dev/null; then
      run_cmd="npm -- start"   # via pm2 : pm2 start npm --name X -- start
    else
      for f in server.js index.js src/server.js src/index.js dist/index.js; do
        [ -f "$f" ] && { run_cmd="node $f"; break; }
      done
    fi
    ;;
  python)
    log "Création de l'environnement Python (venv) + dépendances"
    python3 -m venv .venv
    ./.venv/bin/pip install --upgrade pip >/dev/null
    if   [ -f requirements.txt ]; then ./.venv/bin/pip install -r requirements.txt
    elif [ -f pyproject.toml   ]; then ./.venv/bin/pip install .
    fi
    ok "Dépendances installées."
    if [ -n "${START_CMD:-}" ]; then
      run_cmd="$START_CMD"
    fi
    ;;
esac

if [ -z "$run_cmd" ]; then
  printf '\033[1;31m[ACTION REQUISE]\033[0m Impossible de deviner la commande qui démarre ton MCP.\n'
  printf 'Relance ce script en fournissant START_CMD, par ex. :\n'
  printf '    START_CMD="node server.js"          (Node)\n'
  printf '    START_CMD="./.venv/bin/python -m mon_mcp"   (Python)\n'
  exit 2
fi

log "Démarrage du MCP avec pm2 (service : $APP_NAME)"
pm2 delete "$APP_NAME" >/dev/null 2>&1 || true
# Cas spécial : "npm -- start" doit être lancé comme `pm2 start npm -- start`.
if [ "$run_cmd" = "npm -- start" ]; then
  pm2 start npm --name "$APP_NAME" -- start
else
  # shellcheck disable=SC2086
  pm2 start $run_cmd --name "$APP_NAME"
fi
pm2 save
ok "MCP lancé et sauvegardé (il redémarrera tout seul)."

echo
printf '\033[1;32m=== MCP en route sur 127.0.0.1:%s (service pm2 "%s"). ===\033[0m\n' "$MCP_PORT" "$APP_NAME"
printf 'Vérifie ses logs au besoin :  pm2 logs %s\n' "$APP_NAME"
