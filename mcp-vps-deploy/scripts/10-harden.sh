#!/usr/bin/env bash
# 10-harden.sh - Sécurise le VPS (le "durcissement").
# À exécuter SUR le VPS en root (ou avec sudo).
# Reproduit la sécurité de app.deers.fr : compte dédié, pare-feu, fail2ban,
# SSH sur un port custom (le port 22 reste OUVERT ici, on le fermera à l'étape suivante
# une fois la reconnexion vérifiée, pour ne PAS risquer de se verrouiller dehors).
#
# Variables attendues :
#   MCP_ACCOUNT   compte système à créer (ex. deploy)
#   SSH_PORT      port SSH custom (défaut 22242)
#   ACCOUNT_PUBKEY (optionnel) clé publique SSH à autoriser pour ce compte
set -euo pipefail

log() { printf '\n\033[1;34m[SÉCU]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m  [OK]\033[0m %s\n' "$*"; }

: "${MCP_ACCOUNT:?Il faut fournir MCP_ACCOUNT (le compte système, ex. deploy)}"
SSH_PORT="${SSH_PORT:-22242}"

# Permet de tourner aussi bien en root qu'avec sudo.
if [ "$(id -u)" = "0" ]; then SUDO=""; else SUDO="sudo"; fi
export DEBIAN_FRONTEND=noninteractive

log "Mise à jour de la liste des paquets"
$SUDO apt-get update -y -qq
ok "Liste à jour."

log "Installation des outils de sécurité (pare-feu, fail2ban, mises à jour auto)"
$SUDO apt-get install -y -qq ufw fail2ban unattended-upgrades >/dev/null
ok "ufw, fail2ban, unattended-upgrades installés."

log "Création du compte système '$MCP_ACCOUNT'"
if id "$MCP_ACCOUNT" >/dev/null 2>&1; then
  ok "Le compte '$MCP_ACCOUNT' existe déjà."
else
  $SUDO adduser --disabled-password --gecos "" "$MCP_ACCOUNT"
  ok "Compte '$MCP_ACCOUNT' créé."
fi
$SUDO usermod -aG sudo "$MCP_ACCOUNT"
ok "Compte '$MCP_ACCOUNT' autorisé à administrer (sudo)."

log "Clé SSH du compte '$MCP_ACCOUNT' (connexion sans mot de passe)"
home_dir="$(getent passwd "$MCP_ACCOUNT" | cut -d: -f6)"
$SUDO install -d -m 700 -o "$MCP_ACCOUNT" -g "$MCP_ACCOUNT" "$home_dir/.ssh"
auth="$home_dir/.ssh/authorized_keys"
$SUDO touch "$auth"
# On reprend les clés déjà autorisées pour la session courante (root ou l'utilisateur
# qui lance le script), pour que l'étudiant garde son accès sur le nouveau compte.
for src in /root/.ssh/authorized_keys "$HOME/.ssh/authorized_keys"; do
  if [ -r "$src" ]; then
    $SUDO bash -c "cat '$src' >> '$auth'"
  fi
done
if [ -n "${ACCOUNT_PUBKEY:-}" ]; then
  echo "$ACCOUNT_PUBKEY" | $SUDO tee -a "$auth" >/dev/null
fi
# Déduplique et fixe les droits.
$SUDO bash -c "sort -u '$auth' -o '$auth'"
$SUDO chown "$MCP_ACCOUNT:$MCP_ACCOUNT" "$auth"
$SUDO chmod 600 "$auth"
key_count="$($SUDO bash -c "grep -c . '$auth'" || echo 0)"
ok "$key_count clé(s) SSH autorisée(s) pour '$MCP_ACCOUNT'."

log "Configuration SSH : ajout du port custom $SSH_PORT (le port 22 reste ouvert pour l'instant)"
ssh_drop="/etc/ssh/sshd_config.d/99-mcp-hardening.conf"
$SUDO mkdir -p /etc/ssh/sshd_config.d
# On écoute sur 22 ET le port custom : on ne coupe rien tant que la reconnexion n'est pas testée.
$SUDO tee "$ssh_drop" >/dev/null <<EOF
# Posé par mcp-vps-deploy (10-harden.sh)
Port 22
Port $SSH_PORT
PermitRootLogin prohibit-password
PubkeyAuthentication yes
EOF
# On ne désactive l'authentification par mot de passe QUE si au moins une clé existe,
# pour éviter tout risque de verrouillage.
if [ "${key_count:-0}" -ge 1 ]; then
  echo "PasswordAuthentication no" | $SUDO tee -a "$ssh_drop" >/dev/null
  ok "Connexion par clé uniquement (mot de passe désactivé)."
else
  echo "PasswordAuthentication yes" | $SUDO tee -a "$ssh_drop" >/dev/null
  printf '\033[1;33m  [ATTENTION]\033[0m Aucune clé SSH trouvée : le mot de passe reste activé pour ne pas te bloquer. Ajoute une clé avant de désactiver le mot de passe.\n'
fi
$SUDO sshd -t
$SUDO systemctl restart ssh 2>/dev/null || $SUDO systemctl restart sshd
ok "SSH écoute maintenant sur les ports 22 et $SSH_PORT."

log "Pare-feu ufw : on n'ouvre que le strict nécessaire"
$SUDO ufw --force default deny incoming >/dev/null
$SUDO ufw --force default allow outgoing >/dev/null
$SUDO ufw allow 22/tcp        >/dev/null   # temporaire (filet de sécurité)
$SUDO ufw allow "$SSH_PORT"/tcp comment 'SSH custom' >/dev/null
$SUDO ufw allow 80/tcp        >/dev/null
$SUDO ufw allow 443/tcp       >/dev/null
$SUDO ufw --force enable      >/dev/null
ok "Pare-feu actif : seuls 22 (temporaire), $SSH_PORT, 80 et 443 sont ouverts."

log "fail2ban : bannit les IP qui tentent de forcer le SSH"
$SUDO tee /etc/fail2ban/jail.d/mcp-sshd.local >/dev/null <<EOF
[sshd]
enabled = true
port    = 22,$SSH_PORT
backend = systemd
maxretry = 5
bantime  = 1h
EOF
$SUDO systemctl enable --now fail2ban >/dev/null 2>&1 || true
$SUDO systemctl restart fail2ban
ok "fail2ban actif."

log "Mises à jour de sécurité automatiques"
$SUDO dpkg-reconfigure -f noninteractive unattended-upgrades >/dev/null 2>&1 || true
$SUDO systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
ok "Mises à jour de sécurité automatiques activées."

echo
printf '\033[1;32m=== VPS sécurisé. ===\033[0m\n'
printf '\033[1;33mÉTAPE SUIVANTE IMPORTANTE :\033[0m ouvre un NOUVEau terminal et teste la reconnexion :\n'
printf '    ssh -p %s %s@%s\n' "$SSH_PORT" "$MCP_ACCOUNT" "${MCP_DNS:-<IP_DU_VPS>}"
printf 'Tant que cette reconnexion ne marche pas, NE FERME PAS le port 22.\n'
