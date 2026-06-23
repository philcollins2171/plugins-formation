---
name: ping
description: "Mini skill de test. Vérifie que les skills du Second Cerveau sont bien visibles et exécutables depuis Cowork ou Claude Code. Répond avec une confirmation + écrit une trace dans inbox/_ping/. Déclencher : '/ping', 'ping cerveau', 'test skill', 'tu me vois ?', 'le skill marche ?'."
---

# /ping — Mini skill de test du Second Cerveau

Skill très simple pour vérifier que le mécanisme de skills marche bien dans Cowork (ou Claude Code).

## Comportement (3 actions, dans l'ordre)

### 1. Confirme verbalement dans le chat

Afficher exactement ce message (en remplaçant la date/heure par celle du moment) :

```
✅ Pong ! Le skill /ping est bien actif.
Le second cerveau te voit.

Heure : YYYY-MM-DD HH:MM
```

### 2. Mini diagnostic

Juste après le message ci-dessus, afficher en 3 lignes :

```
🔍 Diagnostic rapide :
- Fichiers du Project visibles : [nombre]
- MCPs connectés : [liste des noms, ex: Gmail, Calendar, Drive]
- État du cerveau : [neuf | initialisé] (présence de .sync-state.json)
```

### 3. Écrit une trace

Créer le fichier `inbox/_ping/YYYY-MM-DD-HHMM.md` (créer le dossier s'il manque) avec ce contenu :

```markdown
# Ping — YYYY-MM-DD HH:MM

- Trigger utilisé : [phrase exacte de l'utilisateur]
- Fichiers Project visibles : [nombre]
- MCPs détectés : [liste]
- .sync-state.json présent : [oui | non]
- Statut : OK
```

## Anti-patterns

- ❌ Ne pas faire autre chose que ces 3 actions
- ❌ Ne pas lire le contenu des fichiers (juste les compter)
- ❌ Ne pas modifier quoi que ce soit en dehors de `inbox/_ping/`
- ❌ Pas de jargon technique dans la réponse chat — l'utilisateur est non-tech
