# Design - Vérification du MCP Unipile en transport stdio (en plus de HTTP)

> Date : 2026-06-24
> Plugin concerné : `mcp-unipile-grader`
> Statut : design validé, prêt pour le plan d'implémentation.

## 1. Problème

Le grader `mcp-unipile-grader` vérifie aujourd'hui la conformité d'un serveur MCP
Unipile **uniquement en transport HTTP** (déploiement VPS, OAuth). Tout repose sur :

- `scripts/test-conformite.sh` : tests `curl` (`/health`, `/.well-known/oauth-*`,
  401 + `WWW-Authenticate`, rejet PKCE `plain`) ;
- `commands/test-mcp.md` : slash command `/test-mcp <URL>` ;
- `skills/verifier-conformite-mcp-unipile/spec-mcp-unipile.md` : grille de conformité
  bâtie autour d'OAuth + endpoints HTTP.

On veut permettre de vérifier **aussi** un serveur MCP Unipile en **transport stdio**
(exécution locale, mono-utilisateur), où l'`account_id` est passé en **argument CLI**
au lancement du process.

## 2. Pourquoi ce n'est pas « le même test sur un autre transport »

Un serveur MCP stdio tourne comme sous-process local ; on lui parle en **JSON-RPC
délimité par newline** (un message JSON par ligne) sur stdin/stdout, et il doit logger
sur **stderr** (tout bruit sur stdout casse le flux JSON-RPC). Il n'y a **ni HTTP, ni
OAuth, ni `/health`, ni `.well-known`, ni 401**. Une grande partie des exigences « DOIT »
(section 3 OAuth, section 4 endpoints, 5.1 sessions HTTP) **ne s'applique pas**. En
revanche, **tout le cœur sécurité du proxy reste pertinent**.

Conséquence : le mode stdio a sa **propre grille de conformité réduite**, et son propre
mécanisme de test (parler MCP sur stdin/stdout, pas `curl`).

## 3. Décisions de cadrage (validées avec l'utilisateur)

| Sujet | Décision |
|---|---|
| Fourniture de l'`account_id` en stdio | **Argument CLI** (ex. `node server.js --account-id XXX`). Pattern Claude Code : `claude mcp add --transport stdio <name> -- <cmd> [args...]`, tout après `--` est passé tel quel. |
| Sélection du mode au lancement de la vérif | **Flag explicite** : `/test-mcp --http <URL>` et `/test-mcp --stdio "<commande>"`. |
| Implémentation du test stdio | **Approche A** : étendre le script existant avec un mode `--stdio`, dialogue JSON-RPC via un helper `python3` embarqué. Un seul outil, dépendances quasi inchangées. |
| Lieu de travail | Clone propre `~/git/plugins-formation` (pas la cache marketplace, qui peut être écrasée par un update de plugin). |

## 4. Grille de conformité réduite (mode stdio)

### 4.1 Exigences qui RESTENT « DOIT »

- **1.1-1.5** : interface MCP (list/call) sur stdio ; relais `tools/list` et `tools/call`
  vers Unipile ; clé org **jamais** exposée au client ; outil synthétique
  `get_current_account` qui renvoie l'`account_id` de l'arg CLI **sans appeler Unipile**.
- **2.1-2.5** : 1 process ↔ 1 `account_id` (celui de l'arg CLI) ; **`account_id`
  forcé/écrasé** sur chaque appel sortant (LE test décisif, il reste) ; réécriture de la
  liste des comptes vers le seul compte ; `DELETE` compte bloqué ; garde SSRF sur l'hôte
  Unipile.
- **6.1-6.2** : séquence d'init MCP vers l'upstream + parsing SSE/JSON de l'upstream.
- **8.3** : secrets jamais loggés (désormais sur **stderr**).
- **9.1-9.2** : `UNIPILE_API_KEY` en variable d'env ; `UNIPILE_BASE_URL` validé anti-SSRF.
- **10.1** : build/run reproductible.

### 4.2 Exigences « DOIT » spécifiques au mode stdio (nouvelles)

- **S.A** : l'`account_id` est fourni en **argument CLI** au lancement du process.
- **S.B** : les logs sont écrits **exclusivement sur stderr** ; stdout ne contient que
  du JSON-RPC valide (sinon le flux MCP est cassé).
- **S.C** (remplace 10.2) : le serveur démarre et **répond à `initialize`** sur stdio.

### 4.3 Exigences CADUQUES en stdio (non vérifiées)

- Toute la section **3a OAuth** (3.1-3.10 : PKCE, DCR, `.well-known`, `/authorize`,
  `/token`, 401 + `WWW-Authenticate`).
- **3.11/3.12** header direct → remplacé par l'arg CLI (S.A) ; **3.13-3.16** cycle de vie
  des tokens (plus de tokens).
- Section **4** endpoints HTTP (dont `/health`) ; **5.1/5.2/5.3** sessions HTTP.
- **8.1** limite payload HTTP, **8.2** rate-limit OAuth, **8.4** CSP, **8.6** TTL DCR.
- **9.3** `PORT`, **9.4** `TOKENS_FILE`.
- **10.2** `/health` → remplacé par S.C.

### 4.4 DEVRAIT (qualité) conservés

- **1.6** outil synthétique documenté « call first » ; **6.3** timeouts upstream ;
  **6.4** erreurs upstream génériques ; **7.1** multipart (si édition de profil visée) ;
  **8.5** non-root ; **10.3** README.

## 5. Tests : automatique vs manuel (parallèle au mode HTTP)

En HTTP, le script automatise les tests **sans authentification** et renvoie le reste en
manuel/revue de code. Même logique en stdio : sans vraies creds Unipile, on automatise ce
qui est testable **hors-ligne**.

### 5.1 Automatique (script, sans creds Unipile)

Le script lance le serveur avec une `UNIPILE_BASE_URL` **volontairement injoignable**
(sentinelle), pour prouver l'absence d'appel réseau.

- **S1** : le serveur démarre et répond à `initialize` (couvre S.C / ex-10.2).
- **S2** : `tools/list` renvoie une liste contenant `get_current_account` (1.5).
- **S3** : `tools/call get_current_account` renvoie un `account_id` non vide **malgré**
  l'`UNIPILE_BASE_URL` injoignable → prouve qu'il ne fait pas d'appel Unipile (1.5).
  Option `--account-id <id>` pour vérifier en plus la **valeur exacte** attendue.
- **S4** : aucune trace de la clé org (`UNIPILE_API_KEY`) dans les réponses stdout
  (1.4 / 8.3).
- **S5** : stdout ne contient **que** du JSON-RPC valide (logs bien rangés sur stderr,
  couvre S.B).

### 5.2 Manuel / revue de code (comme la partie auth en HTTP)

- **2.2** `account_id` forcé (le test décisif, nécessite upstream réel ou mock + un
  compte) ; **2.3** réécriture liste comptes ; **2.4** `DELETE` bloqué ; **2.5** SSRF.
- **1.2/1.3** relais réel (nécessite creds) ; **6.1/6.2** init + parsing upstream.

## 6. Conception du script `test-conformite.sh`

### 6.1 Parsing des arguments

- `--http <URL>` : comportement actuel, **inchangé**.
- `--stdio "<commande>"` : nouvelle branche de test. La commande inclut l'arg CLI de
  l'account_id (ex. `--stdio "node server.js --account-id ABC123"`).
- `--account-id <id>` (optionnel, mode stdio) : valeur attendue pour S3.
- **Rétrocompat** : si le 1er argument est une URL nue (`http…`), bascule
  automatiquement en `--http` → les `/test-mcp <URL>` existants continuent de marcher.

### 6.2 Branche stdio

Un **helper `python3` embarqué** (heredoc dans le script bash) :

1. ouvre le sous-process (la commande `--stdio`), avec `UNIPILE_API_KEY` (sentinelle
   reconnaissable, ex. `SENTINEL_ORG_KEY_DO_NOT_LEAK`) et `UNIPILE_BASE_URL` injoignable
   (ex. `http://127.0.0.1:1`) dans l'environnement ;
2. dialogue en JSON-RPC newline-delimited avec `timeout` : `initialize` →
   `notifications/initialized` → `tools/list` → `tools/call get_current_account` ;
   corrèle les réponses par `id` ;
3. applique les assertions S1-S5 et renvoie un **résumé JSON** sur stdout.

Le bash parse ce résumé et émet les `[PASS]`/`[FAIL]` via les fonctions `ok`/`ko`
existantes (compteurs `PASS`/`FAIL` unifiés avec le mode HTTP). En fin de run, il rappelle
les vérifications **manuelles** spécifiques stdio (section 5.2).

### 6.3 Dépendances

- Mode HTTP : `bash`, `curl`, `jq` (inchangé).
- Mode stdio : `bash`, `python3` (présent partout dans l'environnement cible ; sert
  uniquement au dialogue JSON-RPC, plus robuste que bash pur pour timeouts + corrélation
  des `id`).

## 7. Autres fichiers à mettre à jour

- **`commands/test-mcp.md`** : documenter les flags `--http` / `--stdio`
  (+ `--account-id`), mettre à jour l'`argument-hint`, et faire préciser au rapport
  **quelle grille** (HTTP ou stdio) a été appliquée. Pour le mode stdio, rappeler les
  vérifications manuelles propres (section 5.2).
- **`skills/verifier-conformite-mcp-unipile/spec-mcp-unipile.md`** : ajouter une
  **« Annexe B - Variante transport stdio »** reprenant la grille réduite (sections 4 et 5
  de ce design), avec sa propre checklist cochable.
- **`skills/verifier-conformite-mcp-unipile/SKILL.md`** : mentionner les **deux modes de
  transport** (HTTP / stdio) dans la procédure et pointer vers l'annexe B.
- **`.claude-plugin/plugin.json`** : pas de changement fonctionnel (bump de version
  éventuel au moment du commit).

## 8. Hors périmètre (YAGNI)

- Pas de mock Unipile fourni : les tests nécessitant de vraies creds restent manuels,
  comme en HTTP.
- Pas de support du framing « Content-Length » style LSP : le transport stdio MCP est
  newline-delimited.
- Pas de dépendance à un client MCP externe (ex. `@modelcontextprotocol/inspector`) :
  écarté pour garder le grader minimaliste.
