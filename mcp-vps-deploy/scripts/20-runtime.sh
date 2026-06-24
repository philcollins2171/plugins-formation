#!/usr/bin/env bash
# 20-runtime.sh - Installe de quoi faire tourner le MCP : Node.js, pm2, et Python.
# À exécuter SUR le VPS en root (ou sudo).
# Variables attendues :
#   MCP_ACCOUNT  compte système sous lequel pm2 démarrera au boot (ex. deploy)
set -euo pipefail

log() { printf '\n\033[1;34m[INSTALL]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [OK]\033[0m %s\n' "$*"; }

: "${MCP_ACCOUNT:?Il faut fournir MCP_ACCOUNT (le compte système, ex. deploy)}"
if [ "$(id -u)" = "0" ]; then SUDO=""; else SUDO="sudo"; fi
export DEBIAN_FRONTEND=noninteractive

log "Outils de base (git, curl)"
$SUDO apt-get install -y -qq git curl ca-certificates >/dev/null
ok "git et curl présents."

log "Node.js (LTS) - le moteur qui exécute la plupart des MCP"
if command -v node >/dev/null 2>&1; then
  ok "Node.js déjà installé ($(node -v))."
else
  curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash - >/dev/null 2>&1
  $SUDO apt-get install -y -qq nodejs >/dev/null
  ok "Node.js installé ($(node -v))."
fi

log "Python 3 + venv - pour les MCP écrits en Python"
$SUDO apt-get install -y -qq python3 python3-venv python3-pip >/dev/null
ok "Python prêt ($(python3 --version 2>&1))."

log "pm2 - le gardien qui relance le MCP s'il plante et au redémarrage du serveur"
if command -v pm2 >/dev/null 2>&1; then
  ok "pm2 déjà installé ($(pm2 -v))."
else
  $SUDO npm install -g pm2 >/dev/null 2>&1
  ok "pm2 installé ($(pm2 -v))."
fi

log "Démarrage automatique de pm2 au boot pour le compte '$MCP_ACCOUNT'"
# Génère et installe le service systemd qui relancera pm2 (et donc le MCP) au reboot.
home_dir="$(getent passwd "$MCP_ACCOUNT" | cut -d: -f6)"
startup_cmd="$($SUDO env PATH="$PATH" pm2 startup systemd -u "$MCP_ACCOUNT" --hp "$home_dir" 2>/dev/null | grep -E '^sudo ' | tail -n1 || true)"
if [ -n "$startup_cmd" ]; then
  eval "$startup_cmd" >/dev/null 2>&1 || true
fi
ok "pm2 redémarrera automatiquement au boot."

echo
printf '\033[1;32m=== Environnement d'\''exécution prêt. ===\033[0m\n'
