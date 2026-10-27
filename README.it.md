[English](README.md) · [简体中文](README.zh-CN.md) · [Deutsch](README.de.md) · **Italiano** · [日本語](README.ja.md) · [Français](README.fr.md)

> Fa fede la versione inglese [README.md](README.md) @ 87e7c74; questa traduzione corrisponde a quella versione.

# Weltuhr

> Dispiegare un campo di studio in uno spazio di conoscenza **localizzabile, pianificabile e misurabile**, così che «voglio imparare X» diventi «so cosa imparare, in quale ordine, e a che punto sono quando conta come utilizzabile».

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

- **Spazi di conoscenza**: la conoscenza è organizzata attorno ai pacchetti di contenuti — uno spazio, un pacchetto. Il confine di uno spazio è deciso da tre criteri, non tracciato a mano in livelli
- **Un grafo, tre proiezioni**: sei assi (disciplina / ruolo / settore / competenza / tema / stack tecnologico) × tre livelli (persistente / vista / effimero) formano **coordinate di indice** combinabili come filtri, non cartelle annidate; universo 3D, albero 2D e pannello di dettaglio sono tre proiezioni dello stesso grafo, la posizione stessa porta significato (`r` / `θ` / `φ`) e non si usa un layout force-directed in 3D
- **Pianificazione in tre fasi**: fonte (materiali) → sistema (ordine) → metodo (azioni + criteri); tutte e tre sono redigibili dall'utente, i candidati sono ordinati secondo i propri criteri e i compromessi sono mostrati
- **Ciclo di acquisizione in sette passi**: scegliere la fonte → scegliere il sistema → scegliere il metodo → esercitare → verificare → mantenere → uscita; il ripasso segue FSRS. Il progresso è discreto (non torna mai indietro) e resta separato dalla padronanza, che è continua (può calare)
- **Due tipi di note**: le note di sistema (derivate dal sistema) e quelle scritte dall'utente condividono lo stesso ancoraggio `itemId` e si possono commutare sul posto; l'esportazione verso app di note esterne è a senso unico

## Avvio rapido

> Prerequisiti: Flutter 3.x + Dart 3.x · Serverpod 4.x (le versioni sono fissate in `app/pubspec.yaml` / `server/pubspec.yaml`) · PostgreSQL 16

```bash
git clone git@github.com:liberalluz/weltuhr-knowledge.git && cd weltuhr-knowledge

# abilitare gli hook gestiti dal repository (controllo del formato del messaggio di commit).
# Una volta per clone; senza di essi la stessa regola gira comunque in CI, ma te ne
# accorgi solo dopo il push.
git config core.hooksPath .githooks

# dipendenze del client
cd app && flutter pub get

# dipendenze del server + database
cd ../server && dart pub get

# generare i pacchetti di contenuti (l'output non è versionato; il client cerca <radice candidata>/<dir del pacchetto>/pack.json rispetto alla CWD di esecuzione)
cd ../content && python tools/build.py

# avvio
cd ../app && flutter run -d windows
```

## Comandi

| Comando | Cosa fa |
|---|---|
| `cd app && flutter run -d windows` | Avvia il client |
| `cd app && flutter test --reporter compact` | Esegue la suite di test del client |
| `python content/tools/assemble_pack.py` | Assembla `<space>/pack.json` — **è questo che legge il client** |
| `python content/tools/build.py` | Vecchio formato (cinque segmenti) in `<space>/dist/` — tenuto per le fixture di `verify.py` |
| `python content/tools/verify.py --suite` | Verifica i pacchetti di contenuti rispetto al loro schema |
| `cd app && flutter analyze && dart run tool/lint/check.dart && dart run tool/docs/check.dart` | Controlli statici: analyzer, regole lint del repository, link e coerenza della documentazione |

> Questa tabella deve corrispondere a ciò che la CI verifica davvero; se cambia un workflow, la tabella cambia nella stessa pull request.

## Struttura del progetto

| Directory | Responsabilità |
|---|---|
| [app/](app/README.md) | Client Flutter (un'unica base di codice per Windows / macOS / iOS) |
| [server/](server/README.md) | Server Serverpod: sincronizzazione, fusione degli eventi, governance e revisione |
| [content/](content/README.md) | Dati sorgente dei pacchetti di contenuti e pipeline di build |
| [docs/](docs/README.md) | Documentazione tecnica — regole di collocazione in [docs/README.md](docs/README.md) |
| [infra/](infra/README.md) | Build / firma / aggiornamento / mirror / CI |

## Architettura

Tre livelli: il client Flutter disegna tre proiezioni di un unico modello a grafo (universo 3D / albero 2D / dettaglio); il server Serverpod si occupa di sincronizzazione, fusione degli eventi, governance e revisione; i pacchetti di contenuti sono dati puri compilati da `content/tools/` in `pack.json`. Il modello a grafo, le sue coordinate e le regole dei percorsi sono nell'[indice delle specifiche](docs/specs/00-index.md).

Le decisioni di progetto e le alternative scartate: [docs/decisions/](docs/decisions/).

## Documentazione

- Regole di collocazione e copertura delle aree di conoscenza: [docs/README.md](docs/README.md)
- Specifiche e contratti di interfaccia: [docs/specs/](docs/specs/00-index.md)
- Esercizio, preparazione dell'ambiente e come avviare le cose: [docs/runbooks/](docs/runbooks/)
- Base metodologica del progetto: [docs/intent/knowledge-system-learning-methodology.md](docs/intent/knowledge-system-learning-methodology.md)

## Ottenere aiuto

- Inizia dall'indice della documentazione: [docs/README.md](docs/README.md)
- Qualcosa è rotto o non parte: [docs/runbooks/](docs/runbooks/)
- Domande e proposte: le Issues del repository. Per gli errori nei contenuti indica l'identificativo dello spazio e l'`itemId`

## Contribuire

Nomi dei branch, formato dei commit, pull request e soglia di revisione sono in [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Sicurezza

Segnala le vulnerabilità tramite il canale riservato descritto in [.github/SECURITY.md](.github/SECURITY.md). Non aprire una issue pubblica per un problema di sicurezza.

## Licenza

Rilasciato sotto [Apache-2.0](LICENSE); vedi [NOTICE](NOTICE) per l'attribuzione.
