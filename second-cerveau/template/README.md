# Second Cerveau — Arborescence de base de connaissance

Projet inspiré de l'article d'Alex Bouchez :
[De prompteur à orchestrateur](https://alexbouchez.substack.com/p/de-prompteur-a-orchestrateur-le-guide)

## Principe

Un seul espace "Cowork" pour tout centraliser. Deux types de fichiers par domaine :
- `knowledge.md` — contexte stable, vrai demain
- `history.md` — événements datés, horodatés, compressé à 500 lignes max

## Arborescence

```
second-cerveau/
├── ME.md                   ← identité, ton, anti-patterns, internal_domains
├── TOOLS.md                ← outils, conventions, mappings
├── history.md              ← historique global
├── contacts.jsonl          ← mini-CRM
├── COWORK_CUSTOM_INSTRUCTIONS.md  ← texte à coller dans le champ Instructions du Project Cowork
├── .sync-state.json        ← état du dernier passage de update-memory (créé au premier run)
├── skills/
│   ├── INDEX.md            ← carte de découverte (lu en début de conv)
│   ├── assistant.md        ← concierge : installe puis aide au quotidien
│   ├── update-memory.md    ← skill central (manuel + scheduled)
│   ├── ping.md             ← skill de test
│   └── self-improve.md     ← règle anti-erreur
├── Clients/
│   └── [NomClient]/
│       ├── knowledge.md
│       ├── history.md
│       └── livrables/
├── Activity/               ← journal du jour (créé par update-memory)
│   └── YYYY-MM-DD.md
├── inbox/                  ← zones tampons gérées par update-memory
│   ├── _a_trier/
│   ├── _erreurs/
│   ├── _propositions/
│   └── _skill-improvements/
├── Marketing/
│   ├── knowledge.md
│   ├── history.md
│   └── exemples-posts/
└── Admin/
    └── factures/
```

> **Architecture Cowork-native** : ce dossier est conçu pour vivre dans **Google Drive synchronisé à un Project Cowork (Claude desktop)**. Claude lit les skills dans `skills/`, les exécute, et peut **les modifier** via le MCP Drive (auto-amélioration). Le texte à coller dans le champ "Custom Instructions" du Project est dans `COWORK_CUSTOM_INSTRUCTIONS.md`. Pas de dossier `.claude/` caché — tout est visible et naviguable par un utilisateur non-technique.

## Routage mémoire

| Information | Destination |
|---|---|
| Préférence personnelle | `ME.md` |
| Règle d'outil / workflow | `TOOLS.md` |
| Contexte stable client | `Clients/[X]/knowledge.md` |
| Événement daté | `Clients/[X]/history.md` ou `history.md` |
| Contact | `contacts.jsonl` |

## Les 5 niveaux de maturité

| Niveau | Profil |
|---|---|
| 1 | Débutant — questions ad-hoc |
| 2 | Prompteur — prompts sauvegardés, copier-coller |
| 3 | Organisateur — contexte chargé situationnellement |
| 4 | Skiller — processus packagés |
| 5 | Orchestrateur — automatisation 24/7 |

## Règles opérationnelles

**Ce qui marche**
- Un seul Project "Pro" (pas de silos par client)
- Appels explicites `/skill` (jamais implicite)
- Directions plutôt que règles rigides
- 4–5 exemples > descriptions de style
- Deux fichiers par dossier, pas plus

**Ce qui échoue**
- Un Project par client (fragmentation contextuelle)
- Mémoire native Claude activée (mélange de contextes)
- Conversations > 20–30 échanges sans /update-memory
- Données sensibles stockées dans l'espace Cowork
