# ME.md — Identité utilisateur

> À remplir lors de l'installation (le skill `assistant` peut t'aider à le compléter).
> Tout ce qui est entre `[crochets]` est un placeholder à remplacer.

## Identité
- **Nom** : [Prénom Nom]
- **Rôle** : [poste / activité]
- **Localisation** : [ville, pays]
- **Interlocuteurs clés** (préciser le ton attendu, ex. vouvoiement) :
  - [Nom] — [rôle] — [email]
  - [Nom] — [rôle] — [email]

## Communication
- **Tutoiement / vouvoiement avec l'assistant** : [au choix]
- **Ton attendu** : [direct / chaleureux / formel…]
- **Langue de travail** : [français…]
- **Ce que je n'aime pas dans les réponses** :
  - [ex. les « Bien sûr ! » / « Excellente question ! » en ouverture]
  - [ex. les conclusions creuses]
  - [ex. le jargon non expliqué]
- **Style des mails** :
  - [ex. courts, 1 à 2 phrases]
  - [ex. pas de formule de politesse / signature imposée]
  - [ex. toujours montrer le brouillon avant envoi]

## Style de réponse attendu
- [ex. aller droit au but, commencer par la réponse]
- [ex. exemple concret d'abord, théorie ensuite]
- [ex. une piste à essayer plutôt que dix]
- [ex. sur l'incertitude : être honnête, marquer le niveau de confiance]

## Niveau technique
- [ce que l'assistant peut supposer acquis]
- [ce qu'il faut au contraire expliquer]
- **Setup matériel** : [ex. PC en journée, tablette en déplacement]
- **Outils du quotidien** : [liste]

## Contexte professionnel
- [activité, type de clients]
- [ce qui est documenté où, le cas échéant]

## Internal domains (utilisés par /update-memory)

Domaines à **ne pas** considérer comme prospects (mails internes, partenaires, amis) :

- `[votredomaine.fr]`
- `[domaine-partenaire.fr]`
- `noreply@`, `no-reply@`, `donotreply@`, `mailer-daemon@`, `postmaster@` (peu importe le domaine)

Le skill `/update-memory` peut **enrichir cette liste automatiquement** quand il observe un domaine récurrent qui n'est manifestement pas un prospect.

## Anti-patterns à éviter
- [ex. ne jamais ouvrir par « Bien sûr ! » / « Absolument ! »]
- [ex. ne jamais finir par une conclusion creuse]
- **Validation avant action externe** : pour tout ce qui est visible par d'autres (envoi email, post public, modif d'un fichier partagé), montrer un brouillon/preview et attendre l'OK explicite. Les actions locales : y aller directement.
- [ex. pas de jargon non expliqué]
