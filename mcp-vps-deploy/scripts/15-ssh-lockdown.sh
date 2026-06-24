#!/usr/bin/env bash
# 15-ssh-lockdown.sh - Ferme le port SSH standard (22) APRÈS avoir vérifié la reconnexion.
# À exécuter SUR le VPS en root (ou sudo), depuis une session ouverte sur le port custom.
# Variables attendues : SSH_PORT (port SSH custom, défaut 22242).
set -euo pipefail

log() { printf '\n\033[1;34m[SÉCU]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [OK]\033[0m %s\n' "$*"; }

SSH_PORT="${SSH_PORT:-22242}"
if [ "$(id -u)" = "0" ]; then SUDO=""; else SUDO="sudo"; fi

# Garde-fou : on refuse de fermer le 22 si la session courante passe encore par lui.
current_port="$(echo "${SSH_CONNECTION:-}" | awk '{print $4}')"
if [ "${current_port:-}" = "22" ]; then
  printf '\033[1;31m[STOP]\033[0m Tu es connecté par le port 22. Reconnecte-toi d'\''abord sur le port %s, sinon tu vas te verrouiller dehors.\n' "$SSH_PORT"
  exit 1
fi

log "Retrait du port 22 de la configuration SSH"
ssh_drop="/etc/ssh/sshd_config.d/99-mcp-hardening.conf"
$SUDO tee "$ssh_drop" >/dev/null <<EOF
# Posé par mcp-vps-deploy (15-ssh-lockdown.sh)
Port $SSH_PORT
PermitRootLogin prohibit-password
PubkeyAuthentication yes
PasswordAuthentication no
EOF
$SUDO sshd -t
$SUDO systemctl restart ssh 2>/dev/null || $SUDO systemctl restart sshd
ok "SSH n'écoute plus que sur le port $SSH_PORT."

log "Fermeture du port 22 dans le pare-feu"
$SUDO ufw delete allow 22/tcp >/dev/null 2>&1 || true
$SUDO ufw deny 22/tcp >/dev/null
ok "Port 22 bloqué."

echo
printf '\033[1;32m=== Le SSH est maintenant accessible uniquement sur le port %s. ===\033[0m\n' "$SSH_PORT"
