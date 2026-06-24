# Design - plugin `mcp-vps-deploy`

Date : 2026-06-24
Dépôt : `plugins-formation` (marketplace nocodeia+)

## But

3e plugin du marketplace, qui ferme la boucle pédagogique **coder -> tester (`mcp-unipile-grader`) -> déployer (ce plugin)**.

Il guide des étudiants **non-informaticiens** (vibe-codeurs) pour héberger leur serveur
MCP Unipile sur **leur propre VPS Ubuntu vierge**, en reproduisant fidèlement la
configuration durcie déjà en place sur `app.deers.fr`.

## Paramètres (fournis par l'étudiant)

- `--dns` : nom DNS public, ex. `mcp-unipile-groupe3.deers.fr`
- `--port` : port localhost du process MCP, ex. `3101`
- `--account` : utilisateur système SSH créé et durci sur le VPS, ex. `deploy`
- `--repo` : URL GitHub du MCP des étudiants (Node ou Python, auto-détecté)

## Configuration de référence relevée sur app.deers.fr (2026-06-24)

- Process Node sous **pm2** (`mcp-unipile-server`), écoute en **localhost uniquement**
  (port 3100), jamais exposé directement à Internet.
- **NGINX reverse proxy** sur `mcp-unipile.deers.fr` -> `localhost:3100`, relais des
  en-têtes MCP (`Authorization`, `X-Account-Id`, `X-Mcp-Secret`, `Mcp-Session-Id`),
  `proxy_buffering off` (streaming SSE), `proxy_read_timeout 300s`, redirection 80->443.
- **TLS Let's Encrypt** via certbot.
- **Durcissement** : `ufw` (entrant refusé sauf 80/443 + SSH sur port custom 22242,
  port 22 bloqué), `fail2ban` actif, pm2 en démarrage automatique au boot.

## Principe pédagogique (coeur du plugin)

Public = vibe-codeurs, **pas des informaticiens**. Donc :

- Zéro prérequis supposé. Chaque terme technique défini à sa première apparition avec une
  analogie du quotidien (VPS, SSH, port, pare-feu, reverse proxy, TLS, DNS...).
- L'étudiant **valide** (question fermée oui/non), Claude **fait** le travail technique et
  le traduit en langage courant. L'étudiant n'a pas besoin de lire le bash.
- Points sensibles sur-expliqués avec filet de sécurité (ex. changement de port SSH : on
  garde une session de secours pour ne pas se verrouiller dehors).
- Aucun message d'erreur brut laissé sans traduction : en cas d'échec, explication claire
  + piste de correction.

## Structure des fichiers

```
mcp-vps-deploy/
├── .claude-plugin/plugin.json
├── commands/
│   └── deploy-mcp.md
├── skills/
│   └── deployer-mcp-sur-vps/
│       ├── SKILL.md                # guide pas-à-pas pédagogique (le coeur)
│       └── reference-app-deers.md  # config de référence figée
└── scripts/
    ├── 00-precheck.sh              # OS Ubuntu, sudo, internet, DNS résout vers le VPS
    ├── 10-harden.sh                # compte système + clé, ufw, fail2ban, MAJ auto, sshd port custom (22 gardé)
    ├── 15-ssh-lockdown.sh          # APRÈS reconnexion confirmée : ferme le port 22
    ├── 20-runtime.sh               # Node LTS (ou Python venv) + pm2 + démarrage auto
    ├── 30-deploy-app.sh            # clone repo, deps, .env (port), pm2 start + save
    ├── 40-nginx-certbot.sh         # vhost reverse-proxy (template) + TLS certbot
    ├── 99-verify.sh                # /health HTTPS + rappel /test-mcp
    └── templates/
        └── nginx-mcp.conf.tmpl     # calqué sur mcp-unipile.deers.fr
```

Scripts **idempotents** (relançables sans casse), paramètres passés en variables d'env,
exécutés sur le VPS via SSH par Claude sous la supervision de l'étudiant.

## Parcours guidé (ordre = durcir avant d'exposer)

0. Cadre + analogie d'architecture, collecte des 4 paramètres, vérifie VPS Ubuntu vierge
   avec accès root/sudo.
1. `00-precheck` : SSH OK, Ubuntu, sudo, le DNS résout déjà vers l'IP du VPS.
2. `10-harden` : crée le compte système + sa clé SSH, ajoute le port SSH custom (garde 22
   temporairement), `ufw` (entrant refusé sauf SSH-custom/80/443), `fail2ban`, MAJ auto.
3. **Gate de reconnexion** : l'étudiant rouvre une session sur le port custom (filet de
   sécurité) puis `15-ssh-lockdown` ferme le port 22.
4. `20-runtime` : Node LTS (ou Python) + pm2 + démarrage auto au boot.
5. `30-deploy-app` : clone le repo, installe les deps, génère le `.env` (port localhost +
   secrets saisis à la main), lance sous pm2 + `pm2 save`.
6. `40-nginx-certbot` : vhost reverse-proxy (template de référence) + certbot HTTPS.
7. `99-verify` : `/health` en HTTPS, puis invite à enchaîner `/test-mcp` (plugin grader).

## Choix techniques

- **Process manager** : pm2 pour Node *et* Python (cohérent avec la référence, un seul
  outil).
- **DNS** : le plugin ne crée pas l'enregistrement (clé Gandi = secret de l'instructeur,
  hors repo public). Il **vérifie** la résolution. La création des sous-domaines
  `deers.fr` reste du ressort de l'instructeur (API Gandi).
- **Secrets** : jamais commités ; saisis à l'étape 5, écrits dans le `.env` du VPS
  uniquement.
- **Détection de stack** : `package.json` -> Node ; `requirements.txt`/`pyproject.toml` ->
  Python. Commande de démarrage demandée à l'étudiant si non déductible.

## Hors périmètre (YAGNI)

- Pas de provisioning du VPS (l'étudiant arrive avec un Ubuntu vierge).
- Pas d'Ansible / IaC.
- Pas de création DNS automatisée.
- Pas de multi-tenant (1 MCP = 1 VPS = 1 sous-domaine).

## Livraison

- 3e plugin ajouté à `.claude-plugin/marketplace.json`.
- Section dédiée ajoutée au `README.md` (boucle coder -> tester -> déployer).
- Commit + push sur `git@github.com:philcollins2171/plugins-formation.git`.
