#!/usr/bin/env bash
# 40-nginx-certbot.sh - Met NGINX en façade (reverse proxy) et active le HTTPS.
# À exécuter SUR le VPS en root (ou sudo).
# Variables attendues :
#   MCP_DNS      nom DNS public (ex. mcp-unipile-groupe3.deers.fr)
#   MCP_PORT     port localhost du MCP (ex. 3101)
#   ADMIN_EMAIL  email pour Let's Encrypt (alertes d'expiration de certificat)
#   TEMPLATE     (optionnel) chemin du template nginx ; sinon cherché à côté du script
set -euo pipefail

log() { printf '\n\033[1;34m[WEB]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [OK]\033[0m %s\n' "$*"; }

: "${MCP_DNS:?Il faut fournir MCP_DNS}"
: "${MCP_PORT:?Il faut fournir MCP_PORT}"
: "${ADMIN_EMAIL:?Il faut fournir ADMIN_EMAIL (pour les alertes de certificat)}"
if [ "$(id -u)" = "0" ]; then SUDO=""; else SUDO="sudo"; fi
export DEBIAN_FRONTEND=noninteractive

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${TEMPLATE:-$script_dir/templates/nginx-mcp.conf.tmpl}"
[ -r "$TEMPLATE" ] || { echo "Template introuvable : $TEMPLATE"; exit 1; }

log "Installation de NGINX et certbot"
$SUDO apt-get install -y -qq nginx certbot python3-certbot-nginx >/dev/null
ok "NGINX et certbot installés."

log "Création du vhost reverse proxy pour $MCP_DNS"
vhost="/etc/nginx/sites-available/$MCP_DNS"
sed -e "s/__MCP_DNS__/$MCP_DNS/g" -e "s/__MCP_PORT__/$MCP_PORT/g" "$TEMPLATE" | $SUDO tee "$vhost" >/dev/null
$SUDO ln -sf "$vhost" "/etc/nginx/sites-enabled/$MCP_DNS"
# Évite le conflit avec le site par défaut sur le port 80.
$SUDO rm -f /etc/nginx/sites-enabled/default
$SUDO nginx -t
$SUDO systemctl reload nginx
ok "NGINX transmet maintenant $MCP_DNS vers 127.0.0.1:$MCP_PORT (en HTTP)."

log "Obtention du certificat HTTPS (Let's Encrypt) et passage en HTTPS"
# certbot modifie le vhost : ajoute le 443 + la redirection 80 -> 443 (--redirect).
$SUDO certbot --nginx -d "$MCP_DNS" \
  --non-interactive --agree-tos -m "$ADMIN_EMAIL" --redirect
$SUDO systemctl reload nginx
ok "HTTPS actif pour https://$MCP_DNS (renouvellement automatique du certificat)."

echo
printf '\033[1;32m=== %s est en ligne en HTTPS. ===\033[0m\n' "$MCP_DNS"
