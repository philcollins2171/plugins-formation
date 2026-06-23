# TOOLS.md — Outils et conventions

## Suite outils
| Outil | Usage principal | Connector disponible |
|---|---|---|
| VS Code | Édition de code et fichiers .md | — |
| Claude Code (terminal) | Édition assistée du repo, exécution des skills | — |
| Google Drive | Stockage du Second Cerveau (synchro Cowork) | MCP Drive |
| Git / GitHub | Versioning (optionnel) | — |

## Conventions d'usage

### Email
- Toujours proposer un brouillon, jamais envoyer directement
- Objet : court, factuel, sans "URGENT" abusif
- Signature : [modèle de signature]

### Documents
- Nommage : `YYYYMMDD_[client]_[type].pdf`
- Stockage livrables : `Clients/[NomClient]/livrables/`

### Facturation
- Format devis : `Admin/factures/DEVIS_[N]_[client].pdf`
- Format facture : `Admin/factures/FAC_[N]_[client].pdf`

## Skills disponibles

| Skill | Déclencheur | Description |
|---|---|---|
| `/update-memory` | Fin de session | Scanne et sauvegarde ce qui doit persister |
| `/self-improve` | Erreur répétée | Formule une règle et l'ajoute aux fichiers |
| [à compléter] | | |

## Règle de création de skill

> Si j'explique le même processus 2× par semaine à Claude → créer un skill.
