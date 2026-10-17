# Weltuhr

[English](../../README.md) · [简体中文](README.zh.md) · [Deutsch](README.de.md) · **Italiano** · [日本語](README.ja.md) · [Français](README.fr.md)

> Traduzione di [docs/readme/README.zh.md](../../docs/readme/README.zh.md) · 2026-10-17 · fa fede la versione cinese.

> Dispiegare un campo di studio in uno spazio di conoscenza **localizzabile, pianificabile e misurabile**, così che «voglio imparare X» diventi «so cosa imparare, in quale ordine, e a che punto sono quando conta come utilizzabile».

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](../../LICENSE)

## Caratteristiche

- **Spazi di conoscenza**: la conoscenza è organizzata attorno a pacchetti di contenuti — uno spazio, un pacchetto. Il confine di uno spazio è deciso da tre criteri, non tracciato a mano in livelli
- **Coordinate, non cartelle**: sei assi (disciplina / ruolo / settore / competenza / tema / stack tecnologico) × tre livelli (persistente / vista / effimero) formano **coordinate di indice** combinabili come filtri, non cartelle annidate
- **Universo 3D + albero 2D + dettaglio**: tre proiezioni di uno stesso modello a grafo; la posizione stessa porta significato (`r` / `θ` / `φ`), senza layout force-directed in 3D
- **Pianificazione in tre fasi**: fonte (materiali) → sistema (ordine) → metodo (azioni + criteri); tutte e tre sono redigibili dall'utente, i candidati sono ordinati secondo i propri criteri e i compromessi sono mostrati
- **Ciclo di acquisizione in sette passi**: localizzare → pianificare → esercitare → verificare → mantenere → uscita; il ripasso segue FSRS. Il progresso è discreto (non torna mai indietro) e resta separato dalla padronanza, che è continua (può calare)
- **Due tipi di note**: le note di sistema (derivate dal sistema) e quelle scritte dall'utente condividono lo stesso ancoraggio `itemId` e si possono commutare sul posto; l'esportazione verso app di note esterne è a senso unico

## Avvio rapido

> Prerequisiti: Flutter 3.x + Dart 3.x · Serverpod 4.x (le versioni sono fissate in `app/pubspec.yaml` / `server/pubspec.yaml`) · PostgreSQL 16

```bash
git clone git@github.com:liberalluz/project-knowledge.git && cd project-knowledge

# dipendenze del client
cd app && flutter pub get

# dipendenze del server + database
cd ../server && dart pub get

# generare il pacchetto di contenuti (deve precedere l'avvio del client: il client cerca content/<space>/dist/pack.json rispetto alla CWD di esecuzione)
cd ../content && python tools/build.py

# avvio
cd ../app && flutter run -d windows
```

## Mappa delle directory

| Directory | Responsabilità |
|---|---|
| [app/](../../app/README.md) | Client Flutter (un'unica base di codice per Windows / macOS / iOS) |
| [server/](../../server/README.md) | Server Serverpod: sincronizzazione, fusione degli eventi, governance e revisione |
| [content/](../../content/README.md) | Dati sorgente dei pacchetti di contenuti e pipeline di build |
| [docs/](../../docs/README.md) | Documenti di consegna, documenti vivi, ADR e specifiche di progetto |
| [infra/](../../infra/README.md) | Build / firma / aggiornamento / mirror / CI |

Inoltre: [docs/reference/knowledge-system-learning-methodology.md](../../docs/reference/knowledge-system-learning-methodology.md) — la **base metodologica** di questo progetto (metodologia dell'apprendimento a sistema di conoscenza); per la specifica di progetto software vedi [docs/design/](../../docs/design/00-index.md).

## Documentazione

- [docs/README.md](../../docs/README.md) — indice della documentazione (documenti di consegna / documenti vivi / ADR)
- [docs/design/00-index.md](../../docs/design/00-index.md) — **indice delle specifiche di progetto** (FND / VIEW / PACK / PLAN / STEP / QUANT / NOTE / GOV + tabelle trasversali)

## Licenza e attribuzione

Copyright (c) 2026 liberal. Questo progetto è rilasciato con licenza [Apache-2.0](../../LICENSE); vedi anche [NOTICE](../../NOTICE).

## Contribuire e chiedere aiuto

- **Vulnerabilità di sicurezza**: non aprire una issue pubblica — segnala tramite il canale riservato descritto in [.github/SECURITY.md](../../.github/SECURITY.md) (prima risposta entro 7 giorni lavorativi)
- Domande e proposte: tramite le Issues del repository; per gli errori nei contenuti indica l'identificativo dello spazio e l'`itemId`
- Flusso di contribuzione: [.github/CONTRIBUTING.md](../../.github/CONTRIBUTING.md)
