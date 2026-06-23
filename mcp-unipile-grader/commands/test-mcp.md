---
description: Lance les tests automatiques de conformité d'un serveur MCP Unipile à une URL donnée
argument-hint: <URL_DU_SERVEUR>
---

Tu vas tester la conformité d'un serveur MCP Unipile.

URL cible fournie par l'utilisateur : $ARGUMENTS

Étapes :

1. Si aucune URL n'est fournie ci-dessus, demande-la (ex. `http://localhost:3101` ou
   l'URL publique du serveur).
2. Exécute le script de test fourni par ce plugin :
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/test-conformite.sh <URL>`
3. Lis la sortie et présente un **rapport clair** :
   - liste des `[PASS]` et `[FAIL]` automatiques ;
   - rappelle les vérifications manuelles restantes (isolation de l'`account_id`,
     blocage `DELETE`, persistance des tokens, non-exposition de la clé org).
4. Pour chaque `[FAIL]`, propose une piste de correction et indique l'exigence concernée
   de la spec (numéro entre parenthèses).
5. Si l'endpoint MCP n'est pas à la racine `/` mais sur `/mcp`, signale-le : ce n'est pas
   une non-conformité, mais le test 3.10 doit être relancé en adaptant l'URL.

Pour le détail des exigences, réfère-toi au skill `verifier-conformite-mcp-unipile`
(fichier `spec-mcp-unipile.md`). N'invente aucune exigence hors spec, et ne conclus
jamais « conforme » sans avoir réellement exécuté le script et montré sa sortie.
