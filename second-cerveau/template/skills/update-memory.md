---
name: update-memory
description: "Mise à jour du Second Cerveau. Deux modes auto-détectés. (1) MANUEL — scanne la conversation en cours, propose, demande confirmation, écrit dans knowledge.md / history.md / ME.md / TOOLS.md / contacts.jsonl. (2) SCHEDULED — lit Gmail + Calendar + Drive depuis le dernier passage, détecte nouveaux clients, met à jour les fichiers existants, crée les dossiers clients neufs, log l'activité du jour dans Activity/, sans aucune action utilisateur. Déclencher : '/update-memory', 'update memory', 'mets à jour la mémoire', 'sauvegarde le contexte', 'fin de session', 'mode scheduled', 'scheduled task', 'sync cerveau', ou via Scheduled Task Cowork."
---

# /update-memory — Mise à jour du Second Cerveau

Le skill a **deux modes** auto-détectés :

| Mode | Déclenchement | Comportement |
|---|---|---|
| **MANUEL** | Utilisateur dit `/update-memory` au milieu d'une conv | Scanne la conv, propose, **demande confirmation**, écrit |
| **SCHEDULED** | Aucun contexte conversationnel préalable, ou prompt contient `scheduled` / `mode scheduled` / `sync cerveau` / déclenché par Scheduled Task Cowork | Lit **Gmail + Calendar + Drive**, écrit direct sans confirmation, log dans `Activity/YYYY-MM-DD.md` |

## Pré-requis : localiser le Second Cerveau

Avant toute action, identifier le dossier racine du Second Cerveau :

1. Si tu travailles dans un dossier qui contient `CLAUDE.md` mentionnant "Second Cerveau" ou la structure `ME.md` + `TOOLS.md` + `Clients/` → c'est la racine.
2. En Cowork avec MCP Drive : la racine est le dossier Drive `Cerveau/` (ou celui défini dans les Custom Instructions du Project).
3. Sinon, demander à l'utilisateur le chemin de son Second Cerveau.

Tous les chemins ci-dessous sont relatifs à cette racine.

---

# MODE 1 — MANUEL

## 1. Scanner la conversation

Identifier tout ce qui répond "oui" au test : **« Est-ce que c'est vrai demain ? »**

Routage :
- Nouvelles informations stables sur un client → `Clients/[X]/knowledge.md`
- Événements datés (réunion, décision, livraison) → `Clients/[X]/history.md` ou `history.md` global
- Préférence personnelle découverte (ton, anti-pattern, méthode de travail) → `ME.md`
- Nouvelle règle d'outil / workflow → `TOOLS.md`
- Nouveau contact (email, téléphone, LinkedIn, rôle) → `contacts.jsonl`

Ne **jamais** sauvegarder : détails éphémères, code dérivable des fichiers, données sensibles (mots de passe, identifiants).

## 2. Proposer les mises à jour

```
À sauvegarder :
- Clients/Acme/knowledge.md : ajout interlocuteur "Jean Martin, DRH"
- Clients/Acme/history.md : 2026-05-07 14:30 — décision sur pricing
- ME.md : préférence "pas de listes pour les réponses courtes"
- contacts.jsonl : Jean Martin <jean@acme.fr>, DRH Acme
```

**Demander confirmation explicite** avant d'écrire.

## 3. Appliquer

- Ajouter (jamais écraser).
- Format `history.md` : `YYYY-MM-DD HH:MM — [description]` (date du jour récupérée via outil).
- Format `contacts.jsonl` : 1 ligne JSON par contact, ex :
  ```json
  {"nom": "Jean Martin", "email": "jean@acme.fr", "role": "DRH", "client": "Acme", "ajoute_le": "2026-05-07"}
  ```

## 4. Compresser si nécessaire

Si un `history.md` dépasse **500 lignes** : compresser le trimestre le plus ancien en 10–15 lignes, garder les 3 derniers mois intacts. Si l'année change : archiver dans `history-archive-[YYYY].md`.

## 5. Confirmer

```
✅ Mémoire mise à jour — [N] fichiers modifiés
- [chemin1]
- [chemin2]
```

---

# MODE 2 — SCHEDULED

Déclenché par une Scheduled Task Cowork (typiquement 1×/jour le soir).
**Pas de confirmation utilisateur. Pas de scan de conversation directe (mais on lit l'historique des conversations Cowork si exposé).**
On lit toutes les sources accessibles via les MCPs du Project.

## Principes de jugement (autonomie & adaptabilité)

Le skill tourne pour un utilisateur **non-technique** (typiquement un dirigeant). Il doit prendre la **meilleure décision possible à chaque fois**, **jamais demander d'expertise** ni bloquer pour intervention humaine.

Règles de jugement :

1. **Si tu ne sais pas → ne range pas** : tout item flou va dans `inbox/_a_trier/YYYY-MM-DD.md` avec un résumé. Pas de placeholder vide qui pollue.
2. **Tu connais pas une source ? Lis-la quand même** : si un nouveau MCP apparaît dans le Project (ex: Notion, Slack, GitHub), tente une lecture exploratoire et adapte. Tu ne dois jamais ignorer une source potentielle.
3. **Erreur d'un MCP → continue avec les autres** : si Gmail timeout / Drive 503, log dans `inbox/_erreurs/YYYY-MM-DD.md` et passe à la suite. Jamais d'arrêt total.
4. **Tu repères un pattern récurrent (3+ fois) → propose une amélioration** : ex: « l'utilisateur met toujours ses factures dans Drive/Factures avant le 5 du mois → suggérer un Scheduled Task de relance ». Stocker dans `inbox/_propositions/YYYY-MM-DD.md`.
5. **Tu vois une info qui contredit knowledge.md existant** :
   - Si la nouvelle source est plus récente ET vient d'un canal fiable (mail direct du contact, RDV confirmé) → mets à jour le knowledge.md avec note `<!-- mis à jour le YYYY-MM-DD depuis [source] -->`
   - Sinon → flag dans `_a_trier/`
6. **Adapte ton vocabulaire à l'utilisateur** : si tu écris une notif ou une note dans `_a_trier/`, utilise des mots simples (pas de jargon tech). L'utilisateur ne sait pas ce qu'est un "MCP" ou un "JSON".

## Étape 0 — Vérification d'environnement et pressure test

**Avant toute lecture/écriture**, le skill fait un check complet de son environnement et un mini pressure test. Si quelque chose manque, il bascule en mode dégradé approprié (cf. § Modes dégradés ci-dessous). Il n'avorte jamais.

### 0.1 — Inventaire des accès

Pour chaque MCP attendu, vérifier la disponibilité avec une lecture triviale :

| MCP | Test de vie | Comportement si KO |
|---|---|---|
| Gmail | `search_threads(query="in:inbox", max=1)` | passer en mode "Gmail KO" |
| Calendar | `list_calendars()` | passer en mode "Calendar KO" |
| Drive | `list_recent_files(max=1)` | passer en mode "Drive KO" — **critique**, on perd l'écriture |
| Conversations Cowork | introspection MCP | skip si absent |
| Autres MCPs | introspection | catalogue, à explorer |

Stocker le résultat dans une variable `env_state` qui guide tout le reste du run.

### 0.2 — Pressure test sur données fictives

Si Gmail OK, faire un mini parse sur 3 mails imaginés (3 cas typiques) :
1. Mail entrant d'un nouveau prospect demandant un RDV
2. Mail de notification interne (à skipper)
3. Mail d'un client existant avec décision business

Vérifier que le routage interne produit le bon résultat (sans écrire). Si les 3 résultats sont incohérents → mode "safe" (lit mais n'écrit pas, juste logue dans `_a_trier/` ce qui aurait été fait).

### 0.3 — Self-check du second cerveau

Vérifier l'intégrité de la structure :
- `.sync-state.json` existe et est lisible (sinon : s'il est **manquant** → premier run, `last_run = NOW - 100 jours` ; s'il est **corrompu** → `last_run = NOW - 7 jours`)
- `Clients/` existe
- `ME.md`, `TOOLS.md` lisibles
- `Activity/` existe (sinon le créer)
- `inbox/_a_trier/`, `inbox/_erreurs/`, `inbox/_propositions/`, `inbox/_skill-improvements/` existent (sinon créer)

Toute brique manquante → recréer, logger dans `_erreurs/YYYY-MM-DD.md`, continuer.

### 0.4 — Décision : run normal, dégradé, ou safe

Combiner les résultats en mode opérationnel :

| Env | Mode |
|---|---|
| Tous MCPs OK + pressure test OK | **NORMAL** : workflow complet |
| 1+ MCP KO mais Drive OK | **DÉGRADÉ** : sources disponibles seulement, écriture OK |
| Drive KO | **READ-ONLY** : ne peut pas écrire dans le 2C → notifier Cowork puis sortir |
| Pressure test KO | **SAFE** : tout passe en `_a_trier/`, rien d'autre |
| Aucun MCP du tout | **MINIMAL** : notif Cowork "Je suis bloqué, vérifie tes connexions" en français simple, puis sortir |

## Étape 1 — Récupérer l'état du dernier passage

Lire `.sync-state.json` à la racine du second cerveau :

```json
{
  "last_run": "2026-05-28T18:00:00+02:00",
  "stats_last_run": {
    "events_added": 7,
    "clients_created": 1,
    "contacts_added": 2,
    "items_a_trier": 0
  }
}
```

Si le fichier n'existe pas → premier run, considérer `last_run = NOW - 100 jours` (bootstrap initial sur ~3 mois).

## Étape 2 — Scanner les sources

### Gmail (via MCP `search_threads` / `get_thread`)

Récupérer les threads avec activité (reçu OU envoyé) depuis `last_run`.

**Exclure systématiquement** :
- expéditeurs `noreply@`, `no-reply@`, `donotreply@`, `mailer-daemon@`, `postmaster@`
- newsletters / notifications (labels Gmail `Promotions`, `Updates`, `Forums`, `Social`)
- threads dont le sujet contient "Cerveau MAJ" (auto-notifications passées)
- expéditeurs du domaine interne (à lire dans `ME.md` → `internal_domains`, ex: `votredomaine.fr`)

### Calendar (via MCP `list_events`)

Récupérer events de la fenêtre `[last_run, NOW + 24h]` :
- passés récents (pour débrief) + futurs imminents (pour prep RDV)

### Drive (via MCP `search_files` / `list_recent_files`)

Récupérer les fichiers ajoutés depuis `last_run` dans `inbox/` :
- Fichiers à la racine de `inbox/` → à trier
- Sous-dossier `inbox/[NomClient]/` créé par l'utilisateur → **signal explicite** de nouveau client

### Conversations Cowork (si MCP exposé)

Si un MCP "Conversations" ou équivalent est disponible :
- Lister les conversations Cowork de l'utilisateur depuis `last_run`
- Pour chaque conv : extraire titre, date, sujet, personnes mentionnées, décisions prises
- Croiser avec Gmail/Calendar pour éviter doublons (souvent une conv = retour d'un RDV qui est déjà capté par Calendar)
- Si pas de MCP "Conversations" disponible → skip cette étape sans erreur

### Tout autre MCP connecté au Project

À chaque run, **lister les MCPs disponibles** dans le Project Cowork. Pour chaque MCP non géré ci-dessus :

| MCP | Comportement |
|---|---|
| Notion | Lire les pages modifiées depuis `last_run`, extraire les pages ressemblant à des notes RDV / clients |
| GitHub | Lire les commits / issues / PR récents pertinents |
| Slack / Discord | Lire les channels marqués "pro" si exposés |
| Spotify / AllTrails / autre perso | Ignorer (pas info pro) |
| MCP inconnu | Tenter une lecture exploratoire (lister ressources), log dans `_propositions/` ce qu'on peut en faire |

**Règle générale** : un MCP utile = un MCP qui parle de pro (client, RDV, doc, décision). Tout le reste = skip.

## Étape 3 — Inventaire (réflexion Claude)

Pour chaque mail / event / fichier nouveau, extraire :

| Champ | Description |
|---|---|
| **sujet** | 1 ligne descriptive |
| **personnes** | nom + email + rôle si déductible |
| **date** | `YYYY-MM-DD HH:MM` |
| **client_identifié** | `existing(NomDossier)` / `new(NomPropose)` / `none` |
| **nature** | `action` / `décision` / `info_stable` / `livrable` / `nouveau_contact` / `rdv` |

## Étape 4 — Routage et écriture

Pour chaque item identifié :

| Cas | Action |
|---|---|
| `client_existing` + `action` / `décision` / `rdv` | append à `Clients/X/history.md` |
| `client_existing` + `info_stable` (rôle, deadline, pricing) | edit `Clients/X/knowledge.md` (section correspondante) |
| `client_new` | créer `Clients/[NouveauNom]/` avec scaffold `knowledge.md` + `history.md` pré-remplis depuis ce qu'on sait (cf. § 4.1) |
| `nouveau_contact` (pas un client à lui seul) | append à `contacts.jsonl` |
| `none` (info globale) | append à `history.md` racine |

### 4.1 — Heuristique "nouveau client"

**Seuil bas** : 1 seul signal suffit. **Mais** garde-fous obligatoires.

**Créer un nouveau client si AU MOINS UN** :
- mail entrant d'un domaine pro inconnu mentionnant RDV / cadrage / demande / projet / proposition
- event Calendar avec personne inconnue + sujet pro (kickoff, présentation, RDV, démo, cadrage)
- L'utilisateur a déposé un dossier explicite `inbox/[Nom]/` (force le routage)
- échange déjà vu mais avec progression claire (envoi de doc, fixage de RDV, etc.)

**SKIP si** :
- domaine interne (lire `internal_domains` dans `ME.md`)
- personne déjà dans `contacts.jsonl` avec autre rôle (ex: encadrant)
- mail typé marketing / commercial sortant générique
- expéditeur exclu (cf. Étape 2)

**Si ambigu** (Claude n'est pas certain à >70%) :
- Ne **pas** créer de `Clients/X/`
- Append à `inbox/_a_trier/YYYY-MM-DD.md` avec un résumé de 5 lignes
- Le compter dans `stats.items_a_trier`

### 4.2 — Scaffold d'un nouveau client

Quand Claude crée `Clients/[NouveauNom]/`, pré-remplir depuis ce qu'on a vu :

`knowledge.md` :
```markdown
# knowledge.md — [NouveauNom]

> Créé automatiquement le [DATE] par sync auto depuis [source].
> À enrichir au prochain échange.

## Entreprise
- **Secteur** : [deviné depuis domaine / signature mail, sinon "à confirmer"]
- **Taille** : à confirmer
- **Site** : [domaine si déductible]

## Interlocuteurs
| Nom | Rôle | Email | Ton |
|---|---|---|---|
| [Nom détecté] | [rôle si signature] | [email] | à découvrir |

## Contexte commercial
- **Origine** : [comment ils sont arrivés, ex: "mail entrant 2026-05-28 demandant un cadrage"]
- **Besoin exprimé** : [résumé du premier échange]
- **Budget évoqué** : à confirmer
- **Décideur** : à confirmer

## Prochaine action
- [extraite du mail si claire, sinon "rappeler / recadrer"]
```

`history.md` :
```markdown
# history.md — [NouveauNom]

> Événements datés.
> Format : `YYYY-MM-DD HH:MM — [description]`

---

[DATE source] — **Première détection** : [résumé du mail/event ayant déclenché la création de la fiche].
```

### 4.3 — Anti-doublons

Avant d'append un event à `history.md`, vérifier qu'une ligne avec la même date + même sujet n'existe pas déjà. Si oui, skip.

Avant d'ajouter un contact à `contacts.jsonl`, vérifier que l'email n'existe pas déjà. Si oui, **mettre à jour** la ligne existante au lieu d'en créer une nouvelle.

## Étape 5 — Journal du jour (`Activity/YYYY-MM-DD.md`)

Créer ou append `Activity/YYYY-MM-DD.md` :

```markdown
# Activité — YYYY-MM-DD

## Ce que l'utilisateur a fait
- HH:MM — RDV [client] : [résumé décision en 1 ligne]
- HH:MM — mail envoyé à [contact] sujet [sujet]
- HH:MM — mail reçu de [contact] sujet [sujet]
- HH:MM — fichier déposé dans inbox/ : [nom du fichier]

## Nouveau dans le cerveau
- Client créé : **[Nom]** — source : [mail / calendar / drive]
- Contact ajouté : [Nom] `<email>` — [rôle]

## À trier (items ambigus)
- [item 1, court résumé]
```

Et une seule ligne récap dans `history.md` racine :
```
YYYY-MM-DD — sync auto : N events, M nouveaux clients, X contacts, Y à trier (détails Activity/YYYY-MM-DD.md)
```

## Étape 6 — Mise à jour de `.sync-state.json`

```json
{
  "last_run": "YYYY-MM-DDTHH:MM:SS+02:00",
  "stats_last_run": {
    "events_added": N,
    "clients_created": M,
    "contacts_added": X,
    "items_a_trier": Y
  }
}
```

## Étape 7 — Notification Cowork

Envoyer un message dans le chat Cowork :

```
✅ Cerveau MAJ — N events, M nouveaux clients, X contacts, Y à trier
→ détails dans Activity/YYYY-MM-DD.md
```

Si `Y > 0` (items à trier) : ajouter une mention claire que l'utilisateur devrait jeter un œil rapide à `inbox/_a_trier/YYYY-MM-DD.md`.

## Étape 8 — Méta-actions (propositions d'amélioration du système)

Le skill peut **proposer** des modifications au système lui-même (skills, configs, structure de dossier), mais **n'écrit jamais directement** ces modifs : elles vont dans `inbox/_propositions/YYYY-MM-DD.md`. L'utilisateur valide à froid.

Cas typiques de proposition :

| Pattern détecté | Proposition |
|---|---|
| L'utilisateur fait 3× la même action manuelle | nouveau skill ou nouvelle Scheduled Task pour automatiser |
| Un dossier `Clients/X/` reste vide depuis 30 jours | suggérer archivage |
| Un client revient souvent avec le même type de demande | suggérer template de réponse |
| Un nouveau MCP apparaît dans le Project | suggérer comment l'intégrer au sync |
| Un skill existant échoue régulièrement (logs `_erreurs/`) | suggérer correction précise (pas la corriger seul) |
| L'utilisateur utilise un mot/expression récurrent | l'ajouter au `ME.md` (style) |
| Une convention de nommage dérive | suggérer normalisation |

Format de `_propositions/YYYY-MM-DD.md` :

```markdown
# Propositions — YYYY-MM-DD

## 1. [Titre court de la proposition]
**Pattern détecté** : [ce que Claude a vu, ex: "l'utilisateur a refait 3× la même requête pour générer un compte-rendu"]
**Proposition** : [action concrète à faire]
**Impact si fait** : [bénéfice estimé]
**Effort estimé** : [minutes / heures]

## 2. ...
```

**Garde-fou strict** : ne **jamais** modifier un fichier `.claude/`, un skill, ou une config de Project automatiquement. Seules les écritures permises en automatique sont :
- `Clients/*/knowledge.md`, `Clients/*/history.md`, `Clients/*/livrables/`
- `contacts.jsonl`
- `history.md` racine
- `Activity/YYYY-MM-DD.md`
- `inbox/_a_trier/`, `inbox/_erreurs/`, `inbox/_propositions/`
- `.sync-state.json`
- `ME.md` **uniquement** pour la liste des `internal_domains` (auto-apprentissage du contexte pro)

Tout le reste = proposition seulement.

---

# Modes dégradés — toutes éventualités couvertes

Le skill doit **survivre à tout** sans demander à l'utilisateur. Voici les scénarios et la réponse :

| Scénario | Réponse du skill |
|---|---|
| **Gmail MCP pas connecté** | Continue avec Calendar + Drive + autres MCPs. Notif Cowork : "Je n'ai pas pu lire tes mails aujourd'hui, je regarde ton agenda et tes documents quand même." |
| **Gmail auth expirée** | Idem, et stocker dans `_erreurs/YYYY-MM-DD.md` un mémo "auth Gmail à renouveler". Re-tenter au prochain run. |
| **Calendar MCP KO** | Continue avec Gmail + Drive. Notif simple. |
| **Drive MCP KO** | Mode READ-ONLY (cf. Étape 0.4) — notif Cowork claire "Je n'ai pas pu enregistrer aujourd'hui, je réessaye demain". Garder un cache mémoire si possible pour le run suivant. |
| **Drive plein / quota dépassé** | Tenter de compresser les `history.md` >500 lignes en priorité. Si toujours plein → notif "Ton Google Drive est plein, on peut nettoyer ?". |
| **Aucun MCP disponible** | Mode MINIMAL : notif "Je suis hors-ligne aujourd'hui, je réessaie demain." Ne rien tenter d'autre. |
| **`.sync-state.json` corrompu** | Repartir d'un état neuf (`last_run = NOW - 7 jours`). Logger l'incident. Pas de notif à l'utilisateur. |
| **Premier run jamais** | Considérer `last_run = NOW - 100 jours` pour un "bootstrap" propre. Notif spéciale : "Je viens de commencer à organiser ton cerveau, voilà ce que j'ai trouvé." |
| **Rate limit LLM / API** | Backoff exponentiel, max 3 retries. Au-delà → mode SAFE pour le reste du run. |
| **Conflit fichier (édit concurrente)** | Re-lire le fichier, merger l'ajout, re-écrire. Si conflit persistant → écrire dans `_a_trier/` au lieu du fichier ciblé. |
| **Encodage / caractères spéciaux** | Tout en UTF-8. Si lecture KO sur un fichier → skip ce fichier, log dans `_erreurs/`. |
| **Cowork notifications KO** | Écrire la notif dans `Activity/YYYY-MM-DD.md` au lieu de Cowork. L'utilisateur la verra au prochain coup d'œil. |
| **Un nouveau MCP apparaît** | L'inclure au prochain run, le cataloguer dans `_propositions/` ("On peut intégrer Notion ?"). |
| **Un MCP utilisé disparaît** | Continuer sans lui, logger, le retirer du plan au prochain run. |
| **L'utilisateur dépose 100 fichiers d'un coup dans `inbox/`** | Traiter en batch, prioriser par date desc, limiter à 50 max par run pour ne pas surcharger. Le reste au prochain run. |
| **L'utilisateur a renommé un dossier client** | Détecter par contenu (knowledge.md, contacts), réconcilier au lieu de dupliquer. Si pas sûr → flag dans `_a_trier/`. |
| **Le skill plante en cours** | Catch global : sauver le partial state, logger trace dans `_erreurs/`, sortir proprement. L'utilisateur voit "Cerveau MAJ — quelques détails à reprendre demain". |

# Auto-amélioration du skill lui-même

Le skill est **le skill le plus important du second cerveau**. Il doit pouvoir s'améliorer sans intervention humaine quand possible.

## Détection d'amélioration nécessaire

Pendant le run, le skill collecte des indicateurs :
- Combien d'items sont allés dans `_a_trier/` (vs traités directement) ?
- Combien d'erreurs dans `_erreurs/` ?
- Quels patterns récurrents ressortent dans les logs ?
- Quel MCP donne le plus de valeur ?
- Quelles heuristiques se trompent (vu après-coup quand l'utilisateur modifie un fichier auto-créé) ?

Si un seuil est atteint (ex: >30% items en `_a_trier/`, ou même erreur 3 fois) :

## Proposition d'amélioration

Écrire dans `inbox/_skill-improvements/YYYY-MM-DD.md` :

```markdown
# Proposition d'amélioration du skill update-memory — YYYY-MM-DD

## Symptôme observé
[Description précise + statistiques]

## Cause probable
[Hypothèse]

## Patch proposé
[Diff précis : quelle section du skill, quelle modification]

```diff
- ancienne règle
+ nouvelle règle
```

## Test de validation
[Comment vérifier que le patch marche]

## Risque
[low / medium / high]
```

## Auto-application sous conditions strictes

Le skill peut s'auto-modifier (= écrire dans son propre fichier `.claude/commands/update-memory.md`) **uniquement** si toutes les conditions ci-dessous sont remplies :

1. Le patch est **additif** (nouvelle règle / nouveau cas) — pas de suppression de comportement existant
2. Le pattern d'erreur a été observé **≥ 5 fois** sur ≥ 3 runs différents
3. Le patch concerne **uniquement** : `internal_domains`, listes d'exclusion, seuils numériques, ou patterns de matching
4. Une **sauvegarde** de la version précédente est faite dans `inbox/_skill-improvements/_backup-YYYY-MM-DD.md` **avant** la modif
5. Un log explicite dans `_skill-improvements/` indique : "Auto-appliqué" + raison

Tout autre type de modification (refonte logique, suppression de garde-fou, ajout de capacités structurelles) → **proposition seulement**, l'utilisateur relit.

## Garde-fou ultime

Si après 3 auto-modifications consécutives le skill se plante au démarrage → **rollback automatique** vers la dernière version saine connue (dans `_backup-*`) et notif explicite à l'utilisateur "J'ai eu un problème en me mettant à jour, je suis revenu à ma version d'avant".

# Garanties absolues pour l'utilisateur

Ce skill est le **système nerveux** du second cerveau. L'utilisateur ne doit jamais avoir à y toucher.

## Les 5 garanties

1. **L'utilisateur n'a jamais à intervenir** — Aucune action manuelle requise, même en panne totale. Le skill se débrouille seul ou prévient gentiment.
2. **L'utilisateur ne voit jamais d'erreur tech** — Pas de stack trace, pas de "MCP error", pas de "JSON parse failed". Tout est traduit en français simple.
3. **Le cerveau reste toujours cohérent** — Mieux vaut ne rien écrire que polluer. En cas de doute → `_a_trier/`.
4. **Le skill survit à toute panne** — Catch global, modes dégradés, rollback auto. Il sort toujours proprement.
5. **Le skill s'améliore tout seul** — Détection de ses faiblesses, propositions de patchs, auto-apply sous conditions strictes.

## Test "à éteindre la lumière"

L'utilisateur peut partir 3 semaines en vacances. À son retour, le second cerveau doit être :
- Plus riche qu'avant (events captés, nouveaux clients détectés, contacts ajoutés)
- Pas pollué (pas de faux clients, pas de doublons)
- Avec une `Activity/` claire pour les 21 jours passés
- Avec un récap simple dans Cowork "Voilà ce qui s'est passé pendant ton absence"

Si le skill ne passe pas ce test mental → il faut le re-cadrer avant de le lancer en prod.

# Anti-patterns (les deux modes)

- ❌ Écraser un fichier (toujours append ou edit chirurgical)
- ❌ Inventer des infos non vues dans la source — si pas clair → `_a_trier/`
- ❌ Sauvegarder mots de passe, numéros bancaires, identifiants gouvernementaux
- ❌ Re-processer un item déjà traité (vérifier dans `history.md`)
- ❌ Créer un faux client depuis un mail interne, marketing, ou notification
- ❌ Mode SCHEDULED : demander confirmation à l'utilisateur (il n'est pas là)
- ❌ Mode MANUEL : écrire sans confirmation explicite
- ❌ Modifier automatiquement un skill, une config, ou un fichier `.claude/` (seulement proposer dans `_propositions/`)
- ❌ Bloquer ou s'arrêter parce qu'un MCP renvoie une erreur (log + continue)
- ❌ Utiliser du jargon technique dans les notifs Cowork (utilisateur non-tech)
- ❌ Ignorer une source / un MCP nouveau sans tentative (essaie, log, propose)

# Robustesse pour utilisateur non-technique

Le skill tourne pour l'utilisateur qui ne sait pas coder. Conséquences :

1. **Jamais d'erreur visible non gérée** : si quelque chose plante, log dans `_erreurs/` et continue. Notif Cowork dit "✅ Cerveau MAJ — quelques détails à vérifier" sans afficher de stack trace.
2. **Notifs Cowork en français simple** : pas de "MCP", "JSON", "timestamp". Dire "ton agenda", "tes mails", "le 28 mai à 18h".
3. **Auto-récupération** : si `.sync-state.json` est corrompu, repartir d'un état neuf en considérant `last_run = NOW - 7 jours`. Ne jamais demander à l'utilisateur de "réinitialiser".
4. **Choix par défaut robuste** : à chaque ambiguïté, le défaut doit être "ne pas casser ce qui existe" plutôt que "essayer de bien faire".
5. **Notifs hebdo** : 1×/semaine, faire un récap "voilà ce que j'ai rangé cette semaine, voilà ce que je propose" — pour que l'utilisateur garde la main sans avoir à fouiller.
