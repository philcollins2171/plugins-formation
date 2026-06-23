# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet : Second Cerveau — Base de connaissance centralisée

**Second Cerveau** est une base de connaissance personnelle, conçue pour vivre dans un Project Cowork (Claude) synchronisé à Google Drive. Inspirée de l'article d'Alex Bouchez [« De prompteur à orchestrateur »](https://alexbouchez.substack.com/p/de-prompteur-a-orchestrateur-le-guide).

## Architecture

### Principe fondamental

Un seul espace "Cowork" pour tout centraliser. **Deux fichiers par domaine** :
- `knowledge.md` — contexte stable (vrai demain et au-delà)
- `history.md` — événements datés, horodatés, compressé à **max 500 lignes**

### Structure arborescence

```
second-cerveau/
├── ME.md                   ← identité, ton, anti-patterns
├── TOOLS.md                ← outils, conventions, mappings
├── history.md              ← historique global (dates + heures)
├── contacts.jsonl          ← mini-CRM (format JSONL)
├── COWORK_CUSTOM_INSTRUCTIONS.md  ← texte à coller dans le champ Instructions du Project Cowork
├── .sync-state.json        ← état du dernier passage de update-memory (créé au premier run)
├── skills/                 ← tous les skills (un .md ou un dossier par skill)
│   ├── INDEX.md            ← carte de découverte des skills (lu en début de conv)
│   ├── assistant.md        ← concierge : installe le cerveau puis aide au quotidien
│   ├── update-memory.md    ← skill central (manuel + scheduled)
│   ├── ping.md             ← skill de test
│   └── self-improve.md     ← formuler une règle anti-erreur
├── Clients/
│   ├── _template/          ← squelette à copier pour un nouveau client
│   └── [NomClient]/
│       ├── knowledge.md    ← contexte client stable
│       ├── history.md      ← événements client datés
│       └── livrables/      ← documents livrés
├── Activity/               ← journal du jour (1 fichier par jour, créé par update-memory)
│   └── YYYY-MM-DD.md
├── inbox/                  ← zones tampons gérées par update-memory
│   ├── _a_trier/           ← items ambigus à clarifier
│   ├── _erreurs/           ← logs d'erreurs (MCP KO, parsing failed)
│   ├── _propositions/      ← suggestions d'amélioration du système
│   └── _skill-improvements/  ← patchs proposés ou auto-appliqués sur les skills
├── Marketing/
│   ├── knowledge.md
│   ├── history.md
│   └── exemples-posts/     ← brouillons de posts
└── Admin/
    └── factures/           ← devis et factures (format PDF)
```

### Routage d'informations

| Information | Fichier destination |
|---|---|
| Préférence personnelle | `ME.md` |
| Règle d'outil / workflow | `TOOLS.md` |
| Contexte stable client | `Clients/[X]/knowledge.md` |
| Événement daté | `Clients/[X]/history.md` ou `history.md` global |
| Contact (email, téléphone, LinkedIn) | `contacts.jsonl` |
| Signature email, template facture | `TOOLS.md` (modèles) |

## Conventions

### Dates et horodatage

Format : `YYYY-MM-DD HH:MM — [description]`

Exemple :
```
2026-01-15 14:46 — Mise en place du second cerveau
```

### Nommage fichiers

**Documents livrables** : `YYYYMMDD_[client]_[type].pdf`
- Exemple : `20260115_client_cadrage_technique.pdf`

**Devis** : `Admin/factures/DEVIS_[N]_[client].pdf`
- Exemple : `DEVIS_001_client.pdf`

**Factures** : `Admin/factures/FAC_[N]_[client].pdf`
- Exemple : `FAC_001_client.pdf`

### Compression d'historique

Quand `history.md` dépasse 500 lignes → archiver les entrées les plus anciennes dans un fichier `history-archive-[YYYY].md` et garder les derniers 500 lignes.

## Profil utilisateur

Le profil de l'utilisateur (identité, ton attendu, anti-patterns, niveau technique) est décrit dans `ME.md`. À lire en début de session pour adapter le ton et le style des réponses.

## Cas d'usage

Le second cerveau doit servir aux usages suivants :

- **Vue 360 quotidienne** — agréger l'état du jour (tâches, RDV, livrables en cours)
- **Mémoire des interlocuteurs** — retrouver qui est qui, ton, historique d'échanges
- **Sortie de RDV** — transcription → actions extraites + suivi
- **Préparation de RDV en hypothèse** — anticiper le contenu et les questions
- **Génération de docs depuis entrée brute** — ex : photo → facture, demande → cadrage
- **Journal et veille** — consigner et retrouver les sources, articles, références

## Skills disponibles

Tous les skills vivent dans `skills/` à la racine. Voir `skills/INDEX.md` pour la carte complète avec déclencheurs.

Vue d'ensemble :

| Skill | Quand l'utiliser | Mode déclenchement |
|---|---|---|
| `assistant` | Concierge : installe le cerveau (1re fois) puis aide au quotidien — pour utilisateur non-technique | langage naturel |
| `update-memory` | Mettre à jour le cerveau (manuel sur conv, ou scheduled sur sources externes) | natif + Scheduled Task Cowork |
| `ping` | Test que les skills marchent | manuel |
| `self-improve` | Formuler une règle anti-erreur récurrente | manuel |

**Règle de création** : si tu expliques le même processus 2× par semaine à Claude → créer un skill (un fichier `skills/[nom].md` + une ligne dans `skills/INDEX.md`).

## Architecture Cowork-native

Le second cerveau est conçu pour vivre dans **Cowork (Claude desktop / claude.ai)** :

- Fichiers stockés dans **Google Drive** (synchronisé au Project Cowork via MCP Drive)
- Skills lisibles et **modifiables** par Claude via MCP Drive (auto-amélioration possible)
- Pas de `.claude/` caché — tout est dans `skills/` visible et naviguable
- Le texte à coller dans le champ "Custom Instructions" du Project est dans `COWORK_CUSTOM_INSTRUCTIONS.md`

> Note : ce dossier peut aussi être ouvert avec **Claude Code** (terminal) pour développer/déboguer les skills, mais la cible d'usage est Cowork.

## Règles opérationnelles

### ✅ Ce qui marche

- Un seul Project "Pro" (pas de silos par client)
- Appels explicites `/skill` (jamais implicite)
- Directions plutôt que règles rigides
- 4–5 exemples > descriptions de style
- Deux fichiers par dossier, pas plus
- Historique compressé régulièrement (max 500 lignes)

### ❌ Ce qui échoue

- Un Project par client (fragmentation contextuelle)
- Mémoire native Claude activée (mélange de contextes)
- Conversations > 20–30 échanges sans `/update-memory`
- Données sensibles dans l'espace Cowork
- Plus de deux fichiers par domaine (dilatation du contexte)

## Les 5 niveaux de maturité

| Niveau | Profil | Exemple |
|---|---|---|
| 1 | Débutant | Questions ad-hoc, pas de structure |
| 2 | Prompteur | Prompts sauvegardés, copier-coller |
| 3 | Organisateur | Contexte chargé situationnellement |
| 4 | Skiller | Processus packagés dans des skills |
| 5 | Orchestrateur | Automatisation 24/7 (n8n, webhooks) |

## Outils

| Outil | Usage | Notes |
|---|---|---|
| Cowork (Claude) | Usage quotidien du second cerveau | Cible principale |
| Google Drive | Stockage des fichiers du cerveau | Synchro via MCP Drive |
| VS Code | Édition fichiers .md et config | Optionnel |
| Claude Code | Édition repo + exécution skills | Terminal, optionnel |
| Git / GitHub | Versioning | Optionnel |
