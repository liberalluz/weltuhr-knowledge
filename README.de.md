[English](README.md) · [简体中文](README.zh-CN.md) · **Deutsch** · [Italiano](README.it.md) · [日本語](README.ja.md) · [Français](README.fr.md)

> Maßgeblich ist die englische Fassung [README.md](README.md) @ d888a44; diese Übersetzung entspricht dieser Version.

# Weltuhr

> Ein Lerngebiet zu einem Wissensraum entfalten, der **verortbar, planbar und messbar** ist — sodass aus „ich möchte X lernen" wird: „ich weiß, was ich in welcher Reihenfolge lerne und wann es als nutzbar gilt".

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

- **Wissensräume**: Wissen wird um Content-Pakete herum organisiert — ein Raum, ein Paket. Die Grenze eines Raums wird durch drei Kriterien entschieden, nicht von Hand in Schichten gezogen
- **Ein Graph, drei Projektionen**: sechs Achsen (Disziplin / Rolle / Branche / Kompetenz / Thema / Technologie-Stack) × drei Ebenen (dauerhaft / Ansicht / schnelllebig) bilden **Indexkoordinaten**, die sich als Filter stapeln lassen — keine verschachtelten Ordner; 3D-Universum, 2D-Baum und Detailansicht sind drei Projektionen desselben Graphen, die Position selbst trägt Bedeutung (`r` / `θ` / `φ`), ein kraftgerichtetes 3D-Layout wird nicht verwendet
- **Planung in drei Stufen**: Quelle (Materialien) → System (Reihenfolge) → Methode (Handlungen + Kriterien); alle drei sind selbst verfassbar, Kandidaten werden nach ihren eigenen Kriterien geordnet und die Zielkonflikte sichtbar gemacht
- **Siebenstufiger Aneignungszyklus**: Quelle wählen → System wählen → Methode wählen → Üben → Prüfen → Behalten → Ausstieg; die Wiederholung folgt FSRS. Der Fortschritt ist diskret (schreitet nie zurück) und bleibt getrennt von der Beherrschung, die kontinuierlich ist (sinken kann)
- **Zwei Arten von Notizen**: Systemnotizen (aus dem System abgeleitet) und selbst verfasste Notizen teilen denselben `itemId`-Anker und lassen sich an Ort und Stelle umschalten; der Export in externe Notizprogramme ist einwegig

## Schnellstart

> Voraussetzungen: Flutter 3.x + Dart 3.x · Serverpod 4.x (Versionen sind in `app/pubspec.yaml` / `server/pubspec.yaml` festgeschrieben) · PostgreSQL 16

```bash
git clone git@github.com:liberalluz/weltuhr-knowledge.git && cd weltuhr-knowledge

# repository-verwaltete Hooks aktivieren (Formatprüfung der Commit-Nachricht).
# Einmal pro Klon; ohne sie läuft dieselbe Regel weiterhin in der CI, sie fällt
# aber erst nach dem Push auf.
git config core.hooksPath .githooks

# Client-Abhängigkeiten
cd app && flutter pub get

# Server-Abhängigkeiten + Datenbank
cd ../server && dart pub get

# Content-Pakete erzeugen (Ausgabe wird nicht versioniert; der Client sucht <Kandidatenwurzel>/<Paketverzeichnis>/pack.json relativ zum Arbeitsverzeichnis zur Laufzeit)
cd ../content && python tools/build.py

# starten
cd ../app && flutter run -d windows
```

## Befehle

| Befehl | Wirkung |
|---|---|
| `cd app && flutter run -d windows` | Client starten |
| `cd app && flutter test --reporter compact` | Testsuite des Clients ausführen |
| `python content/tools/build.py` | Content-Paket erzeugen |
| `python content/tools/verify.py --suite` | Content-Pakete gegen ihr Schema prüfen |
| `cd app && flutter analyze && dart run tool/lint/check.dart && dart run tool/docs/check.dart` | Statische Prüfungen: Analyzer, Lint-Regeln des Repositories, Dokumentlinks und Konsistenz |

> Diese Tabelle muss dem entsprechen, was die CI tatsächlich prüft; ändert sich ein Workflow, ändert sich diese Tabelle im selben Pull Request.

## Projektstruktur

| Verzeichnis | Zuständigkeit |
|---|---|
| [app/](app/README.md) | Flutter-Client (eine Codebasis für Windows / macOS / iOS) |
| [server/](server/README.md) | Serverpod-Server: Synchronisation, Ereigniszusammenführung, Governance und Prüfung |
| [content/](content/README.md) | Quelldaten der Content-Pakete und Build-Pipeline |
| [docs/](docs/README.md) | Technische Dokumentation — Ablageregeln in [docs/README.md](docs/README.md) |
| [infra/](infra/README.md) | Build / Signierung / Updater / Spiegel / CI |

## Architektur

Drei Schichten: der Flutter-Client rendert drei Projektionen eines Graphmodells (3D-Universum / 2D-Baum / Detail); der Serverpod-Server verantwortet Synchronisation, Ereigniszusammenführung, Governance und Prüfung; Content-Pakete sind reine Daten, die `content/tools/` zu `pack.json` kompiliert. Graphmodell, seine Koordinaten und die Pfadregeln stehen in der [Spezifikationsübersicht](docs/specs/00-index.md).

Entwurfsentscheidungen und die jeweils verworfenen Alternativen: [docs/decisions/](docs/decisions/).

## Dokumentation

- Ablageregeln und Abdeckung der Wissensbereiche: [docs/README.md](docs/README.md)
- Spezifikationen und Schnittstellenverträge: [docs/specs/](docs/specs/00-index.md)
- Betrieb, Umgebungseinrichtung und wie man Dinge startet: [docs/runbooks/](docs/runbooks/)
- Methodische Grundlage des Projekts: [docs/intent/knowledge-system-learning-methodology.md](docs/intent/knowledge-system-learning-methodology.md)

## Hilfe erhalten

- Zuerst der Dokumentationsindex: [docs/README.md](docs/README.md)
- Etwas ist kaputt oder startet nicht: [docs/runbooks/](docs/runbooks/)
- Fragen und Anregungen: Issues des Repositories. Bei inhaltlichen Fehlern bitte Raumkennung und `itemId` angeben

## Mitwirken

Branch-Namen, Commit-Format, Pull Requests und die Prüfschwelle stehen in [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md).

Maintainer: liberal

## Sicherheit

Sicherheitslücken bitte über den in [.github/SECURITY.md](.github/SECURITY.md) beschriebenen vertraulichen Weg melden. Für ein Sicherheitsproblem bitte kein öffentliches Issue eröffnen.

## Lizenz

Apache-2.0 — siehe [LICENSE](LICENSE) und [NOTICE](NOTICE).
