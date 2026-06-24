#!/usr/bin/env bash
# 00-precheck.sh - Vérifie que le VPS est prêt avant de commencer.
# À exécuter SUR le VPS. Variables attendues : MCP_DNS (nom DNS public).
set -euo pipefail

log()  { printf '\n\033[1;34m[VÉRIF]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  [OK]\033[0m %s\n' "$*"; }
ko()   { printf '\033[1;31m  [PROBLÈME]\033[0m %s\n' "$*"; }

: "${MCP_DNS:?Il faut fournir MCP_DNS (le nom DNS public, ex. mcp-unipile-groupe3.deers.fr)}"
fail=0

log "1/4 Système d'exploitation"
if [ -r /etc/os-release ] && . /etc/os-release && [ "${ID:-}" = "ubuntu" ]; then
  ok "Ubuntu détecté (${PRETTY_NAME:-Ubuntu})."
else
  ko "Ce n'est pas un Ubuntu. Le plugin est prévu pour Ubuntu."; fail=1
fi

log "2/4 Droits administrateur (sudo)"
if [ "$(id -u)" = "0" ]; then
  ok "Tu es connecté en root (administrateur)."
elif sudo -n true 2>/dev/null || sudo -v 2>/dev/null; then
  ok "Tu peux utiliser sudo (droits administrateur)."
else
  ko "Pas de droits administrateur. Il faut root ou un compte avec sudo."; fail=1
fi

log "3/4 Accès à Internet"
if curl -fsS --max-time 10 https://deb.debian.org >/dev/null 2>&1 \
   || curl -fsS --max-time 10 https://www.google.com >/dev/null 2>&1; then
  ok "Le VPS accède bien à Internet."
else
  ko "Le VPS ne semble pas avoir accès à Internet."; fail=1
fi

log "4/4 Le nom DNS pointe-t-il vers CE serveur ?"
# Adresse IP publique de CE serveur :
my_ip="$(curl -fsS --max-time 10 https://api.ipify.org 2>/dev/null || curl -fsS --max-time 10 https://ifconfig.me 2>/dev/null || true)"
# Adresse vers laquelle pointe le nom DNS :
dns_ip="$(getent ahostsv4 "$MCP_DNS" 2>/dev/null | awk '{print $1; exit}')"
if [ -z "$dns_ip" ]; then
  dns_ip="$(getent hosts "$MCP_DNS" 2>/dev/null | awk '{print $1; exit}')"
fi
printf '  IP de ce VPS         : %s\n' "${my_ip:-inconnue}"
printf '  IP du nom %s : %s\n' "$MCP_DNS" "${dns_ip:-aucune}"
if [ -n "$dns_ip" ] && [ -n "$my_ip" ] && [ "$dns_ip" = "$my_ip" ]; then
  ok "Le nom DNS pointe bien vers ce VPS."
elif [ -z "$dns_ip" ]; then
  ko "Le nom DNS $MCP_DNS ne pointe vers aucune adresse. Demande a ton formateur de creer un enregistrement DNS (type A) vers ${my_ip:-cette IP du VPS}."; fail=1
else
  ko "Le nom DNS pointe vers $dns_ip, mais ce VPS est $my_ip. Tant que ce n'est pas corrigé, le certificat HTTPS échouera."; fail=1
fi

echo
if [ "$fail" = "0" ]; then
  printf '\033[1;32m=== Tout est bon, on peut continuer. ===\033[0m\n'
else
  printf '\033[1;31m=== Au moins un point est à corriger avant de continuer. ===\033[0m\n'
  exit 1
fi
