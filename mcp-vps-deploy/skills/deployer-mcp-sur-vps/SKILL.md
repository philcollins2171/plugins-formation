---
name: deployer-mcp-sur-vps
description: Utiliser pour accompagner pas-à-pas un étudiant (non-informaticien) qui veut mettre en ligne son serveur MCP Unipile sur son propre VPS Ubuntu vierge. Couvre la sécurisation du serveur (durcissement), le reverse proxy NGINX, le HTTPS et la mise en route du MCP, en reproduisant la configuration de référence app.deers.fr. Déclencher quand quelqu'un veut "déployer", "héberger", "mettre en production", "mettre en ligne" son MCP sur un VPS.
---

# Déployer un MCP sur un VPS (guide pour débutants)

## Quoi et pourquoi

Tu vas aider une personne **qui n'est pas informaticienne** (une vibe-codeuse) à mettre
son serveur MCP en ligne sur un **VPS** : un ordinateur loué dans un centre de données,
allumé en permanence, que l'on pilote à distance.

Le but : reproduire, étape par étape, la configuration **sûre** déjà éprouvée sur le
serveur de référence `app.deers.fr`. À la fin, le MCP de l'étudiant sera accessible à une
adresse `https://...` propre et sécurisée.

Lis d'abord le fichier de référence pour avoir la "vérité terrain" :
`${CLAUDE_PLUGIN_ROOT}/skills/deployer-mcp-sur-vps/reference-app-deers.md`
(il est à côté de ce fichier SKILL.md).

## RÈGLE D'OR : comment tu dois parler et agir

Le public ne connaît pas le jargon technique. Donc, à CHAQUE étape, dans cet ordre :

1. **Une analogie ou une phrase simple** qui dit ce qu'on va faire et pourquoi.
2. **Tu définis chaque mot technique** la première fois qu'il apparaît (VPS, SSH, port,
   pare-feu, reverse proxy, certificat, DNS...). Voir le mini-lexique plus bas.
3. **Tu demandes une validation simple** ("On y va ? oui/non") avant d'agir.
4. **TU fais le travail technique** (les commandes SSH, les scripts). L'étudiant n'a pas à
   lire ni à comprendre le bash. Tu lui résumes en français ce que le script vient de faire.
5. **Si une commande échoue**, tu ne montres jamais un message d'erreur brut sans le
   traduire : tu expliques en clair ce qui se passe et tu proposes la correction.

Reste patient, encourageant, et avance **une étape à la fois**. Ne déroule jamais
plusieurs étapes d'un coup sans validation.

## Mini-lexique (à réutiliser quand le mot apparaît)

- **VPS** : un ordinateur loué, allumé 24h/24, qu'on pilote à distance.
- **SSH** : le tunnel sécurisé pour piloter ce VPS à distance (comme une télécommande
  protégée).
- **Port** : une porte numérotée sur la machine ; chaque programme écoute derrière la sienne.
- **Pare-feu (ufw)** : le videur à l'entrée ; il ne laisse passer que les portes autorisées.
- **Reverse proxy (NGINX)** : l'accueil de l'immeuble ; les visiteurs parlent à l'accueil,
  qui transmet au bon bureau à l'intérieur.
- **Certificat TLS / HTTPS** : le cadenas du navigateur ; il chiffre la conversation et
  prouve l'identité du site.
- **DNS** : l'annuaire qui traduit un nom (`mcp-...deers.fr`) en adresse de la machine.
- **pm2** : le gardien qui relance le MCP s'il plante ou si le serveur redémarre.

## Les 4 informations à réunir au départ

Demande-les si elles ne sont pas déjà fournies par la commande `/deploy-mcp` :

| Info | Exemple | À quoi ça sert |
|---|---|---|
| Nom DNS (`--dns`) | `mcp-unipile-groupe3.deers.fr` | l'adresse publique du MCP |
| Port (`--port`) | `3101` | la porte interne où tourne le MCP (jamais exposée directement) |
| Compte (`--account`) | `deploy` | l'utilisateur dédié créé sur le VPS |
| Dépôt GitHub (`--repo`) | `https://github.com/groupe3/mon-mcp.git` | le code du MCP à installer |

Tu auras aussi besoin de demander à l'étudiant, au fil de l'eau :
- **comment il se connecte à son VPS pour la première fois** (l'adresse IP, et l'utilisateur
  de départ, souvent `root`) ;
- **un email** (pour les alertes du certificat HTTPS) ;
- **ses clés secrètes** (clé API Unipile, etc.) au moment de configurer le MCP.

Garde en tête ces variables pendant toute la session :
`MCP_DNS`, `MCP_PORT`, `MCP_ACCOUNT`, `MCP_REPO`, `SSH_PORT` (défaut **22242**),
`ADMIN_EMAIL`, `APP_NAME` (par défaut, déduis-le du nom DNS, ex. `mcp-unipile-groupe3`),
`VPS_HOST` (IP du VPS), `INITIAL_USER` (souvent `root`).

## Où sont les scripts

Tous les scripts sont dans `${CLAUDE_PLUGIN_ROOT}/scripts/`. Pour les utiliser sur le VPS,
**copie d'abord le dossier sur le VPS**, puis exécute-les là-bas. Exemple de copie (adapte
l'utilisateur et le port selon l'étape) :

```
scp -P <port> -r "${CLAUDE_PLUGIN_ROOT}/scripts" <user>@<VPS_HOST>:~/mcp-deploy
```

Puis tu lances un script en passant les variables, par ex. :

```
ssh -p <port> <user>@<VPS_HOST> "MCP_DNS='...' SSH_PORT='22242' MCP_ACCOUNT='deploy' bash ~/mcp-deploy/10-harden.sh"
```

## Le déroulé, étape par étape

### Étape 0 - Accueil et préparation
Explique l'architecture avec l'analogie de l'immeuble : "Internet parle à un accueil
(NGINX) en HTTPS ; l'accueil transmet à ton MCP qui, lui, reste à l'intérieur, invisible
de l'extérieur. Un videur (le pare-feu) garde l'entrée." Réunis les 4 informations.
Demande l'IP du VPS et l'utilisateur de connexion initial. **Valide** avant de continuer.

### Étape 1 - Vérifications (`00-precheck.sh`)
Dis : "On vérifie d'abord que ton serveur est prêt : qu'il est bien sous Ubuntu, qu'on a
les droits, qu'il a Internet, et surtout que ton adresse `MCP_DNS` pointe bien vers lui."
Copie les scripts, puis lance `00-precheck.sh` avec `MCP_DNS`.
Si le DNS ne pointe pas encore vers le VPS : explique qu'il faut créer un enregistrement
DNS (type A) vers l'IP du VPS, et que c'est **le formateur** qui le fait (pour les
sous-domaines `deers.fr`). On ne continue pas tant que ce n'est pas réglé.

### Étape 2 - Sécuriser le serveur (`10-harden.sh`)
Explique : "Avant d'ouvrir la porte au public, on sécurise. On crée un compte dédié (plutôt
que de tout faire en root, le super-administrateur), on met un pare-feu, un système qui
bannit les pirates qui tapent à la porte (fail2ban), et on déplace la porte d'entrée SSH
sur un numéro discret." **Préviens du point sensible** : "On va changer le port de la porte
SSH, mais on garde l'ancienne ouverte le temps de vérifier que la nouvelle marche, pour que
tu ne restes jamais enfermé dehors." **Valide**, puis lance `10-harden.sh` (en root/sudo)
avec `MCP_ACCOUNT` et `SSH_PORT`.

### Étape 3 - GATE de reconnexion, puis verrouillage (`15-ssh-lockdown.sh`)
C'est l'étape la plus délicate. Demande à l'étudiant (ou fais-le toi-même dans un nouveau
test) de **se reconnecter sur le nouveau port avec le nouveau compte** :
```
ssh -p <SSH_PORT> <MCP_ACCOUNT>@<VPS_HOST>
```
**N'avance que si cette reconnexion fonctionne.** Une fois confirmée, lance
`15-ssh-lockdown.sh` (depuis une session sur le port custom) pour fermer l'ancienne porte
(port 22). Explique : "Maintenant que la nouvelle entrée marche, on condamne l'ancienne."

### Étape 4 - Installer le moteur (`20-runtime.sh`)
Explique simplement : "On installe les moteurs qui font tourner les MCP (Node.js, et
Python au cas où), plus pm2, le gardien qui relancera ton MCP tout seul." Lance
`20-runtime.sh` (root/sudo) avec `MCP_ACCOUNT`.

### Étape 5 - Installer et démarrer le MCP (`30-deploy-app.sh`)
Explique : "On récupère ton code depuis GitHub, on installe ses dépendances, on règle le
port, et on le démarre." **Ce script tourne sous le compte dédié, pas en root** :
```
ssh -p <SSH_PORT> <MCP_ACCOUNT>@<VPS_HOST> "MCP_REPO='...' MCP_PORT='3101' APP_NAME='...' bash ~/mcp-deploy/30-deploy-app.sh"
```
Puis aide l'étudiant à **remplir ses clés secrètes** dans le fichier `.env` (sur le VPS,
jamais dans GitHub). Si le script ne trouve pas la commande de démarrage, demande-la à
l'étudiant (souvent indiquée dans le README de son repo) et relance avec `START_CMD`.

### Étape 6 - Mettre l'accueil et le HTTPS (`40-nginx-certbot.sh`)
Explique : "On installe l'accueil (NGINX) qui reçoit les visiteurs et les dirige vers ton
MCP, et on pose le cadenas HTTPS (certificat gratuit Let's Encrypt)." Demande l'email pour
les alertes de certificat. Lance `40-nginx-certbot.sh` (root/sudo) avec `MCP_DNS`,
`MCP_PORT`, `ADMIN_EMAIL`.

### Étape 7 - Vérifier (`99-verify.sh`)
Lance `99-verify.sh` avec `MCP_DNS` (et `APP_NAME`). Si `/health` répond `200` en HTTPS :
bravo, c'est en ligne. Propose ensuite d'enchaîner avec le plugin de test :
`/test-mcp --http https://<MCP_DNS>` pour vérifier la conformité du MCP.

## En cas de souci (à traduire en clair pour l'étudiant)

- **certbot échoue** : presque toujours le DNS qui ne pointe pas (encore) vers le VPS, ou
  le port 80 fermé. Reviens à l'étape 1.
- **`/health` ne répond pas** : le MCP n'écoute peut-être pas sur le bon port, ou il a
  planté. Regarde `pm2 logs <APP_NAME>` et le `.env`.
- **plus d'accès SSH après le changement de port** : c'est pour ça qu'on garde le port 22
  ouvert jusqu'à l'étape 3. Si besoin, le panneau de secours ("console") du fournisseur de
  VPS permet de revenir en arrière.
