# Spécification fonctionnelle — Serveur MCP Unipile (LinkedIn)

> **But de ce document.** Décrire *ce que le serveur doit faire*, indépendamment de la
> stack technique choisie (Node/TypeScript, Python/FastMCP, Go, etc.). Sert de
> **grille de conformité** pour valider un rendu d'étudiant avant la phase de test.
>
> Convention : **DOIT** = exigence obligatoire (bloquante si absente).
> **DEVRAIT** = recommandé (point de qualité, non bloquant).

---

## 0. En une phrase

Un **proxy de sécurité MCP** qui se place entre un client Claude (claude.ai web ou
Claude Desktop) et l'endpoint MCP officiel d'Unipile, pour piloter un compte LinkedIn
**sans jamais exposer la clé d'API de l'organisation** au client, et en **isolant
strictement chaque utilisateur sur son seul compte**.

```
  Claude (client MCP)  ──MCP──▶  [ NOTRE PROXY ]  ──HTTP+clé org──▶  Unipile MCP  ──▶  LinkedIn
                                  ▲ ajoute la sécurité ici
```

Analogie : c'est un **portier d'immeuble**. Le visiteur (Claude) ne reçoit jamais le
passe-partout (clé org). Le portier ouvre lui-même la porte, et uniquement celle de
l'appartement du visiteur (son `account_id`), jamais les autres.

---

## 1. Rôle de proxy MCP (cœur fonctionnel)

| # | Exigence | Niveau |
|---|---|---|
| 1.1 | Le serveur DOIT exposer une interface **MCP** consommable par un client Claude (liste d'outils + appel d'outils). | DOIT |
| 1.2 | Le serveur DOIT relayer `tools/list` vers l'upstream Unipile et renvoyer la liste d'outils réelle au client. | DOIT |
| 1.3 | Le serveur DOIT relayer `tools/call` vers l'upstream Unipile et renvoyer le résultat au client. | DOIT |
| 1.4 | Le serveur NE DOIT JAMAIS transmettre la clé d'API de l'organisation au client. Elle est injectée **côté serveur** dans l'appel sortant vers Unipile (en-tête `X-API-KEY`). | DOIT |
| 1.5 | Le serveur DOIT ajouter un **outil synthétique** (généré localement, ex. `get_current_account`) en tête de la liste d'outils, qui retourne l'`account_id` de la session **sans appeler Unipile**. | DOIT |
| 1.6 | L'outil synthétique DOIT être documenté pour être appelé en premier (« Always call this first »). | DEVRAIT |

> **Pourquoi 1.5 ?** Le modèle a besoin de connaître son propre `account_id` pour
> construire les appels API LinkedIn. On le lui fournit localement plutôt que de le lui
> faire deviner ou lister tous les comptes.

---

## 2. Isolation par compte (sécurité multi-utilisateurs)

C'est la partie *la plus importante* à vérifier. Sans elle, un utilisateur pourrait
agir sur le compte LinkedIn d'un autre.

| # | Exigence | Niveau |
|---|---|---|
| 2.1 | Chaque session/identité DOIT être liée à **un seul** `account_id` Unipile. | DOIT |
| 2.2 | Sur chaque appel sortant, le serveur DOIT **forcer** l'`account_id` de la session : supprimer tout `account_id` fourni par le client, puis réinjecter celui de la session. | DOIT |
| 2.3 | Un appel qui listerait *tous* les comptes de l'organisation (ex. `GET /api/v1/accounts`) DOIT être réécrit pour ne renvoyer que le compte de la session (ex. `GET /api/v1/accounts/{accountId}`). | DOIT |
| 2.4 | Les opérations **destructives** sur le compte (ex. `DELETE /api/v1/accounts...`, qui déconnecte LinkedIn d'Unipile) DOIVENT être **bloquées** par le proxy, avec une erreur renvoyée au client. | DOIT |
| 2.5 | Le serveur DOIT se protéger contre le **SSRF** : l'URL/DSN Unipile cible DOIT être validée contre une liste blanche d'hôtes autorisés (ex. motif `api<N>.unipile.com`) ; toute valeur invalide retombe sur un défaut sûr. | DOIT |

> **Test de 2.2 :** demander à Claude de faire un appel en passant volontairement un
> `account_id` étranger dans la requête. Le proxy doit l'écraser silencieusement par
> celui de la session. Si l'appel passe avec l'`account_id` étranger → **échec**.

---

## 3. Authentification — deux modes

Le serveur DOIT supporter **deux** façons de résoudre l'`account_id` d'un appel.

### 3a. Mode OAuth (claude.ai web) — **DOIT**

| # | Exigence | Niveau |
|---|---|---|
| 3.1 | OAuth 2.0 **Authorization Code** avec **PKCE**. | DOIT |
| 3.2 | **PKCE S256 obligatoire** ; la méthode `plain` DOIT être rejetée. | DOIT |
| 3.3 | **Dynamic Client Registration** (DCR) : endpoint d'enregistrement qui génère `client_id`/`client_secret`. | DOIT |
| 3.4 | Endpoints de **métadonnées de découverte** : `/.well-known/oauth-authorization-server` et `/.well-known/oauth-protected-resource`. | DOIT |
| 3.5 | Endpoint `/authorize` (GET) : valide `client_id`, `redirect_uri`, `code_challenge` ; affiche un **formulaire** où l'utilisateur saisit son **Account ID Unipile** (champ masqué). | DOIT |
| 3.6 | Endpoint `/authorize` (POST) : DOIT **vérifier l'`account_id` auprès d'Unipile** (compte existant/valide) **avant** d'émettre un code. Rejet → réaffiche le formulaire avec l'erreur. | DOIT |
| 3.7 | Code d'autorisation : à **usage unique**, **courte durée** (ordre de quelques minutes). | DOIT |
| 3.8 | Endpoint `/token` (POST) : valide `grant_type`, `client_id`/`client_secret`, le code, **et le PKCE** (`code_verifier`), puis émet un `access_token`. | DOIT |
| 3.9 | À l'exécution MCP, un `Authorization: Bearer <token>` DOIT être résolu en `account_id` via le store de tokens. | DOIT |
| 3.10 | Si l'authentification échoue/absente, le serveur DOIT répondre **401** avec un en-tête `WWW-Authenticate: Bearer ...` (déclenche la ré-authentification automatique côté Claude). | DOIT |

### 3b. Mode header direct (Claude Desktop) — **DOIT**

| # | Exigence | Niveau |
|---|---|---|
| 3.11 | Un en-tête direct (ex. `X-Unipile-Account-Id: <id>`) DOIT permettre de fournir l'`account_id` sans passer par OAuth. | DOIT |
| 3.12 | Ce mode direct est **prioritaire** sur le Bearer s'il est présent. | DEVRAIT |

### 3c. Cycle de vie des tokens OAuth — **DOIT**

> Aligné sur le code de référence (le code fait foi).

| # | Exigence | Niveau |
|---|---|---|
| 3.13 | Les `access_token` DOIVENT avoir un **TTL de 30 jours** (et exposer `expires_in` cohérent à l'émission). | DOIT |
| 3.14 | Les tokens DOIVENT être **persistés sur disque** : ils survivent à un redémarrage du serveur. | DOIT |
| 3.15 | Au démarrage, le serveur DOIT **recharger** les tokens persistés en **filtrant les expirés**. | DOIT |
| 3.16 | Les tokens expirés DOIVENT être **purgés** périodiquement (et la persistance mise à jour). | DOIT |

---

## 4. Endpoints HTTP attendus

| # | Endpoint | Rôle | Niveau |
|---|---|---|---|
| 4.1 | Endpoint **MCP** (racine `/` ou `/mcp`) | Point d'entrée du protocole MCP | DOIT |
| 4.2 | `GET /health` | Sonde de santé (JSON `status: ok` + nom du service + upstream) | DOIT |
| 4.3 | `/.well-known/oauth-authorization-server` | Métadonnées OAuth | DOIT |
| 4.4 | `/.well-known/oauth-protected-resource` | Métadonnées ressource protégée | DOIT |
| 4.5 | `POST /oauth/register` (ou équivalent) | DCR | DOIT |
| 4.6 | `GET` + `POST /oauth/authorize` | Autorisation + formulaire | DOIT |
| 4.7 | `POST /oauth/token` | Échange code → token | DOIT |

---

## 5. Gestion de session MCP

| # | Exigence | Niveau |
|---|---|---|
| 5.1 | Le serveur DOIT gérer des sessions MCP (transport HTTP) et réutiliser la session existante quand un identifiant de session est fourni par le client. | DOIT |
| 5.2 | Les sessions inactives DOIVENT être **purgées** après un délai (TTL, ordre de l'heure/des heures). | DOIT |
| 5.3 | Une session fermée DOIT être retirée du store. | DEVRAIT |

---

## 6. Robustesse de l'appel upstream (proxy → Unipile)

| # | Exigence | Niveau |
|---|---|---|
| 6.1 | Le serveur DOIT respecter la séquence d'initialisation MCP de l'upstream (`initialize` → `notifications/initialized` → appel réel). | DOIT |
| 6.2 | Le serveur DOIT savoir parser les réponses qu'elles soient en **SSE** (`data:`) ou en **JSON** direct. | DOIT |
| 6.3 | Des **timeouts** DOIVENT être posés sur les appels sortants. | DEVRAIT |
| 6.4 | En cas d'erreur upstream, le détail DOIT être loggé côté serveur mais l'erreur renvoyée au client DOIT rester **générique** (pas de fuite d'info sensible). | DEVRAIT |

---

## 7. Cas particulier — corps multipart / form-data

Certains appels LinkedIn (ex. édition de profil) exigent un corps `multipart/form-data`
avec *bracket notation* pour les champs imbriqués.

| # | Exigence | Niveau |
|---|---|---|
| 7.1 | Pour les endpoints qui l'exigent, le serveur DEVRAIT savoir construire un vrai corps `multipart/form-data` (boundary, `Content-Disposition`, etc.) à partir des paramètres. | DEVRAIT |

> Point de qualité, non bloquant pour une formation. À vérifier seulement si l'étudiant
> a visé les fonctions d'édition de profil.

---

## 8. Durcissement (hardening)

| # | Exigence | Niveau |
|---|---|---|
| 8.1 | **Limite de taille de payload** sur tous les endpoints HTTP (ordre de quelques dizaines de ko). | DOIT |
| 8.2 | **Rate limiting** sur les endpoints OAuth sensibles (`/authorize` POST, `/token`). | DEVRAIT |
| 8.3 | **Secrets jamais loggés** : la clé org et les tokens sont masqués dans les logs. | DOIT |
| 8.4 | **CSP stricte** sur la page du formulaire OAuth. | DEVRAIT |
| 8.5 | Container/exécution en **non-root**. | DEVRAIT |
| 8.6 | Les clients OAuth enregistrés dynamiquement DEVRAIENT avoir un TTL. | DEVRAIT |

---

## 9. Configuration (variables d'environnement)

| # | Variable | Rôle | Niveau |
|---|---|---|---|
| 9.1 | `UNIPILE_API_KEY` | Clé org, injectée comme `X-API-KEY`, jamais exposée | DOIT |
| 9.2 | `UNIPILE_BASE_URL` (DSN) | Hôte Unipile cible, validé anti-SSRF | DOIT |
| 9.3 | `PORT` | Port d'écoute (avec défaut) | DEVRAIT |
| 9.4 | `TOKENS_FILE` (ou équivalent) | Chemin de persistance des tokens OAuth sur disque (cf. §3.14) | DOIT |

> Aucun secret ne DOIT être codé en dur dans les sources.

---

## 10. Déployabilité

| # | Exigence | Niveau |
|---|---|---|
| 10.1 | Le projet DOIT fournir un moyen de build + run reproductible (ex. `Dockerfile` ou scripts clairs). | DOIT |
| 10.2 | `GET /health` DOIT répondre une fois le service lancé. | DOIT |
| 10.3 | Le projet DEVRAIT documenter (README) : variables d'env requises, commandes de build/run, endpoints. | DEVRAIT |

---

## Annexe — Checklist de conformité (à cocher par rendu)

> Imprimable. Un rendu est « conforme » si tous les **DOIT** sont cochés.
> Les **DEVRAIT** servent à noter la qualité.

**Proxy MCP**
- [ ] (1.1) Interface MCP fonctionnelle (list + call)
- [ ] (1.2) `tools/list` relaie la liste réelle d'Unipile
- [ ] (1.3) `tools/call` relaie les appels
- [ ] (1.4) Clé org **jamais** exposée au client
- [ ] (1.5) Outil synthétique `get_current_account` présent, répond sans appeler Unipile

**Isolation / sécurité multi-utilisateurs**
- [ ] (2.1) 1 session ↔ 1 `account_id`
- [ ] (2.2) `account_id` forcé sur chaque appel (test de l'`account_id` étranger réussi)
- [ ] (2.3) Liste des comptes réécrite vers le seul compte de session
- [ ] (2.4) `DELETE` compte bloqué
- [ ] (2.5) Garde SSRF sur l'hôte Unipile

**OAuth**
- [ ] (3.1) Authorization Code + PKCE
- [ ] (3.2) PKCE **S256** obligatoire, `plain` rejeté
- [ ] (3.3) Dynamic Client Registration
- [ ] (3.4) Endpoints `.well-known` présents
- [ ] (3.5) Formulaire de saisie de l'Account ID
- [ ] (3.6) Vérification de l'`account_id` auprès d'Unipile avant émission du code
- [ ] (3.7) Code à usage unique + courte durée
- [ ] (3.8) `/token` valide code + PKCE
- [ ] (3.9) Bearer → `account_id`
- [ ] (3.10) 401 + `WWW-Authenticate` si non authentifié
- [ ] (3.13) Tokens TTL 30 jours, `expires_in` cohérent
- [ ] (3.14) Tokens persistés sur disque (survivent au redémarrage)
- [ ] (3.15) Rechargement au démarrage en filtrant les expirés
- [ ] (3.16) Purge périodique des tokens expirés

**Mode direct**
- [ ] (3.11) Header `X-Unipile-Account-Id` supporté
- [ ] (3.12) Mode direct prioritaire

**Endpoints / sessions / upstream**
- [ ] (4.2) `GET /health`
- [ ] (5.1) Sessions MCP gérées et réutilisées
- [ ] (5.2) Purge des sessions inactives (TTL)
- [ ] (6.1) Séquence d'init MCP upstream respectée
- [ ] (6.2) Parsing SSE **et** JSON

**Hardening**
- [ ] (8.1) Limite de payload
- [ ] (8.3) Secrets jamais loggés
- [ ] (9.1) `UNIPILE_API_KEY` en variable d'env, jamais en dur
- [ ] (9.2) `UNIPILE_BASE_URL` validé
- [ ] (10.2) Service démarre et `/health` répond

**Qualité (DEVRAIT)**
- [ ] (1.6) Outil synthétique documenté « call first »
- [ ] (6.3) Timeouts upstream
- [ ] (6.4) Erreurs upstream génériques côté client
- [ ] (7.1) Multipart/form-data géré (si édition de profil visée)
- [ ] (8.2) Rate limiting OAuth
- [ ] (8.4) CSP du formulaire
- [ ] (8.5) Non-root
- [ ] (8.6) TTL des clients DCR
- [ ] (10.3) README complet

---

### Notes pédagogiques (pièges fréquents à surveiller en correction)

1. **Endpoint MCP** : il peut être à la racine `/` ou sur `/mcp`. Ne pas pénaliser le
   choix, vérifier juste que le client Claude s'y connecte.
2. **Le piège classique** : oublier de **forcer** l'`account_id` (2.2). Beaucoup
   d'implémentations se contentent de *fournir* l'`account_id` mais laissent passer
   celui du client → faille d'isolation. C'est LE test à faire.
3. **PKCE `plain`** : si l'étudiant accepte `plain`, c'est non conforme (3.2).
4. **Clé org dans la réponse** : vérifier qu'aucun outil ne renvoie la clé org au client.
5. **Stack libre** : Python/FastMCP, Node/SDK, etc. La grille ci-dessus ne dépend
   d'aucune techno — elle teste des comportements observables.
