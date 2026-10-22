# Weltuhr

[English](README.md) · [简体中文](README.zh-CN.md) · [Deutsch](README.de.md) · [Italiano](README.it.md) · [日本語](README.ja.md) · **Français**

> Traduction de [README.zh-CN.md](README.zh-CN.md) · 2026-10-17 · la version chinoise fait foi.

> Déployer un domaine d'étude en un espace de connaissances **localisable, planifiable et mesurable**, pour que « je veux apprendre X » devienne « je sais quoi apprendre, dans quel ordre, et à quel point j'en suis quand cela compte comme utilisable ».

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

## Points clés

- **Espaces de connaissances** : les connaissances s'organisent autour de packs de contenu — un espace, un pack. La frontière d'un espace est tranchée par trois critères, non tracée à la main en couches
- **Des coordonnées, pas des dossiers** : six axes (discipline / métier / secteur / compétence / thème / stack technique) × trois couches (persistant / vue / éphémère) forment des **coordonnées d'index**, combinables en filtres, et non des dossiers imbriqués
- **Univers 3D + arbre 2D + détail** : trois projections d'un même modèle de graphe ; la position porte elle-même du sens (`r` / `θ` / `φ`), sans disposition force-directed en 3D
- **Planification en trois étapes** : source (supports) → système (ordre) → méthode (actions + critères) ; les trois sont rédigeables par l'utilisateur, les candidats sont classés selon leurs propres critères et les compromis sont affichés
- **Boucle d'acquisition en sept étapes** : repérer → planifier → s'exercer → vérifier → entretenir → sortie ; la révision suit FSRS. La progression est discrète (elle ne recule jamais) et reste séparée de la maîtrise, qui est continue (elle peut baisser)
- **Deux types de notes** : les notes de système (dérivées du système) et les notes personnelles partagent la même ancre `itemId` et se commutent sur place ; l'export vers des applications de notes externes est unidirectionnel

## Démarrage rapide

> Prérequis : Flutter 3.x + Dart 3.x · Serverpod 4.x (les versions sont figées dans `app/pubspec.yaml` / `server/pubspec.yaml`) · PostgreSQL 16

```bash
git clone git@github.com:liberalluz/weltuhr-knowledge.git && cd weltuhr-knowledge

# dependances du client
cd app && flutter pub get

# dependances du serveur + base de donnees
cd ../server && dart pub get

# generer le pack de contenu (doit preceder le lancement du client : le client cherche content/<space>/dist/pack.json par rapport au repertoire de travail a l'execution)
cd ../content && python tools/build.py

# execution
cd ../app && flutter run -d windows
```

## Arborescence

| Répertoire | Responsabilité |
|---|---|
| [app/](app/README.md) | Client Flutter (une seule base de code pour Windows / macOS / iOS) |
| [server/](server/README.md) | Serveur Serverpod : synchronisation, fusion d'événements, gouvernance et révision |
| [content/](content/README.md) | Données sources des packs de contenu et pipeline de build |
| [docs/](docs/README.md) | Documents livrables, documents vivants, ADR et spécifications de conception |
| [infra/](infra/README.md) | Build / signature / mise à jour / miroir / CI |

Voir aussi : [docs/intent/knowledge-system-learning-methodology.md](docs/intent/knowledge-system-learning-methodology.md) — la **base méthodologique** de ce projet (méthodologie de l'apprentissage en système de connaissances) ; pour la spécification de conception logicielle, voir [docs/specs/](docs/specs/00-index.md).

## Documentation

- [docs/README.md](docs/README.md) — index de la documentation (livrables / documents vivants / ADR)
- [docs/specs/00-index.md](docs/specs/00-index.md) — **index des spécifications de conception** (FND / VIEW / PACK / PLAN / STEP / QUANT / NOTE / GOV + tableaux transversaux)

## Licence et attribution

Copyright (c) 2026 liberal. Ce projet est publié sous licence [Apache-2.0](LICENSE) ; voir aussi [NOTICE](NOTICE).

## Contribuer et obtenir de l'aide

- **Vulnérabilités de sécurité** : n'ouvrez pas d'issue publique — signalez-les par le canal privé décrit dans [.github/SECURITY.md](.github/SECURITY.md) (première réponse sous 7 jours ouvrés)
- Questions et propositions : via les Issues du dépôt ; pour une erreur de contenu, précisez l'identifiant de l'espace et l'`itemId`
- Processus de contribution : [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md)
