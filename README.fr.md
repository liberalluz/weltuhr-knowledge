[English](README.md) · [简体中文](README.zh-CN.md) · [Deutsch](README.de.md) · [Italiano](README.it.md) · [日本語](README.ja.md) · **Français**

> La version de référence est la version anglaise [README.md](README.md) @ d888a44 ; cette traduction correspond à cette version.

# Weltuhr

> Déployer un domaine d'étude en un espace de connaissances **localisable, planifiable et mesurable**, pour que « je veux apprendre X » devienne « je sais quoi apprendre, dans quel ordre, et à quel point j'en suis quand cela compte comme utilisable ».

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

- **Espaces de connaissances** : les connaissances s'organisent autour de packs de contenu — un espace, un pack. La frontière d'un espace est tranchée par trois critères, non tracée à la main en couches
- **Un graphe, trois projections** : six axes (discipline / métier / secteur / compétence / thème / stack technique) × trois couches (persistant / vue / éphémère) forment des **coordonnées d'index**, combinables en filtres, et non des dossiers imbriqués ; l'univers 3D, l'arbre 2D et le panneau de détail sont trois projections de ce même graphe, la position porte elle-même du sens (`r` / `θ` / `φ`) et aucune disposition force-directed en 3D n'est utilisée
- **Planification en trois étapes** : source (supports) → système (ordre) → méthode (actions + critères) ; les trois sont rédigeables par l'utilisateur, les candidats sont classés selon leurs propres critères et les compromis sont affichés
- **Boucle d'acquisition en sept étapes** : choisir la source → choisir le système → choisir la méthode → s'exercer → vérifier → entretenir → sortie ; la révision suit FSRS. La progression est discrète (elle ne recule jamais) et reste séparée de la maîtrise, qui est continue (elle peut baisser)
- **Deux types de notes** : les notes de système (dérivées du système) et les notes personnelles partagent la même ancre `itemId` et se commutent sur place ; l'export vers des applications de notes externes est unidirectionnel

## Démarrage rapide

> Prérequis : Flutter 3.x + Dart 3.x · Serverpod 4.x (les versions sont figées dans `app/pubspec.yaml` / `server/pubspec.yaml`) · PostgreSQL 16

```bash
git clone git@github.com:liberalluz/weltuhr-knowledge.git && cd weltuhr-knowledge

# activer les hooks gérés par le dépôt (contrôle du format du message de commit).
# Une fois par clone ; sans eux la même règle tourne toujours en CI, mais vous ne
# le découvrez qu'après le push.
git config core.hooksPath .githooks

# dépendances du client
cd app && flutter pub get

# dépendances du serveur + base de données
cd ../server && dart pub get

# générer les packs de contenu (la sortie n'est pas versionnée ; le client cherche <racine candidate>/<dossier du pack>/pack.json par rapport au répertoire de travail à l'exécution)
cd ../content && python tools/build.py

# exécution
cd ../app && flutter run -d windows
```

## Commandes

| Commande | Ce qu'elle fait |
|---|---|
| `cd app && flutter run -d windows` | Lance le client |
| `cd app && flutter test --reporter compact` | Exécute la suite de tests du client |
| `python content/tools/assemble_pack.py` | Assemble `<space>/pack.json` — **c'est ce fichier que lit le client** |
| `python content/tools/build.py` | Ancien format (cinq segments) vers `<space>/dist/` — conservé pour les fixtures de `verify.py` |
| `python content/tools/verify.py --suite` | Vérifie les packs de contenu par rapport à leur schéma |
| `cd app && flutter analyze && dart run tool/lint/check.dart && dart run tool/docs/check.dart` | Contrôles statiques : analyseur, règles de lint du dépôt, liens et cohérence de la documentation |

> Ce tableau doit correspondre à ce que la CI vérifie réellement ; quand un workflow change, ce tableau change dans la même pull request.

## Structure du projet

| Répertoire | Responsabilité |
|---|---|
| [app/](app/README.md) | Client Flutter (une seule base de code pour Windows / macOS / iOS) |
| [server/](server/README.md) | Serveur Serverpod : synchronisation, fusion d'événements, gouvernance et révision |
| [content/](content/README.md) | Données sources des packs de contenu et pipeline de build |
| [docs/](docs/README.md) | Documentation d'ingénierie — règles de placement dans [docs/README.md](docs/README.md) |
| [infra/](infra/README.md) | Build / signature / mise à jour / miroir / CI |

## Architecture

Trois niveaux : le client Flutter dessine trois projections d'un même modèle de graphe (univers 3D / arbre 2D / détail) ; le serveur Serverpod prend en charge la synchronisation, la fusion d'événements, la gouvernance et la révision ; les packs de contenu sont des données pures compilées par `content/tools/` en `pack.json`. Le modèle de graphe, ses coordonnées et les règles de chemin sont dans l'[index des spécifications](docs/specs/00-index.md).

Les décisions de conception et les alternatives écartées : [docs/decisions/](docs/decisions/).

## Documentation

- Règles de placement et couverture des domaines de connaissance : [docs/README.md](docs/README.md)
- Spécifications et contrats d'interface : [docs/specs/](docs/specs/00-index.md)
- Exploitation, préparation de l'environnement et comment lancer les choses : [docs/runbooks/](docs/runbooks/)
- Base méthodologique du projet : [docs/intent/knowledge-system-learning-methodology.md](docs/intent/knowledge-system-learning-methodology.md)

## Obtenir de l'aide

- Commencez par l'index de la documentation : [docs/README.md](docs/README.md)
- Quelque chose est cassé ou ne démarre pas : [docs/runbooks/](docs/runbooks/)
- Questions et propositions : les Issues du dépôt. Pour une erreur de contenu, précisez l'identifiant de l'espace et l'`itemId`

## Contribuer

Nommage des branches, format des commits, pull requests et seuil de révision : [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md).

Mainteneur : liberal

## Sécurité

Signalez les vulnérabilités par le canal privé décrit dans [.github/SECURITY.md](.github/SECURITY.md). N'ouvrez pas d'issue publique pour un problème de sécurité.

## Licence

Apache-2.0 — voir [LICENSE](LICENSE) et [NOTICE](NOTICE).
