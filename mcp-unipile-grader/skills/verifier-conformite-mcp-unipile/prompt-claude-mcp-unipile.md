# Prompt de référence — faire développer le MCP Unipile par Claude

> **Usage en formation.** Ce prompt est la « commande » de référence qui aurait dû
> produire un MCP Unipile conforme à [`spec-mcp-unipile.md`](./spec-mcp-unipile.md).
> Sers-t'en pour : (a) comparer à ce que tes étudiants ont réellement demandé à leur
> Claude, (b) repérer les exigences absentes de *leur* prompt qui expliquent les manques
> de leur rendu.
>
> Le prompt est **agnostique de la stack** : il décrit les comportements, pas la techno.
> Une variante « stack imposée » est donnée en fin de document.

---

## Prompt principal (à copier-coller)

```
Tu es chargé de développer un serveur MCP (Model Context Protocol) qui sert de
PROXY DE SÉCURITÉ entre un client Claude (claude.ai web et Claude Desktop) et
l'endpoint MCP officiel d'Unipile (https://developer.unipile.com/mcp), afin de
piloter un compte LinkedIn.

OBJECTIF DE SÉCURITÉ CENTRAL : le client ne doit JAMAIS recevoir la clé d'API de
l'organisation, et chaque utilisateur doit être strictement ISOLÉ sur son seul
compte Unipile (account_id). Le proxy est le seul à détenir la clé org et à
décider quel compte est joignable.

Stack : libre (choisis ce que tu maîtrises : Node/TypeScript + SDK MCP, ou
Python + FastMCP, etc.). Justifie brièvement ton choix.

== FONCTIONNALITÉS ATTENDUES ==

1. PROXY MCP
   - Exposer une interface MCP (tools/list, tools/call) consommable par Claude.
   - Relayer tools/list et tools/call vers l'upstream Unipile.
   - Injecter la clé d'API de l'org (en-tête X-API-KEY) UNIQUEMENT côté serveur,
     dans l'appel sortant. Jamais l'exposer au client ni la renvoyer dans une
     réponse d'outil.
   - Ajouter un OUTIL SYNTHÉTIQUE "get_current_account" en tête de la liste
     d'outils, qui retourne l'account_id de la session SANS appeler Unipile, et
     dont la description dit de l'appeler en premier.

2. ISOLATION PAR COMPTE (priorité absolue)
   - Une session = un seul account_id.
   - Sur CHAQUE appel sortant, FORCER l'account_id de la session : supprimer tout
     account_id fourni par le client puis réinjecter celui de la session.
   - Réécrire un éventuel "lister tous les comptes" (GET /api/v1/accounts) vers le
     seul compte de la session (GET /api/v1/accounts/{accountId}).
   - BLOQUER les opérations destructives sur le compte (ex. DELETE
     /api/v1/accounts...) et renvoyer une erreur claire au client.
   - Protéger contre le SSRF : valider l'hôte Unipile cible contre une liste
     blanche (motif type api<N>.unipile.com) ; défaut sûr sinon.

3. AUTHENTIFICATION — DEUX MODES
   a) OAuth 2.0 Authorization Code + PKCE pour claude.ai web :
      - PKCE S256 OBLIGATOIRE ; rejeter la méthode "plain".
      - Dynamic Client Registration (endpoint d'enregistrement client).
      - Métadonnées de découverte : /.well-known/oauth-authorization-server et
        /.well-known/oauth-protected-resource.
      - /authorize (GET) : valider client_id, redirect_uri, code_challenge ;
        afficher un formulaire HTML où l'utilisateur saisit son Account ID Unipile
        (champ masqué).
      - /authorize (POST) : VÉRIFIER l'account_id auprès d'Unipile (compte
        existant/valide) AVANT d'émettre un code ; sinon réafficher l'erreur.
      - Code d'autorisation à usage unique et courte durée.
      - /token (POST) : valider grant_type, client_id/secret, le code ET le PKCE
        (code_verifier), puis émettre un access_token avec un TTL de 30 jours
        (expires_in cohérent).
      - Les access_token doivent être PERSISTÉS SUR DISQUE (survivre à un
        redémarrage), rechargés au démarrage en filtrant les expirés, et les
        tokens expirés purgés périodiquement.
      - À l'exécution MCP, résoudre Authorization: Bearer <token> → account_id.
      - Si non authentifié : répondre 401 avec en-tête WWW-Authenticate: Bearer
        (pour déclencher la ré-authentification automatique côté Claude).
   b) Header direct pour Claude Desktop :
      - Accepter un en-tête X-Unipile-Account-Id: <id> qui fournit l'account_id
        sans OAuth. Ce mode est prioritaire s'il est présent.

4. ENDPOINTS HTTP
   - Endpoint MCP (racine / ou /mcp).
   - GET /health (JSON: status ok + nom du service + upstream).
   - Les endpoints OAuth et .well-known ci-dessus.

5. SESSIONS MCP
   - Gérer les sessions (transport HTTP), réutiliser une session existante via son
     identifiant, purger les sessions inactives après un TTL.

6. ROBUSTESSE UPSTREAM
   - Respecter la séquence d'init MCP de l'upstream (initialize →
     notifications/initialized → appel réel).
   - Savoir parser les réponses en SSE (data:) ET en JSON direct.
   - Poser des timeouts sur les appels sortants.
   - Logger le détail des erreurs côté serveur mais renvoyer au client une erreur
     générique (pas de fuite).

== DURCISSEMENT ==
   - Limite de taille de payload sur tous les endpoints HTTP.
   - Rate limiting sur /authorize (POST) et /token.
   - Secrets JAMAIS loggés (clé org et tokens masqués).
   - CSP stricte sur le formulaire OAuth.
   - Exécution non-root (si conteneurisé).

== CONFIGURATION ==
   - UNIPILE_API_KEY : clé org (jamais en dur, jamais exposée).
   - UNIPILE_BASE_URL : DSN Unipile, validé anti-SSRF.
   - PORT : port d'écoute (avec défaut).
   - Aucun secret codé en dur.

== LIVRABLES ==
   - Code source organisé et commenté.
   - Dockerfile (ou instructions de build/run reproductibles).
   - README : variables d'env, commandes de build/run, liste des endpoints, et
     explication du modèle de sécurité (isolation + non-exposition de la clé).

== CRITÈRE DE RÉUSSITE ==
   Le test décisif : si un client passe volontairement un account_id ÉTRANGER dans
   une requête, le proxy doit l'écraser par celui de la session. Aucune fuite de la
   clé org. PKCE S256 obligatoire.

Procède par étapes, explique tes choix d'architecture, puis implémente.
```

---

## Variante « stack imposée » (optionnelle)

Si tu veux contraindre la techno pour homogénéiser les rendus, remplace la ligne
« Stack : libre… » par l'un des deux blocs :

**Node / TypeScript :**
```
Stack imposée : Node.js 20 + TypeScript (ESM), framework HTTP Express, et le SDK
officiel @modelcontextprotocol/sdk avec le transport Streamable HTTP. Validation
des schémas avec zod. Build via tsc, run via node dist/index.js.
```

**Python :**
```
Stack imposée : Python 3.11+ avec FastMCP (ou le SDK MCP officiel Python) pour
l'interface MCP, et un framework HTTP au choix (FastAPI/Starlette) pour les routes
OAuth et /health. Gestion d'environnement via uv ou venv + requirements.txt.
```

---

## Comment t'en servir en correction

1. Demande à chaque étudiant le **prompt qu'il a réellement donné** à son Claude.
2. Mets-le côte à côte avec ce prompt de référence.
3. Pour chaque fonctionnalité manquante dans son rendu, cherche d'abord si
   l'exigence était **absente de son prompt**. C'est le moment pédagogique clé du
   vibe-coding : *« le modèle ne fait bien que ce qu'on lui a clairement demandé »*.
4. Repasse ensuite la [checklist de conformité](./spec-mcp-unipile.md#annexe--checklist-de-conformité-à-cocher-par-rendu)
   sur le rendu, indépendamment du prompt, pour mesurer l'écart objectif.

> Distinction utile à enseigner : un manque peut venir (a) d'un **prompt incomplet**,
> (b) d'une **dérive du modèle** (il a oublié une consigne pourtant présente), ou
> (c) d'un **bug d'implémentation**. Les trois se corrigent différemment.
