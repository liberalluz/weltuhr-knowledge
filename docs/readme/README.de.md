# Weltuhr

[English](../../README.md) · [简体中文](README.zh.md) · **Deutsch** · [Italiano](README.it.md) · [日本語](README.ja.md) · [Français](README.fr.md)

> Übersetzung von [docs/readme/README.zh.md](../../docs/readme/README.zh.md) · 2026-10-17 · maßgeblich ist die chinesische Fassung.

> Ein Lerngebiet zu einem Wissensraum entfalten, der **verortbar, planbar und messbar** ist — sodass aus „ich möchte X lernen" wird: „ich weiß, was ich in welcher Reihenfolge lerne und wann es als nutzbar gilt".

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](../../LICENSE)

## Merkmale

- **Wissensräume**: Wissen wird um Content-Pakete herum organisiert — ein Raum, ein Paket. Die Grenze eines Raums wird durch drei Kriterien entschieden, nicht von Hand in Schichten gezogen
- **Koordinaten statt Ordner**: sechs Achsen (Disziplin / Rolle / Branche / Kompetenz / Thema / Technologie-Stack) × drei Ebenen (dauerhaft / Ansicht / schnelllebig) bilden **Indexkoordinaten**, die sich als Filter stapeln lassen — keine verschachtelten Ordner
- **3D-Universum + 2D-Baum + Detail**: drei Projektionen ein und desselben Graphmodells; die Position selbst trägt Bedeutung (`r` / `θ` / `φ`), ein kraftgerichtetes 3D-Layout wird nicht verwendet
- **Planung in drei Stufen**: Quelle (Materialien) → System (Reihenfolge) → Methode (Handlungen + Kriterien); alle drei sind selbst verfassbar, Kandidaten werden nach ihren eigenen Kriterien geordnet und die Zielkonflikte sichtbar gemacht
- **Siebenstufiger Aneignungszyklus**: Verorten → Planen → Üben → Prüfen → Behalten → Ausstieg; die Wiederholung folgt FSRS. Der Fortschritt ist diskret (schreitet nie zurück) und bleibt getrennt von der Beherrschung, die kontinuierlich ist (sinken kann)
- **Zwei Arten von Notizen**: Systemnotizen (aus dem System abgeleitet) und selbst verfasste Notizen teilen denselben `itemId`-Anker und lassen sich an Ort und Stelle umschalten; der Export in externe Notizprogramme ist einwegig

## Schnellstart

> Voraussetzungen: Flutter 3.x + Dart 3.x · Serverpod 4.x (Versionen sind in `app/pubspec.yaml` / `server/pubspec.yaml` festgeschrieben) · PostgreSQL 16

```bash
git clone git@github.com:liberalluz/project-knowledge.git && cd project-knowledge

# Client-Abhaengigkeiten
cd app && flutter pub get

# Server-Abhaengigkeiten + Datenbank starten
cd ../server && dart pub get

# Content-Paket erzeugen (muss vor dem Start des Clients laufen: der Client sucht content/<space>/dist/pack.json relativ zum Arbeitsverzeichnis zur Laufzeit)
cd ../content && python tools/build.py

# starten
cd ../app && flutter run -d windows
```

## Verzeichnisübersicht

| Verzeichnis | Zuständigkeit |
|---|---|
| [app/](../../app/README.md) | Flutter-Client (eine Codebasis für Windows / macOS / iOS) |
| [server/](../../server/README.md) | Serverpod-Server: Synchronisation, Ereigniszusammenführung, Governance und Prüfung |
| [content/](../../content/README.md) | Quelldaten der Content-Pakete und Build-Pipeline |
| [docs/](../../docs/README.md) | Lieferdokumente, lebende Dokumente, ADRs und Design-Spezifikationen |
| [infra/](../../infra/README.md) | Build / Signierung / Updater / Spiegel / CI |

Außerdem: [docs/reference/knowledge-system-learning-methodology.md](../../docs/reference/knowledge-system-learning-methodology.md) — die **methodische Grundlage** dieses Projekts (Methodik des Wissenssystem-Lernens); zur Software-Design-Spezifikation siehe [docs/design/](../../docs/design/00-index.md).

## Dokumentation

- [docs/README.md](../../docs/README.md) — Index der Dokumentation (Lieferdokumente / lebende Dokumente / ADRs)
- [docs/design/00-index.md](../../docs/design/00-index.md) — **Index der Design-Spezifikation** (FND / VIEW / PACK / PLAN / STEP / QUANT / NOTE / GOV + Querschnittstabellen)

## Lizenz und Namensnennung

Copyright (c) 2026 liberal. Dieses Projekt steht unter der Lizenz [Apache-2.0](../../LICENSE); siehe auch [NOTICE](../../NOTICE).

## Mitwirken und Hilfe

- **Sicherheitslücken**: bitte kein öffentliches Issue eröffnen — melden über den vertraulichen Kanal in [.github/SECURITY.de.md](../../.github/SECURITY.de.md) (erste Rückmeldung innerhalb von 7 Werktagen zugesagt)
- Fragen und Vorschläge: über die Issues des Repositories; bei inhaltlichen Fehlern bitte Raumkennung und `itemId` angeben
- Beitragsablauf: [.github/CONTRIBUTING.de.md](../../.github/CONTRIBUTING.de.md)
