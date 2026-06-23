# plugins-formation

Marketplace de plugins Claude Code pour la **formation vibe-coding**.

> Ressources pédagogiques publiques. Ne contient aucun secret (pas de clé API, pas de
> token) : tout cela reste dans les fichiers `.env`, jamais dans un plugin.

## Plugins disponibles

| Plugin | Rôle |
|---|---|
| `mcp-unipile-grader` | Vérifie la conformité d'un serveur MCP Unipile (connecteur LinkedIn) à la spec de référence, indépendamment de la stack. Fournit le skill `verifier-conformite-mcp-unipile` et la commande `/test-mcp`. |

## Installation (à faire une fois par apprenti)

Dans Claude Code :

```
/plugin marketplace add philcollins2171/plugins-formation
/plugin install mcp-unipile-grader@plugins-formation
```

## Utilisation

- **Auto-évaluer son rendu** : demande simplement « vérifie la conformité de mon MCP
  Unipile » — le skill `verifier-conformite-mcp-unipile` s'active et te guide.
- **Lancer les tests automatiques** :
  ```
  /test-mcp http://localhost:3101
  ```
  (ou l'URL publique de ton serveur)

Le test automatique couvre les vérifications sans authentification (`/health`, 401,
métadonnées OAuth, rejet PKCE `plain`). Les vérifications nécessitant une session
authentifiée (isolation de l'`account_id`, blocage `DELETE`, persistance des tokens)
sont rappelées et se font manuellement ou par revue de code.

## Mise à jour

Quand le formateur publie une nouvelle version :

```
/plugin marketplace update plugins-formation
/reload-plugins
```

## Pour le formateur — publier ce marketplace

1. Crée un dépôt **public** nommé `plugins-formation` sur ton compte/organisation GitHub.
2. Pousse le contenu de ce dossier à la **racine** du dépôt (le fichier
   `.claude-plugin/marketplace.json` doit être à la racine).
3. À chaque correction : bump le champ `version` dans
   `.claude-plugin/marketplace.json` **et** dans
   `mcp-unipile-grader/.claude-plugin/plugin.json`, puis `git push`.

> Garde toujours un `version` explicite : sans lui, chaque commit deviendrait une
> « version » et se propagerait automatiquement aux apprentis.

## Structure

```
plugins-formation/
├── .claude-plugin/
│   └── marketplace.json                 # catalogue
└── mcp-unipile-grader/
    ├── .claude-plugin/
    │   └── plugin.json                  # manifeste du plugin
    ├── skills/
    │   └── verifier-conformite-mcp-unipile/
    │       ├── SKILL.md
    │       ├── spec-mcp-unipile.md       # spec + checklist (référence)
    │       └── prompt-claude-mcp-unipile.md
    ├── commands/
    │   └── test-mcp.md                   # slash command /test-mcp
    └── scripts/
        └── test-conformite.sh           # tests curl automatiques
```
