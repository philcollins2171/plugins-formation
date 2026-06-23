# plugins-formation

Marketplace de plugins Claude Code de **nocodeia+** : outils de **formation** (vibe-coding) et de **déploiement client**.

> Ressources pédagogiques publiques. Ne contient aucun secret (pas de clé API, pas de
> token) : tout cela reste dans les fichiers `.env`, jamais dans un plugin.

## Plugins disponibles

| Plugin | Rôle |
|---|---|
| `mcp-unipile-grader` | Vérifie la conformité d'un serveur MCP Unipile (connecteur LinkedIn) à la spec de référence, indépendamment de la stack. Fournit le skill `verifier-conformite-mcp-unipile` et la commande `/test-mcp`. |
| `second-cerveau` | Initialise un Second Cerveau vierge prêt à déployer chez un client (base de connaissance Cowork). Fournit la commande `/init-second-cerveau`. |

## Installation

Dans Claude Code, ajoute le marketplace une seule fois :

```
/plugin marketplace add philcollins2171/plugins-formation
```

Puis installe le plugin correspondant à ton besoin :

```
# Apprenti vibe-coding — auto-évaluer son MCP Unipile
/plugin install mcp-unipile-grader@plugins-formation

# Déployeur / formateur — générer un Second Cerveau client
/plugin install second-cerveau@plugins-formation
```

## Utilisation

### Plugin `mcp-unipile-grader`

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

### Plugin `second-cerveau`

Pour le **déployeur/formateur** : génère un Second Cerveau vierge à copier dans le
Google Drive d'un client. Le client final, lui, n'utilise que Cowork (claude.ai), pas
Claude Code.

```
/init-second-cerveau Cabinet Dupont
```

Crée un dossier `cabinet-dupont-second-cerveau/` dans le répertoire courant :
arborescence complète, skills génériques (`assistant`, `update-memory`, `ping`,
`self-improve`) et le premier dossier `Clients/Cabinet Dupont/`. Aucune donnée n'est
inventée : seul le nom du client est renseigné, le reste est rempli côté Cowork via
« installe mon cerveau ». Suis ensuite le `GUIDE_DEMARRAGE.md` à la racine du dossier
généré (Drive -> Project -> Custom Instructions).

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
   `.claude-plugin/marketplace.json` **et** dans le `plugin.json` du plugin concerné
   (`mcp-unipile-grader/.claude-plugin/plugin.json`,
   `second-cerveau/.claude-plugin/plugin.json`), puis `git push`.

> Garde toujours un `version` explicite : sans lui, chaque commit deviendrait une
> « version » et se propagerait automatiquement aux apprentis.

## Structure

```
plugins-formation/
├── .claude-plugin/
│   └── marketplace.json                 # catalogue
├── mcp-unipile-grader/
│   ├── .claude-plugin/
│   │   └── plugin.json                  # manifeste du plugin
│   ├── skills/
│   │   └── verifier-conformite-mcp-unipile/
│   │       ├── SKILL.md
│   │       ├── spec-mcp-unipile.md       # spec + checklist (référence)
│   │       └── prompt-claude-mcp-unipile.md
│   ├── commands/
│   │   └── test-mcp.md                   # slash command /test-mcp
│   └── scripts/
│       └── test-conformite.sh           # tests curl automatiques
└── second-cerveau/
    ├── .claude-plugin/
    │   └── plugin.json                  # manifeste du plugin
    ├── commands/
    │   └── init-second-cerveau.md       # slash command /init-second-cerveau
    └── template/                         # kit vierge embarqué (copié chez le client)
        ├── ME.md, TOOLS.md, GUIDE_DEMARRAGE.md, ...
        ├── skills/                       # assistant, update-memory, ping, self-improve
        └── Clients/_template/            # squelette à dupliquer par client
```
