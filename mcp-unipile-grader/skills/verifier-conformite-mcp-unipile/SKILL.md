---
name: verifier-conformite-mcp-unipile
description: Utiliser pour vérifier la conformité d'un serveur MCP Unipile (connecteur LinkedIn) à la spécification de référence, avant ou pendant la phase de test. S'applique quand un apprenti veut auto-évaluer son rendu, savoir s'il manque des fonctionnalités, ou comprendre un écart, quelle que soit la stack (Node, Python, etc.).
---

# Vérifier la conformité d'un MCP Unipile

## Quoi et pourquoi

Ce skill aide à vérifier qu'un serveur **MCP Unipile** (un proxy de sécurité entre
Claude et l'API LinkedIn d'Unipile) fait bien tout ce qu'il doit faire, **avant la phase
de test**. Il s'appuie sur une spécification de référence agnostique de la stack : peu
importe que le serveur soit en Node/TypeScript, Python/FastMCP ou autre, on vérifie des
**comportements observables**, pas du code.

Analogie : c'est une **check-list d'inspection technique** avant de prendre la route. On
ne juge pas la marque de la voiture, on vérifie que les freins, les phares et la ceinture
fonctionnent.

## Fichiers de référence (à lire en premier)

- `spec-mcp-unipile.md` : la spécification complète + la **checklist de conformité** en
  annexe. C'est la source de vérité. Le **code de référence fait foi** (notamment sur les
  tokens OAuth : TTL 30 jours, persistés sur disque).
- `prompt-claude-mcp-unipile.md` : le prompt de référence qui aurait dû produire ce MCP,
  utile pour diagnostiquer si un manque vient d'un prompt incomplet.

Lis `spec-mcp-unipile.md` en entier avant de juger un rendu.

## Procédure de vérification

1. **Localiser le rendu de l'apprenti** : demander le chemin du projet ou l'URL du
   serveur en cours d'exécution.
2. **Lancer les tests automatisables** : exécuter le script `scripts/test-conformite.sh`
   (ou la slash command `/test-mcp <URL>`) qui couvre les vérifications sans
   authentification (santé, 401, métadonnées OAuth, rejet PKCE `plain`).
3. **Passer la checklist** de `spec-mcp-unipile.md` (annexe), point par point. Pour les
   exigences que le script ne couvre pas (isolation `account_id`, blocage `DELETE`,
   persistance des tokens), inspecter le code ou tester manuellement.
4. **Restituer un verdict** structuré :
   - exigences **DOIT** satisfaites / manquantes (un rendu n'est conforme que si tous
     les DOIT passent) ;
   - exigences **DEVRAIT** (points de qualité) ;
   - pour chaque manque, indiquer l'origine probable : (a) prompt incomplet, (b) dérive
     du modèle, (c) bug d'implémentation.

## Le test décisif (ne jamais l'oublier)

L'erreur d'isolation la plus fréquente : le proxy *fournit* le bon `account_id` mais
laisse quand même passer celui injecté par le client. **Test** : faire un appel en
glissant volontairement un `account_id` étranger ; le proxy doit l'**écraser** par celui
de la session. S'il passe → faille d'isolation → **non conforme** (exigence 2.2).

## Ce qu'il ne faut PAS faire

- Ne pas pénaliser un choix de stack ou l'emplacement de l'endpoint MCP (racine `/` ou
  `/mcp` sont tous deux acceptables).
- Ne pas inventer d'exigences hors spec : si ce n'est pas dans `spec-mcp-unipile.md`,
  ce n'est pas un critère.
- Ne pas conclure « conforme » sans avoir réellement exécuté les tests : montrer les
  preuves (sortie des commandes), pas des suppositions.
