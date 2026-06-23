# Skills disponibles — index

> Map de tous les skills du Second Cerveau.
> Quand l'utilisateur demande une action, retrouve la skill correspondante via les phrases déclencheurs, ouvre son fichier, suis ses instructions.

| Skill | Fichier | Quand l'utiliser | Phrases qui déclenchent |
|---|---|---|---|
| **assistant** | `skills/assistant.md` | **Le concierge.** Installe le cerveau (1re fois) puis aide au quotidien : relancer le sync, expliquer l'activité, reconnecter un connecteur, ajouter un client. Pensé pour un utilisateur non-technique. | `installe mon cerveau`, `on commence`, `aide-moi à démarrer`, `configure`, `relance le sync`, `mets à jour`, `ça marche plus`, `je vois plus mes mails`, `qu'est-ce qui s'est passé`, `ajoute le client X`, `aide-moi` |
| **update-memory** | `skills/update-memory.md` | Mettre à jour le Second Cerveau (mode manuel sur conv en cours, ou mode scheduled sur sources externes Gmail/Calendar/Drive). C'est **le skill central**. | `/update-memory`, `mets à jour la mémoire`, `lance le sync`, `sync cerveau`, `sauvegarde le contexte`, `mode scheduled`, `scheduled task`, `fin de session` |
| **ping** | `skills/ping.md` | Vérifier que les skills marchent (test technique simple, répond pong + diagnostic). | `/ping`, `tu me vois ?`, `test skill`, `le skill marche ?` |
| **self-improve** | `skills/self-improve.md` | Formuler une règle anti-erreur quand un pattern d'erreur revient, et l'ajouter à `ME.md` / `TOOLS.md` / `Clients/X/knowledge.md`. | `/self-improve`, `j'ai fait une erreur récurrente`, `ajoute une règle`, `il faut éviter ça à l'avenir` |

## Comment ce système marche

1. Au démarrage de chaque conversation, lire ce fichier `skills/INDEX.md` pour connaître les skills disponibles.
2. Quand l'utilisateur formule une demande, matcher avec les "Phrases qui déclenchent" ci-dessus.
3. Si match → ouvrir le fichier de la skill correspondante et suivre ses instructions.
4. Si pas de match clair → demander à l'utilisateur ce qu'il veut faire, en suggérant 2-3 skills probables.

## Quand ajouter une skill

1. Créer le fichier `skills/[nom].md` avec frontmatter `name:` + `description:`
2. Ajouter une ligne dans le tableau ci-dessus
3. C'est tout — la skill est découvrable au prochain démarrage de conversation

## Conventions

- Un fichier par skill simple (`update-memory.md`, `ping.md`)
- Un dossier avec `SKILL.md` à l'intérieur pour les skills complexes avec ressources (`mon-skill/SKILL.md`)
- Toujours un frontmatter `name:` + `description:` (la description est ce que Claude lit quand il découvre le skill)
- Les déclencheurs en français, langage parlé (l'utilisateur ne tape pas de slash commands)
