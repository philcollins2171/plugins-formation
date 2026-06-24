---
description: Lance les tests automatiques de conformité d'un serveur MCP Unipile (HTTP ou stdio)
argument-hint: --http <URL> | --stdio "<commande>" [--account-id <id>]
---

Tu vas tester la conformité d'un serveur MCP Unipile. Deux transports sont possibles :

- **HTTP (VPS, OAuth)** : `--http <URL>` (ou simplement `<URL>` en rétrocompat).
- **stdio (local, account_id en argument CLI)** : `--stdio "<commande de lancement>"`,
  avec en option `--account-id <id>` pour vérifier la valeur exacte renvoyée par
  `get_current_account`.

Arguments fournis par l'utilisateur : $ARGUMENTS

Étapes :

1. Si aucun argument n'est fourni ci-dessus, demande le mode et la cible :
   - HTTP : l'URL du serveur (ex. `http://localhost:3101` ou l'URL publique) ;
   - stdio : la commande qui lance le serveur, account_id inclus
     (ex. `node server.js --account-id ABC123` ou `python3 -m monmcp --account-id ABC123`).
2. Exécute le script fourni par ce plugin avec les arguments tels quels :
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/test-conformite.sh <arguments>`
   Exemples :
   - `bash ${CLAUDE_PLUGIN_ROOT}/scripts/test-conformite.sh --http https://mcp-linkedin.exemple.fr`
   - `bash ${CLAUDE_PLUGIN_ROOT}/scripts/test-conformite.sh --stdio "node server.js --account-id ABC123" --account-id ABC123`
3. Lis la sortie et présente un **rapport clair**, en précisant **quelle grille** a été
   appliquée (HTTP ou stdio) :
   - liste des `[PASS]` et `[FAIL]` automatiques ;
   - rappelle les vérifications manuelles restantes affichées par le script.
     - En **HTTP** : isolation de l'`account_id`, blocage `DELETE`, persistance des
       tokens, non-exposition de la clé org.
     - En **stdio** : `account_id` forcé (2.2), réécriture liste comptes (2.3), `DELETE`
       bloqué (2.4), garde SSRF (2.5), relais réel `tools/list`/`tools/call` (1.2/1.3),
       séquence d'init + parsing upstream (6.1/6.2). Ces points nécessitent de vraies
       creds Unipile et se vérifient par revue de code ou test manuel.
4. Pour chaque `[FAIL]`, propose une piste de correction et indique l'exigence concernée
   de la spec (numéro entre parenthèses).
5. En **mode HTTP uniquement** : si l'endpoint MCP n'est pas à la racine `/` mais sur
   `/mcp`, signale-le ; ce n'est pas une non-conformité, mais le test 3.10 doit être
   relancé en adaptant l'URL.

Pour le détail des exigences, réfère-toi au skill `verifier-conformite-mcp-unipile`
(fichier `spec-mcp-unipile.md`). La grille **HTTP** est le corps de la spec ; la grille
**stdio** (réduite) est l'**Annexe B** de ce même fichier. N'invente aucune exigence hors
spec, et ne conclus jamais « conforme » sans avoir réellement exécuté le script et montré
sa sortie.
