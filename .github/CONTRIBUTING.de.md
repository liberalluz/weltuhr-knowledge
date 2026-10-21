# Mitwirken

[English](CONTRIBUTING.md) · [简体中文](CONTRIBUTING.zh.md) · **Deutsch** · [Italiano](CONTRIBUTING.it.md) · [日本語](CONTRIBUTING.ja.md) · [Français](CONTRIBUTING.fr.md)

> Übersetzung von [CONTRIBUTING.zh.md](CONTRIBUTING.zh.md) · 2026-10-17 · maßgeblich ist die chinesische Fassung.

> **Was diese Datei regelt**: **Governance** — wer welche Entscheidungsebene ändern darf · wer reviewen darf · worauf ein Review schaut · Rollen · Verhaltenserwartungen · Reaktionszeiten · Lizenz und DCO.
> **Was sie nicht regelt**: **Prozess und Format** — Repository-Struktur · Branches · Commit-Format · PR-Granularität · **Anzahl der Approvals** · Merge-Strategie · Versionen und Tags · Versionsnummern der Lieferdokumente. All das ist maßgeblich in [`docs/guides/git-conventions.md`](../docs/guides/git-conventions.md) geregelt und wird hier nicht dupliziert. Designinhalte → [`docs/design/00-index.md`](../docs/design/00-index.md); Sicherheitslücken → [`SECURITY.md`](SECURITY.de.md).

## 1. Zuständigkeitsgrenzen

Die Designbasis dieses Repositories besteht aus **entschiedenen, nummerierten Spezifikationen** (Anzahl der Einträge in [`docs/design/00-index.md`](../docs/design/00-index.md); diese Datei wiederholt sie nicht). Bei Zusammenarbeit mehrerer Personen lautet die erste Disziplin nicht „wie schreibt man Code", sondern **wer eine Entscheidung ändern darf**: ein falscher Codeänderung lässt sich zurücknehmen, eine falsche Entscheidung schickt alle nachgelagerten Implementierungen in dieselbe Richtung und kein Test wird sie je bemerken.

| Änderungsobjekt | Beispiel | Wer entscheidet | Erforderlich |
|---|---|---|---|
| **Implementierung** | Bugfix, Refactoring, zusätzliche Tests, Layout-Feinschliff | jede mitwirkende Person | PR + Review (Anzahl nach Zahl der Maintainer, siehe §4) |
| **Dokumente der Stufe C** | Formulierungen, Beispiele, tote Links | jede mitwirkende Person | ein Satz im PR |
| **Stufe B** | Konstantenwerte, Nullbarkeit von Feldern, neue Ereignistypen | Bestätigung durch einen Maintainer | PR + Änderungsnotiz + Querschnittstabelle nachtragen |
| **Stufe A** | sechs Achsen, `⪯`, Ereignismodell, Kanaltabelle, Protokoll | **nur Maintainer** | zuerst Issue → ADR → dann die Spezifikation ändern |
| **Stufe D** | Konflikt mit der [NOT-Liste](../docs/reference/not-list.md) | **nur ein Maintainer darf einen NOT-Eintrag kippen** | nicht tun; wenn doch, Nachweis hinterlassen |
| **TBD-Werte** | `C-28` Schwellwert für Suchunschärfe u. a. | **nur Maintainer** | nicht ausfüllen, keinen Standardwert liefern |
| **Externe Zusagen** | Lizenz, Fenster unterstützter Versionen, Reaktionszeiten, Markenname | **nur Maintainer** | Änderung erfordert ausdrückliche Ankündigung und Nachweis |

Die Kriterien der Einstufung selbst werden hier nicht wiederholt; siehe [git-conventions §4.4 Änderungseinstufung](../docs/guides/git-conventions.md) und [design/00-index §7](../docs/design/00-index.md). Diese Tabelle beantwortet nur „wer zeichnet ab".

**Warum die letzten drei Zeilen separat stehen** — sie sehen alle nach „einen Wert eintragen" oder „einen Satz ändern" aus, doch die Kosten tragen andere:

- gibt man `C-28` beiläufig 0,6, verschiebt sich das Suchverhalten „ein einzelner Treffer springt direkt durch" still — **kein Test wird rot**;
- „7 Werktage" zu ändern bricht eine externe Zusage, während der PR-Diff eine Zeile lang ist;
- eine Änderung des Fensters unterstützter Versionen macht den Upgrade-Pfad aller Nutzer älterer Versionen ungültig.

⚠️ **Häufigster Fehlbeitrag**: Im Code ist `C-28` der Sentinel `throw TbdConstantError`; wer ihn liest, stürzt ab. Das ist **Absicht**, kein Bug. „Diesen Absturz schnell beheben und einen sinnvollen Standardwert einsetzen" ist die typische Grenzüberschreitung — bei einem Sentinel bitte ein Issue öffnen, keinen Standardwert ergänzen.

## 2. Vier Zugangswege

| Was Sie tun möchten | Wie Sie beginnen | Vorher ein Issue? |
|---|---|---|
| Einen Defekt melden | Issue mit **Version + Plattform + Reproduktionsschritten** | — |
| Einen Inhaltsfehler melden | Issue mit **Space-Kennung + `itemId`** | — |
| Kleine Änderung (Doku, Kommentar, punktueller Fix) | direkt einen PR öffnen | Nein |
| Neues Feature / Designänderung / Eingriff in Kriterien der Stufe A oder B | zuerst ein Issue öffnen und Einigkeit erzielen | **Ja** |

Das Kriterium für „kleine Änderung": in einer Commit-Nachricht darstellbar und ohne Berührung irgendeines Eintrags in `docs/design/`.

Ein großer PR ohne vorherige Diskussion wird geschlossen statt reviewt — nicht aus Unfreundlichkeit, sondern weil **das Review einer bereits fertigen Änderung der Stufe A** einer nachträglichen Absegnung gleichkommt und mehr kostet als eine Diskussion von Anfang an.

> **Einmalig vor dem Start**: `git config core.hooksPath .githooks` — ohne dies greift der lokale Hook nie, und ein direkter Push auf `main` faellt der CI erst **nach dem Push** auf. Befehl und Fehlerbild: [git-conventions §2.1](../docs/guides/git-conventions.md).

## 3. Fünf Dinge vor dem PR

| # | Punkt | Kriterium |
|---|---|---|
| 1 | Lokale Selbstprüfung | alles aus [git-conventions §7 Selbstprüfung vor dem Commit](../docs/guides/git-conventions.md) ausführen; im PR-Text die **tatsächlich ausgeführten Befehle samt Ausgabe** einfügen |
| 2 | Beobachtbare Zusicherung | neues Verhalten braucht einen Testvektor; „ist im Code umgesetzt" gilt nicht als Abnahme (`X-05`, siehe [00-index §4](../docs/design/00-index.md)) |
| 3 | DCO-Unterzeichnung | `git commit -s`, jeder Commit trägt `Signed-off-by` (siehe §8) |
| 4 | Eine Sache pro PR | Refactoring und Verhaltensänderung nicht mischen; Code und Doku nicht in einem Commit |
| 5 | Keine Beifänge | nur ändern, was beschrieben wurde; ein beiläufig gefundenes fremdes Problem bekommt **ein eigenes Issue**, kein Mitnahme-Umsortieren / Umbenennen / Verschönern |

Herkunft von Regel 5: Doku und Code dieses Repositories folgen festen Konventionen (Tabellen zuerst, zitieren statt duplizieren, nichts wird gerendert, was das Modell nicht deklariert). Der Preis von „mal eben aufräumen" ist, dass das Review Zeile für Zeile klären muss, was die eigentliche Änderung ist — und das Zurücknehmen eines solchen PR kostet weit mehr, als er eingebracht hat.

**Wer einen KI-Assistenten zum Schreiben von Code nutzt, unterliegt allen Regeln**, plus einer weiteren: „läuft durch" aus dem Mund eines Modells ist kein Nachweis — die Ausgabe aus dem eigenen Terminal einfügen. Semantik von Plattform und Laufzeit bemisst sich an offizieller Dokumentation und an Ergebnissen auf echter Hardware, nicht an einem lokalen Build.

## 4. Review

**Die Anzahl wird hier nicht festgelegt**: Approvals richten sich nach der Zahl der Maintainer (ein Maintainer **0** · ab 2 Maintainern **1**, und nicht durch die Autorin oder den Autor). Die Regel steht in [git-conventions §4.1](../docs/guides/git-conventions.md). Dieser Abschnitt beantwortet nur, **wer berechtigt ist** und **worauf geschaut wird**.

- **Solange es einen einzigen Maintainer gibt**: Die **Selbstprüfungs-Schlussfolgerung** im PR-Text ersetzt das Approval (was geändert / wie geprüft / warum so geschnitten). Das ist keine Ausnahme, sondern Review gegen einen schriftlichen Nachweis getauscht; sie endet, sobald ein zweiter Maintainer auftritt.
- **Änderungen der Stufe A und B**: unabhängig von der Personenzahl nimmt ein Maintainer am Review teil.
- Das Review prüft vier Dinge, nicht stilistische Vorlieben:

| # | Worauf geschaut wird | Grundlage |
|---|---|---|
| 1 | ist die beobachtbare Zusicherung vorhanden | `X-05` |
| 2 | werden Regeln **zitiert** oder in eine zweite Quelle kopiert | [docs/README §5](../docs/README.md) |
| 3 | zeichnet die Oberfläche stillschweigend ein Feld, das das Modell nie deklariert hat | `X-01` |
| 4 | wird die NOT-Liste berührt | [not-list](../docs/reference/not-list.md) |

⚠️ **Aktueller Stand**: Auf `main` ist kein Branch-Schutz aktiv (private Repositories kostenloser GitHub-Konten unterstützen ihn nicht), die genannten Vorgaben **beruhen daher auf Disziplin** statt auf technischer Durchsetzung — siehe [git-conventions §4.3 Remote-Stand](../docs/guides/git-conventions.md). Dass technisch nichts blockiert, macht es nicht erlaubt.

## 5. Rollen

| Rolle | Rechte | Erwerb |
|---|---|---|
| **Contributor** | Issues und PRs eröffnen | keine Bewerbung nötig |
| **Reviewer** | approven / Änderungen anfordern | Einladung durch einen Maintainer (Schwelle: siehe offener Punkt unten) |
| **Maintainer** | mergen, Stufe A/B entscheiden, Releases schneiden, Repository-Einstellungen ändern | einstimmige Zustimmung der bestehenden Maintainer |

Aktueller Maintainer: [@liberalluz](https://github.com/liberalluz)

## 6. Erwartetes Verhalten

Dieses Repository hat noch keinen eigenen `CODE_OF_CONDUCT.md`; bis dahin gelten diese vier Regeln:

1. **Zur Sache, nicht zur Person** — technische Meinungsverschiedenheiten werden mit Belegen und beobachtbaren Zusicherungen entschieden, nicht mit Seniorität.
2. **Nicht drängeln** — Fristen siehe §7; nach Ablauf darf man nachfragen, aber denselben Thread nicht wiederholt nach oben schieben.
3. **Nicht für andere ausfüllen** — Werte, die andere verantworten (die letzten drei Zeilen von §1), entscheidet man nicht mit, auch wenn die Antwort offensichtlich scheint.
4. **Keine Selbstbescheinigung** — „läuft bei mir" ist kein Nachweis.

Umgang mit Verstößen: Ein Maintainer kann Diskussionen sperren, einen PR schließen oder weitere Beiträge ablehnen. Ein formeller Verhaltenskodex (Contributor Covenant 2.1) folgt, sobald die Zahl der Beitragenden wächst; dieser Abschnitt wird dann zum Verweis (Auslöseschwelle **TBD**).

## 7. Reaktionszeiten

| Vorgang | Frist |
|---|---|
| Erste Antwort auf ein Issue | innerhalb von 7 Werktagen (gleiche Regel wie [`SECURITY.md`](SECURITY.de.md)) |
| Erstes Review-Statement zu einem PR | **TBD** — offen, derzeit gilt die 7-Werktage-Regel für Issues |
| Schließen eines lange unveränderten PR | **TBD** — offen, aktuelle Praxis ist einmal nachfragen, dann entscheiden |

⚠️ All das **ist kein SLA**, sondern das Bemühen der Maintainer. Eine Änderung dieser beiden Zeilen fällt unter „externe Zusagen" in §1 und erfordert eine ausdrückliche Ankündigung.

## 8. Lizenz und Namensnennung

- Mit dem Einreichen stimmen Sie zu, dass Ihr Beitrag unter **Apache-2.0** verbreitet wird (siehe [`../LICENSE`](../LICENSE), [`../NOTICE`](../NOTICE)).
- **DCO**: Commits müssen mit `git commit -s` und `Signed-off-by: Ihr Name <E-Mail>` versehen sein und damit bestätigen, dass Sie das Material einreichen dürfen (Text unter [developercertificate.org](https://developercertificate.org/)). Das ist keine Urheberrechtsübertragung; das Urheberrecht bleibt bei Ihnen.
- Wissensinhalte eines **Content-Packs** (`content/`) müssen originär sein oder aus Quellen stammen, deren Lizenz mit diesem Projekt vereinbar ist; **nicht einführen** darf man Texte und Materialien aus CC-BY-NC-, GPL- oder AGPL-Quellen (Kriterien in [dependency-licenses §2](../docs/guides/dependency-licenses.md)). Ein Inhaltsfehler ändert die Namensnennung der ursprünglichen Autorin oder des Autors nicht.
- Fremder Code und fremdes Material müssen **im selben PR** in [`../NOTICE`](../NOTICE) und in der [Liste der Abhängigkeitslizenzen](../docs/guides/dependency-licenses.md) eingetragen werden.

## Anhang: lokale Umgebung

Die Versionen von Flutter / Dart / Serverpod sind in `app/pubspec.yaml` und `server/pubspec.yaml` festgeschrieben und **folgen nicht dem neuesten Stand**. Einrichtung und bekannte Stolpersteine eines ersten Windows-Builds (Symlinks, Entwicklermodus) stehen in [`docs/guides/environment.md`](../docs/guides/environment.md).
