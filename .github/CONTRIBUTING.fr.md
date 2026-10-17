# Contribuer

[English](CONTRIBUTING.md) · [简体中文](CONTRIBUTING.zh.md) · [Deutsch](CONTRIBUTING.de.md) · [Italiano](CONTRIBUTING.it.md) · [日本語](CONTRIBUTING.ja.md) · **Français**

> Traduction de [CONTRIBUTING.zh.md](CONTRIBUTING.zh.md) · 2026-10-17 · la version chinoise fait foi.

> **Ce que ce fichier régit** : la **gouvernance** — qui peut modifier quel niveau de décision · qui est habilité à relire · ce qu'une relecture examine · les rôles · les attentes de comportement · les délais de réponse · la licence et le DCO.
> **Ce qu'il ne régit pas** : **le processus et le format** — structure du dépôt · branches · format des commits · granularité des PR · **nombre d'approbations** · stratégie de fusion · versions et tags · numéros de version des livrables. Tout cela fait foi dans [`docs/guides/git-conventions.md`](../docs/guides/git-conventions.md) et n'est pas dupliqué ici. Contenu de conception → [`docs/design/00-index.md`](../docs/design/00-index.md) ; vulnérabilités de sécurité → [`SECURITY.md`](SECURITY.fr.md).

## 1. Limites de compétence

La base de conception de ce dépôt est constituée de **spécifications numérotées et déjà arbitrées** (nombre d'entrées dans [`docs/design/00-index.md`](../docs/design/00-index.md) ; ce fichier ne le répète pas). En collaboration à plusieurs, la première discipline n'est pas « comment écrire du code » mais **qui peut modifier une décision** : une erreur de code se révoque, une erreur de décision fait dériver toutes les implémentations en aval dans la même direction, et aucun test ne s'en apercevra.

| Objet de la modification | Exemple | Qui décide | Ce qu'il faut |
|---|---|---|---|
| **Implémentation** | correction de bug, refactorisation, tests ajoutés, ajustements de mise en page | toute personne qui contribue | PR + relecture (nombre selon l'effectif des mainteneurs, voir §4) |
| **Documents de niveau C** | formulations, exemples, liens morts | toute personne qui contribue | une phrase dans la PR |
| **Niveau B** | valeurs de constantes, nullabilité des champs, nouveaux types d'événement | validation d'un mainteneur | PR + note de modification + mise à jour du tableau transversal |
| **Niveau A** | six axes, `⪯`, modèle d'événements, table des canaux, protocole | **mainteneurs uniquement** | d'abord une issue → ADR → puis modifier la spécification |
| **Niveau D** | conflit avec la [liste NOT](../docs/reference/not-list.md) | **seul un mainteneur peut renverser une entrée NOT** | ne pas le faire ; si c'est indispensable, laisser une trace |
| **Valeurs TBD** | seuil de flou de recherche `C-28`, etc. | **mainteneurs uniquement** | ne pas renseigner, ne pas fournir de valeur par défaut |
| **Engagements externes** | licence, fenêtre de versions prises en charge, délais de réponse, nom de marque | **mainteneurs uniquement** | toute modification exige une annonce explicite et une trace |

Les critères de classement ne sont pas répétés ici ; voir [git-conventions §4.4 classement des modifications](../docs/guides/git-conventions.md) et [design/00-index §7](../docs/design/00-index.md). Ce tableau ne répond qu'à « qui valide ».

**Pourquoi les trois dernières lignes sont séparées** — elles ressemblent toutes à « il suffit de saisir une valeur » ou « il suffit de changer une phrase », mais le coût retombe sur d'autres :

- donner distraitement 0,6 à `C-28` décale silencieusement le comportement « un seul résultat passe directement » de la recherche — **aucun test ne passe au rouge** ;
- modifier « 7 jours ouvrés » rompt un engagement externe alors que le diff de la PR tient sur une ligne ;
- modifier la fenêtre des versions prises en charge invalide le chemin de mise à jour de tous les utilisateurs d'anciennes versions.

⚠️ **La contribution hors périmètre la plus fréquente** : dans le code, `C-28` est la sentinelle `throw TbdConstantError` ; la lire provoque un plantage. C'est **volontaire**, ce n'est pas un bug. « Je corrige vite ce plantage et je mets une valeur par défaut raisonnable » est la modification hors périmètre typique — devant une sentinelle, ouvrez une issue, n'ajoutez pas de valeur par défaut.

## 2. Quatre voies d'entrée

| Ce que vous voulez faire | Comment commencer | Une issue d'abord ? |
|---|---|---|
| Signaler un défaut | issue avec **version + plateforme + étapes de reproduction** | — |
| Signaler une erreur de contenu | issue précisant **l'identifiant de l'espace + `itemId`** | — |
| Petite modification (doc, commentaire, correction ponctuelle) | ouvrir directement une PR | Non |
| Nouvelle fonctionnalité / changement de conception / intervention sur des critères A ou B | ouvrir d'abord une issue et discuter jusqu'à l'accord | **Oui** |

Le critère de la « petite modification » : elle tient en un message de commit et ne touche aucune entrée de `docs/design/`.

Une PR volumineuse jamais discutée sera fermée plutôt que relue — non par manque d'accueil, mais parce que **relire une modification de niveau A déjà terminée** revient à l'entériner après coup, ce qui coûte plus cher que d'en discuter dès le départ.

## 3. Cinq choses avant d'ouvrir une PR

| # | Élément | Critère |
|---|---|---|
| 1 | Auto-vérification locale | exécuter tout ce que prévoit [git-conventions §7 auto-contrôle avant commit](../docs/guides/git-conventions.md) ; coller dans le corps de la PR les **commandes réellement exécutées et leur sortie** |
| 2 | Assertion observable | un nouveau comportement exige un vecteur de test ; « c'est implémenté dans le code » ne vaut pas acceptation (`X-05`, voir [00-index §4](../docs/design/00-index.md)) |
| 3 | Signature DCO | `git commit -s`, chaque commit porte `Signed-off-by` (voir §8) |
| 4 | Une seule chose par PR | refactorisation et changement de comportement ne se mélangent pas ; code et documentation ne se mélangent pas dans un même commit |
| 5 | Aucun passager clandestin | ne modifier que ce qui est décrit ; un problème sans rapport repéré mérite **sa propre issue**, pas un réordonnancement / renommage / embellissement au passage |

Origine de la règle 5 : la documentation et le code de ce dépôt suivent des conventions fixes (tableaux d'abord, citer plutôt que dupliquer, rien n'est dessiné que le modèle ne déclare pas). Le coût du « petit rangement au passage » est que la relecture doit discerner ligne par ligne ce qui constitue le vrai changement, et annuler une telle PR coûte bien plus qu'elle n'a rapporté.

**Utiliser un assistant IA pour écrire du code reste soumis à toutes ces règles**, plus une : « ça passe » dit par un modèle n'est pas une preuve — collez la sortie de votre propre terminal. La sémantique des plateformes et des runtimes se juge sur la documentation officielle et sur des résultats en matériel réel, pas sur un build local.

## 4. Relecture

**Le nombre n'est pas fixé ici** : les approbations suivent l'effectif des mainteneurs (un seul mainteneur **0** · à partir de 2 mainteneurs **1**, et ce ne doit pas être l'auteur). La règle est dans [git-conventions §4.1](../docs/guides/git-conventions.md). Cette section ne répond qu'à **qui est habilité** et **ce qui est examiné**.

- **Tant qu'il n'y a qu'un mainteneur** : la **conclusion d'auto-relecture** dans le corps de la PR tient lieu d'approbation (ce qui a changé / comment cela a été vérifié / pourquoi ce découpage). Ce n'est pas une exemption, c'est une relecture échangée contre une trace écrite ; elle tombe dès qu'un second mainteneur apparaît.
- **Modifications de niveau A et B** : quel que soit l'effectif, un mainteneur participe à la relecture.
- La relecture examine quatre choses, pas les préférences de style :

| # | Ce qui est examiné | Fondement |
|---|---|---|
| 1 | l'assertion observable est-elle présente | `X-05` |
| 2 | les règles sont-elles **citées** ou recopiées dans une seconde source | [docs/README §5](../docs/README.md) |
| 3 | l'interface dessine-t-elle discrètement un champ que le modèle n'a jamais déclaré | `X-01` |
| 4 | la liste NOT est-elle touchée | [not-list](../docs/reference/not-list.md) |

⚠️ **État actuel** : la protection de branche n'est pas activée sur `main` (les dépôts privés des comptes GitHub gratuits ne la proposent pas), les contraintes ci-dessus **reposent donc sur la discipline** et non sur un blocage technique — voir [git-conventions §4.3 état du dépôt distant](../docs/guides/git-conventions.md). Le fait que rien ne l'empêche techniquement ne le rend pas permis.

## 5. Rôles

| Rôle | Droits | Obtention |
|---|---|---|
| **Contributor** | ouvrir des issues et des PR | aucune demande |
| **Reviewer** | approuver / demander des modifications | invitation par un mainteneur (seuil : voir le point en suspens ci-dessous) |
| **Maintainer** | fusionner, arbitrer les niveaux A/B, publier des versions, modifier les réglages du dépôt | accord unanime des mainteneurs en place |

Mainteneur actuel : [@liberalluz](https://github.com/liberalluz)

## 6. Comportement attendu

Ce dépôt n'a pas encore de `CODE_OF_CONDUCT.md` distinct ; ces quatre règles s'appliquent en attendant :

1. **Contester l'argument, pas la personne** — les désaccords techniques se règlent par des preuves et des assertions observables, pas par l'ancienneté.
2. **Ne pas relancer** — les délais sont au §7 ; passé l'échéance vous pouvez demander, mais ne remontez pas plusieurs fois le même fil.
3. **Ne pas décider à la place d'autrui** — les valeurs dont d'autres ont la charge (les trois dernières lignes du §1) ne se renseignent pas, même quand la réponse paraît évidente.
4. **Pas d'auto-certification** — « ça tourne chez moi » n'est pas une preuve.

Traitement des manquements : un mainteneur peut verrouiller une discussion, fermer une PR ou refuser les contributions ultérieures. Un code de conduite formel (Contributor Covenant 2.1) sera ajouté lorsque la base de contributeurs s'élargira ; cette section deviendra alors un renvoi (seuil de déclenchement **TBD**).

## 7. Délais de réponse

| Élément | Délai |
|---|---|
| Première réponse à une issue | sous 7 jours ouvrés (même règle que [`SECURITY.md`](SECURITY.fr.md)) |
| Premier avis de relecture sur une PR | **TBD** — non défini, on applique pour l'instant les 7 jours ouvrés des issues |
| Fermeture d'une PR sans mise à jour depuis longtemps | **TBD** — non défini, la pratique actuelle est de demander une fois puis de décider |

⚠️ Rien de tout cela **ne constitue un SLA** ; ce sont les meilleurs efforts des mainteneurs. Modifier ces deux lignes relève des « engagements externes » du §1 et exige une annonce explicite.

## 8. Licence et attribution

- En soumettant, vous acceptez que votre contribution soit distribuée sous **Apache-2.0** (voir [`../LICENSE`](../LICENSE), [`../NOTICE`](../NOTICE)).
- **DCO** : les commits doivent utiliser `git commit -s` et porter `Signed-off-by: Votre nom <courriel>`, attestant que vous avez le droit de soumettre ce contenu (texte sur [developercertificate.org](https://developercertificate.org/)). Ce n'est pas une cession de droits : le droit d'auteur vous reste acquis.
- Le contenu de connaissance d'un **content pack** (`content/`) doit être original, ou provenir de sources dont la licence est compatible avec ce projet ; **n'introduisez pas** de textes ou de médias issus de sources CC-BY-NC, GPL ou AGPL (critères dans [dependency-licenses §2](../docs/guides/dependency-licenses.md)). Une correction de contenu ne modifie pas l'attribution de l'auteur d'origine.
- Tout code ou média tiers doit être enregistré **dans la même PR** dans [`../NOTICE`](../NOTICE) et dans la [liste des licences de dépendances](../docs/guides/dependency-licenses.md).

## Annexe : environnement local

Les versions de Flutter / Dart / Serverpod sont figées dans `app/pubspec.yaml` et `server/pubspec.yaml` et **ne suivent pas la dernière**. La mise en place de l'environnement et les pièges connus d'une première compilation sous Windows (liens symboliques, mode développeur) sont dans [`docs/guides/environment.md`](../docs/guides/environment.md).
