---
description: Initialise un Second Cerveau vierge prêt à déployer chez un client (arborescence + skills + premier dossier client)
argument-hint: <nom-du-client>
---

Tu vas initialiser un **Second Cerveau** vierge pour un client, prêt à être copié dans son Google Drive et branché sur un Project Cowork.

Nom du client fourni par l'utilisateur : $ARGUMENTS

## Contexte

Le Second Cerveau est une base de connaissance qui vit dans **Cowork (claude.ai / Claude desktop)**, pas dans Claude Code. Cette commande sert au **déployeur** (toi/un formateur) : elle génère le dossier vierge à partir du template embarqué dans ce plugin, puis le déployeur le copie dans le Drive du client. L'utilisateur final est **non-technique**.

Le template vierge est dans `${CLAUDE_PLUGIN_ROOT}/template/`. **Ne jamais inventer de contenu** : on copie le template tel quel, on ne fait que renseigner le nom du client.

## Étapes

1. **Nom du client.** Si `$ARGUMENTS` est vide, demande le nom du client (ex. « Cabinet Dupont »). Sinon, utilise-le.

2. **Calcule un slug** à partir du nom : minuscules, accents retirés, espaces et caractères spéciaux remplacés par des tirets (ex. « Cabinet Dupont » -> `cabinet-dupont`). Le dossier cible sera `<slug>-second-cerveau/` dans le répertoire de travail courant.

3. **Vérifie l'absence de collision.** Si `<slug>-second-cerveau/` existe déjà, arrête-toi et signale-le (ne jamais écraser un dossier existant).

4. **Copie le template** vers le dossier cible :
   ```bash
   cp -r "${CLAUDE_PLUGIN_ROOT}/template" "./<slug>-second-cerveau"
   ```

5. **Crée le premier dossier client** à partir du squelette `_template` :
   ```bash
   cp -r "./<slug>-second-cerveau/Clients/_template" "./<slug>-second-cerveau/Clients/<NomClient>"
   ```
   où `<NomClient>` est le nom lisible (garde les majuscules/espaces du nom réel, ex. `Cabinet Dupont`). Conserve aussi le dossier `_template` en place (il sert pour les futurs clients).

6. **Renseigne le nom du client** dans les deux fichiers du nouveau dossier client, en remplaçant le placeholder `[NomClient]` par le nom réel :
   - `Clients/<NomClient>/knowledge.md` (titre + section Entreprise)
   - `Clients/<NomClient>/history.md` (titre)
   N'écris rien d'autre : pas d'interlocuteurs, pas de pricing inventés. Ces champs restent vides, l'assistant Cowork les remplira.

7. **Vérifie** que le dossier généré ne contient pas de `.sync-state.json` (son absence déclenche l'installation guidée au premier usage Cowork). S'il existe, supprime-le.

8. **Affiche les prochaines étapes** au déployeur, clairement :
   - Copier le dossier `<slug>-second-cerveau/` dans le Google Drive du client (en gardant l'arborescence).
   - Créer un Project Cowork et y connecter ce dossier Drive.
   - Coller le contenu de `COWORK_CUSTOM_INSTRUCTIONS.md` dans le champ « Custom Instructions » du Project.
   - Dans une conversation, dire « installe mon cerveau » : l'assistant guide le reste (remplissage de `ME.md`, contacts, etc.).
   Renvoie aussi vers `GUIDE_DEMARRAGE.md` à la racine du dossier généré.

## Garde-fous

- Ne jamais écraser un dossier existant (étape 3).
- Ne jamais inventer de données client (interlocuteurs, emails, pricing) : seul le nom est renseigné.
- Ne jamais committer ni pousser le dossier généré : c'est un livrable destiné au Drive du client, pas au repo.
- Si une commande shell échoue, montre l'erreur et arrête-toi proprement plutôt que de continuer sur un état partiel.
