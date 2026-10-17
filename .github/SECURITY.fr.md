# Politique de sécurité

[English](SECURITY.md) · [简体中文](SECURITY.zh.md) · [Deutsch](SECURITY.de.md) · [Italiano](SECURITY.it.md) · [日本語](SECURITY.ja.md) · **Français**

> Traduction de [SECURITY.zh.md](SECURITY.zh.md) · 2026-10-17 · la version chinoise fait foi.

## Versions prises en charge

Les mises à jour de sécurité ne sont fournies que pour les versions suivantes :

| Version | Prise en charge |
|---|---|
| Dernière version mineure publiée | ✅ |
| Versions mineures antérieures / toutes les branches de correctifs seuls | ❌ |

> Règle : **dernière mineure uniquement**. Les utilisateurs de versions antérieures doivent passer à la dernière mineure pour recevoir les correctifs de sécurité.

## Signaler une vulnérabilité

**Ne signalez pas les vulnérabilités de sécurité via une issue publique.**

Soumettez-les depuis la page **Security** de ce dépôt → **Report a vulnerability** (canal privé de signalement des vulnérabilités de GitHub).
Ce canal est visible des mainteneurs et invisible du public, ce qui permet une collaboration confidentielle jusqu'à la publication d'un correctif.

Merci d'inclure autant que possible : version concernée, étapes de reproduction, votre évaluation de l'impact et, si possible, un exemple minimal de reproduction.

## Délai de réponse

Nous nous efforçons de répondre une première fois sous **7 jours ouvrés** après réception d'un signalement.

> ⚠️ Cette politique **ne constitue pas un SLA**. Le délai comme le canal sont des engagements externes ; toute modification exige un contrôle des changements et une annonce explicite dans ce fichier.

## Hors périmètre

Ce qui suit est hors du périmètre de cette politique ; merci d'utiliser le suivi d'issues habituel :

- les vulnérabilités des projets amont dont nous dépendons (signalez-les aussi en amont)
- les attaques nécessitant un accès physique à l'appareil, ou qui ne sont atteignables qu'après en avoir obtenu les droits d'administration
- les problèmes d'exactitude du contenu de connaissance d'un content pack (`content/`) — utilisez une issue de correction de contenu
- les simples conseils de configuration, recommandations de durcissement et alertes de scanner sans chemin de reproduction
