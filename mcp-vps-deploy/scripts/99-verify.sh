#!/usr/bin/env bash
# 99-verify.sh - Vérifie que le MCP répond bien en HTTPS depuis l'extérieur.
# Peut être lancé depuis le VPS OU depuis ton ordinateur.
# Variables attendues :
#   MCP_DNS   nom DNS public (ex. mcp-unipile-groupe3.deers.fr)
#   APP_NAME  (optionnel) nom du service pm2, pour afficher son état
set -euo pipefail

log() { printf '\n\033[1;34m[TEST]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [OK]\033[0m %s\n' "$*"; }
ko()  { printf '\033[1;31m  [PROBLÈME]\033[0m %s\n' "$*"; }

: "${MCP_DNS:?Il faut fournir MCP_DNS}"

log "État du service pm2"
if command -v pm2 >/dev/null 2>&1; then
  pm2 list 2>/dev/null | grep -E "${APP_NAME:-mcp}" || pm2 list 2>/dev/null | head -20 || true
else
  echo "  (pm2 non disponible ici, test lancé à distance)"
fi

log "Appel HTTPS de https://$MCP_DNS/health"
code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "https://$MCP_DNS/health" || echo 000)"
if [ "$code" = "200" ]; then
  ok "Le MCP répond (HTTP $code) en HTTPS. 🎉"
elif [ "$code" = "000" ]; then
  ko "Aucune réponse. Vérifie le DNS, le pare-feu (80/443), et que NGINX tourne."
else
  ko "Réponse HTTP $code. Le MCP est joignable mais /health ne renvoie pas 200 : regarde 'pm2 logs ${APP_NAME:-<service>}'."
fi

log "Test du certificat HTTPS"
if curl -sS -o /dev/null --max-time 15 "https://$MCP_DNS/health" 2>/dev/null; then
  ok "Certificat HTTPS valide."
else
  ko "Problème de certificat HTTPS (relance l'étape NGINX/certbot)."
fi

echo
printf '\033[1;36mÉtape suivante recommandée :\033[0m vérifie la conformité du MCP avec le plugin grader :\n'
printf '    /test-mcp --http https://%s\n' "$MCP_DNS"
