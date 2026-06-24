# Configuration de référence : app.deers.fr

Ce document fige la configuration serveur relevée sur le VPS de référence
`app.deers.fr` le 2026-06-24. Les scripts du plugin reproduisent cette configuration.
C'est la « vérité terrain » : en cas de doute, c'est elle qui fait foi.

## Vue d'ensemble

Le MCP ne parle **jamais** directement à Internet. Deux barrières le protègent :

```
Internet  ──HTTPS(443)──►  NGINX (reverse proxy)  ──HTTP──►  process MCP (localhost:PORT)
                              + certificat TLS                 lancé par pm2
   ▲                                                           jamais exposé directement
   │
   └── pare-feu ufw : seuls 80, 443 et le port SSH custom sont ouverts
```

## 1. Process MCP

- Lancé par **pm2** (gestionnaire de process qui le relance s'il plante et au redémarrage
  du serveur).
- Écoute en **localhost uniquement** (sur app.deers.fr : `127.0.0.1:3100`). Il n'est donc
  pas joignable de l'extérieur sans passer par NGINX.
- pm2 configuré pour démarrer automatiquement au boot (`pm2 startup` + `pm2 save`).

## 2. NGINX (reverse proxy) - vhost de référence

Points qui comptent pour un MCP (à reproduire dans le template) :

- `proxy_pass http://localhost:PORT;`
- relais des en-têtes MCP :
  `Authorization`, `X-Account-Id`, `X-Mcp-Secret`, `Mcp-Session-Id` (+ `proxy_pass_header Mcp-Session-Id`)
- `proxy_http_version 1.1;` et `proxy_set_header Connection '';`
- `proxy_buffering off;` et `proxy_cache off;` -> **indispensable** pour le streaming SSE
  (sinon les réponses du MCP arrivent par à-coups ou jamais).
- `proxy_read_timeout 300s;` (les appels MCP peuvent être longs).
- endpoint `/health` proxifié.
- redirection automatique `http://` (port 80) -> `https://` (port 443), posée par certbot.

Extrait réel (`/etc/nginx/sites-enabled/mcp-unipile.deers.fr`) :

```nginx
server {
    server_name mcp-unipile.deers.fr;

    location /mcp/unipile {
        proxy_pass http://localhost:3100;
        proxy_http_version 1.1;
        proxy_set_header Connection '';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Authorization $http_authorization;
        proxy_set_header X-Account-Id $http_x_account_id;
        proxy_set_header X-Mcp-Secret $http_x_mcp_secret;
        proxy_set_header Mcp-Session-Id $http_mcp_session_id;
        proxy_pass_header Mcp-Session-Id;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
    }

    location /health { proxy_pass http://localhost:3100; proxy_http_version 1.1; }

    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/mcp-unipile.deers.fr/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mcp-unipile.deers.fr/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}
server {
    if ($host = mcp-unipile.deers.fr) { return 301 https://$host$request_uri; }
    listen 80;
    server_name mcp-unipile.deers.fr;
    return 404;
}
```

## 3. TLS

- Certificat **Let's Encrypt** posé et renouvelé par **certbot** (plugin nginx).

## 4. Durcissement (sécurité)

- **Pare-feu `ufw`** : politique entrante = refuser par défaut ; autorisés uniquement :
  - `80/tcp` et `443/tcp` (web)
  - le **port SSH custom** (sur app.deers.fr : `22242/tcp`)
  - le port `22` standard est **bloqué** (DENY).
- **`fail2ban`** actif : bannit les IP qui tentent de forcer la connexion SSH.
- **SSH durci** : connexion par **clé** (pas de mot de passe), login `root` direct
  désactivé.
- **Mises à jour de sécurité automatiques** (`unattended-upgrades`).

## 5. Ce que le plugin reproduit (et adapte par paramètre)

| Référence app.deers.fr | Paramètre du plugin |
|---|---|
| sous-domaine `mcp-unipile.deers.fr` | `--dns` |
| process sur `localhost:3100` | `--port` |
| utilisateur système `ubuntu` | `--account` |
| code du MCP (déjà sur le VPS) | `--repo` (clone GitHub) |
| port SSH custom `22242` | `SSH_PORT` (défaut 22242) |
