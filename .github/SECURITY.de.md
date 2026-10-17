# Sicherheitsrichtlinie

[English](SECURITY.md) · [简体中文](SECURITY.zh.md) · **Deutsch** · [Italiano](SECURITY.it.md) · [日本語](SECURITY.ja.md) · [Français](SECURITY.fr.md)

> Übersetzung von [SECURITY.zh.md](SECURITY.zh.md) · 2026-10-17 · maßgeblich ist die chinesische Fassung.

## Unterstützte Versionen

Sicherheitsupdates werden nur für die folgenden Versionen bereitgestellt:

| Version | Unterstützt |
|---|---|
| Die zuletzt veröffentlichte Minor-Version | ✅ |
| Ältere Minor-Versionen / alle reinen Patch-Branches | ❌ |

> Regel: **nur die neueste Minor-Version**. Nutzer älterer Versionen müssen auf die neueste Minor-Version aktualisieren, um Sicherheitskorrekturen zu erhalten.

## Schwachstellen melden

**Bitte melden Sie Sicherheitslücken nicht über öffentliche Issues.**

Reichen Sie sie über die **Security**-Seite dieses Repositories → **Report a vulnerability** ein (GitHubs vertraulicher Meldeweg für Schwachstellen).
Dieser Weg ist für Maintainer sichtbar und für die Öffentlichkeit nicht, sodass bis zur Veröffentlichung einer Korrektur vertraulich zusammengearbeitet werden kann.

Bitte geben Sie so viel wie möglich an: betroffene Version, Reproduktionsschritte, Einschätzung der Auswirkung und, wo möglich, ein minimales Reproduktionsbeispiel.

## Reaktionszeit

Wir bemühen uns um eine erste Antwort innerhalb von **7 Werktagen** nach Eingang einer Meldung.

> ⚠️ Diese Richtlinie **stellt kein SLA dar**. Frist und Meldeweg sind beides externe Zusagen; Änderungen erfordern Änderungskontrolle und eine ausdrückliche Ankündigung in dieser Datei.

## Nicht im Geltungsbereich

Folgendes fällt nicht in den Geltungsbereich dieser Richtlinie; bitte nutzen Sie den regulären Issue-Tracker:

- Schwachstellen in vorgelagerten Projekten, von denen wir abhängen (bitte melden Sie sie zusätzlich beim Upstream)
- Angriffe, die physischen Zugriff auf das Gerät erfordern oder erst nach Erlangung administrativer Rechte darauf auslösbar sind
- inhaltliche Korrektheit der Wissensinhalte eines Content-Packs (`content/`) — nutzen Sie ein Inhaltsfehler-Issue
- reine Konfigurationshinweise, Härtungsempfehlungen und Scanner-Warnungen ohne Reproduktionsweg
