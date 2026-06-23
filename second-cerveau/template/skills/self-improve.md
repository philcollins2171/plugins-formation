---
name: self-improve
description: "Détecte une erreur récurrente de Claude et formule une règle pour l'éviter, puis l'ajoute au bon fichier de config du Second Cerveau (ME.md, TOOLS.md, ou Clients/[X]/knowledge.md). Déclencher quand l'utilisateur dit '/self-improve', 'tu refais la même erreur', 'note cette règle', 'corrige ton comportement', 'évite de refaire ça', ou pour une revue hebdomadaire de feedback."
---

# /self-improve — Capture de règle anti-erreur

Détecte les erreurs récurrentes et formule une règle persistante pour les éviter dans les sessions futures.

## Pré-requis : localiser le Second Cerveau

Identifier le dossier racine du Second Cerveau (présence de `ME.md` + `TOOLS.md` + `Clients/`). Sinon, demander le chemin à l'utilisateur.

## Comportement

### 1. Identifier l'erreur

Poser ou résumer ces 3 questions :
- Quelle était l'instruction ou la demande ?
- Quelle erreur a été faite (vs ce qui était attendu) ?
- Combien de fois cela s'est-il produit (1 fois suffit si l'utilisateur veut une règle) ?

### 2. Formuler une règle générale

| Mauvais | Bon |
|---|---|
| « Ne pas faire X dans la conversation d'hier » | « Quand l'utilisateur demande Y, toujours Z » |
| « Évite cette tournure pour Acme » | « Pour les emails à des DRH, ton sobre, pas d'emoji » |

La règle doit être :
- Formulée **positivement** si possible (ce qu'il faut faire)
- **Applicable** dans des situations futures similaires
- **Courte** (1–2 lignes max)
- Accompagnée d'un **« Why: »** quand le contexte n'est pas évident (raison de la règle, pour juger les cas limites plus tard)

### 3. Router la règle

| Type de règle | Fichier destination |
|---|---|
| Style, communication, ton, anti-patterns | `ME.md`, section "Anti-patterns" |
| Outil, workflow, convention de nommage | `TOOLS.md` |
| Spécifique à un client | `Clients/[X]/knowledge.md` |

### 4. Demander confirmation

Afficher :
```
Règle proposée :
"[texte de la règle]"
Why: [raison]
Destination : [fichier]

Je l'ajoute ?
```

### 5. Appliquer (après confirmation)

- Lire le fichier cible.
- Ajouter la règle à la bonne section (créer la section si elle n'existe pas).
- Ne jamais écraser le contenu existant.

### 6. Confirmer

```
✅ Règle ajoutée dans [fichier] :
"[texte de la règle]"
```

## Anti-patterns

- ❌ Formuler une règle au passé ou liée à une conversation spécifique
- ❌ Règle trop vague (« sois meilleur »)
- ❌ Mettre une règle de style dans `TOOLS.md` (mauvais routage)
- ❌ Écrire sans confirmation utilisateur
- ❌ Oublier le **Why:** quand le contexte est non évident
