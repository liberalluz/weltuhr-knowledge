# Come contribuire

[English](CONTRIBUTING.md) · [简体中文](CONTRIBUTING.zh.md) · [Deutsch](CONTRIBUTING.de.md) · **Italiano** · [日本語](CONTRIBUTING.ja.md) · [Français](CONTRIBUTING.fr.md)

> Traduzione di [CONTRIBUTING.zh.md](CONTRIBUTING.zh.md) · 2026-10-17 · fa fede la versione cinese.

> **Che cosa disciplina questo file**: la **governance** — chi può modificare quale livello di decisione · chi è abilitato a fare review · che cosa guarda una review · ruoli · aspettative di comportamento · tempi di risposta · licenza e DCO.
> **Che cosa non disciplina**: **processo e formato** — struttura del repository · branch · formato dei commit · granularità delle PR · **numero di approval** · strategia di merge · versioni e tag · numeri di versione dei documenti di consegna. Tutto questo fa fede in [`docs/guides/git-conventions.md`](../docs/guides/git-conventions.md) e non viene duplicato qui. Contenuti di design → [`docs/design/00-index.md`](../docs/design/00-index.md); vulnerabilità di sicurezza → [`SECURITY.md`](SECURITY.it.md).

## 1. Confini di competenza

La base di design di questo repository è fatta di **specifiche numerate e già deliberate** (numero di voci in [`docs/design/00-index.md`](../docs/design/00-index.md); questo file non lo ripete). Nella collaborazione tra più persone la prima disciplina non è «come si scrive il codice», ma **chi può cambiare una decisione**: una modifica sbagliata al codice si annulla, una decisione sbagliata fa deviare nella stessa direzione tutte le implementazioni a valle, e nessun test se ne accorgerà.

| Oggetto della modifica | Esempio | Chi decide | Che cosa serve |
|---|---|---|---|
| **Implementazione** | correzione di bug, refactoring, test aggiunti, ritocchi di layout | chiunque contribuisca | PR + review (numero secondo i manutentori, vedi §4) |
| **Documenti di livello C** | formulazioni, esempi, link morti | chiunque contribuisca | una frase nella PR |
| **Livello B** | valori delle costanti, nullabilità dei campi, nuovi tipi di evento | conferma di un manutentore | PR + nota di modifica + aggiornare la tabella trasversale |
| **Livello A** | sei assi, `⪯`, modello degli eventi, tabella dei canali, protocollo | **solo i manutentori** | prima una issue → ADR → poi si modifica la specifica |
| **Livello D** | conflitto con la [lista NOT](../docs/reference/not-list.md) | **solo un manutentore può ribaltare una voce NOT** | non farlo; se indispensabile, lasciare traccia |
| **Valori TBD** | soglia di sfocatura della ricerca `C-28`, ecc. | **solo i manutentori** | non compilare, non fornire un valore predefinito |
| **Impegni verso l'esterno** | licenza, finestra delle versioni supportate, tempi di risposta, nome del marchio | **solo i manutentori** | la modifica richiede annuncio esplicito e traccia |

I criteri di classificazione non vengono ripetuti qui: vedi [git-conventions §4.4 classificazione delle modifiche](../docs/guides/git-conventions.md) e [design/00-index §7](../docs/design/00-index.md). Questa tabella risponde solo a «chi firma».

**Perché le ultime tre righe stanno a parte** — sembrano tutte un «basta inserire un valore» o «basta cambiare una frase», ma il costo ricade su altri:

- dare a `C-28` un 0,6 tanto per fare sposta in silenzio il comportamento «un solo risultato salta subito» della ricerca — **nessun test diventa rosso**;
- cambiare «7 giorni lavorativi» viola un impegno verso l'esterno, mentre il diff della PR è lungo una riga;
- cambiare la finestra delle versioni supportate invalida il percorso di aggiornamento di tutti gli utenti delle versioni precedenti.

⚠️ **Il contributo fuori perimetro più frequente**: nel codice `C-28` è la sentinella `throw TbdConstantError`; chi la incontra va in crash. È **voluto**, non è un bug. «Sistemo subito questo crash e metto un valore predefinito ragionevole» è la tipica modifica fuori perimetro — davanti a una sentinella apri una issue, non aggiungere un valore predefinito.

## 2. Quattro vie d'ingresso

| Che cosa vuoi fare | Come iniziare | Serve prima una issue? |
|---|---|---|
| Segnalare un difetto | issue con **versione + piattaforma + passi di riproduzione** | — |
| Segnalare un errore nei contenuti | issue con **identificativo dello spazio + `itemId`** | — |
| Modifica piccola (documentazione, commenti, correzione puntuale) | apri direttamente una PR | No |
| Nuova funzionalità / modifica di design / intervento su criteri di livello A o B | prima apri una issue e discuti fino all'accordo | **Sì** |

Il criterio per «modifica piccola»: si spiega in un solo messaggio di commit e non tocca nessuna voce di `docs/design/`.

Una PR grande mai discussa viene chiusa anziché revisionata — non per scortesia, ma perché **revisionare una modifica di livello A già conclusa** equivale a ratificarla a posteriori, e costa più che discuterne fin dall'inizio.

## 3. Cinque cose prima di aprire una PR

| # | Voce | Criterio |
|---|---|---|
| 1 | Autoverifica locale | esegui tutto quanto in [git-conventions §7 autoverifica prima del commit](../docs/guides/git-conventions.md); incolla nel corpo della PR i **comandi realmente eseguiti e il loro output** |
| 2 | Asserzione osservabile | un nuovo comportamento richiede un vettore di test; «è implementato nel codice» non è accettazione (`X-05`, vedi [00-index §4](../docs/design/00-index.md)) |
| 3 | Firma DCO | `git commit -s`, ogni commit porta `Signed-off-by` (vedi §8) |
| 4 | Una cosa per PR | refactoring e cambio di comportamento non si mescolano; codice e documentazione non si mescolano nello stesso commit |
| 5 | Niente bagagli | modifica solo ciò che hai descritto; un problema estraneo che noti merita **una issue a parte**, non un riordino / rinomina / abbellimento di passaggio |

Perché esiste la regola 5: documentazione e codice di questo repository seguono convenzioni fisse (tabelle per prime, citare invece di duplicare, nulla viene disegnato se il modello non lo dichiara). Il prezzo del «sistemo al volo» è che la revisione deve distinguere riga per riga qual è la modifica vera, e annullare una PR così costa molto più di quanto abbia reso.

**Chi usa un assistente AI per scrivere codice è soggetto a tutte queste regole**, più una: «funziona» detto da un modello non è una prova — incolla l'output del tuo terminale. La semantica di piattaforma e runtime si stabilisce con la documentazione ufficiale e con i risultati su hardware reale, non con una build locale.

## 4. Revisione

**Il numero non si stabilisce qui**: le approval seguono il numero di manutentori (un solo manutentore **0** · da 2 manutentori **1**, e non deve essere l'autore). La regola è in [git-conventions §4.1](../docs/guides/git-conventions.md). Questa sezione risponde solo a **chi è abilitato** e **che cosa si guarda**.

- **Finché il manutentore è uno solo**: la **conclusione di autoverifica** nel corpo della PR sostituisce l'approval (che cosa è cambiato / come è stato verificato / perché è tagliato così). Non è un'esenzione, è una revisione scambiata con una traccia scritta; decade nel momento in cui compare un secondo manutentore.
- **Modifiche di livello A e B**: qualunque sia il numero di persone, un manutentore partecipa alla revisione.
- La revisione guarda quattro cose, non le preferenze di stile:

| # | Che cosa si guarda | Base |
|---|---|---|
| 1 | c'è l'asserzione osservabile | `X-05` |
| 2 | le regole sono **citate** o copiate in una seconda fonte | [docs/README §5](../docs/README.md) |
| 3 | l'interfaccia disegna di nascosto un campo che il modello non ha mai dichiarato | `X-01` |
| 4 | viene toccata la lista NOT | [not-list](../docs/reference/not-list.md) |

⚠️ **Stato attuale**: su `main` la protezione dei branch non è attiva (i repository privati degli account GitHub gratuiti non la supportano), quindi i vincoli qui sopra **si reggono sulla disciplina** e non su un blocco tecnico — vedi [git-conventions §4.3 stato del remoto](../docs/guides/git-conventions.md). Il fatto che tecnicamente nulla lo impedisca non lo rende permesso.

## 5. Ruoli

| Ruolo | Permessi | Come si ottiene |
|---|---|---|
| **Contributor** | aprire issue e PR | nessuna richiesta |
| **Reviewer** | approvare / chiedere modifiche | invito di un manutentore (soglia: vedi la voce in sospeso qui sotto) |
| **Maintainer** | fare merge, deliberare su A/B, pubblicare release, cambiare le impostazioni del repository | accordo unanime dei manutentori esistenti |

Manutentore attuale: [@liberalluz](https://github.com/liberalluz)

## 6. Comportamento atteso

Questo repository non ha ancora un `CODE_OF_CONDUCT.md` separato; nel frattempo valgono queste quattro regole:

1. **Contesta la tesi, non la persona** — i disaccordi tecnici si risolvono con prove e asserzioni osservabili, non con l'anzianità.
2. **Non sollecitare** — i tempi sono al §7; passata la scadenza puoi chiedere, ma non far risalire più volte la stessa discussione.
3. **Non decidere al posto altrui** — i valori di competenza di altri (le ultime tre righe del §1) non si compilano, anche quando la risposta sembra ovvia.
4. **Nessuna autodichiarazione** — «da me funziona» non è una prova.

Gestione delle violazioni: un manutentore può bloccare una discussione, chiudere una PR o rifiutare ulteriori contributi. Un codice di condotta formale (Contributor Covenant 2.1) arriverà quando la base di contributori crescerà; a quel punto questa sezione diventerà un rimando (soglia di attivazione **TBD**).

## 7. Tempi di risposta

| Voce | Tempo |
|---|---|
| Prima risposta a una issue | entro 7 giorni lavorativi (stesso criterio di [`SECURITY.md`](SECURITY.it.md)) |
| Primo parere di revisione su una PR | **TBD** — non definito, per ora si applicano i 7 giorni lavorativi delle issue |
| Chiusura di una PR senza aggiornamenti da molto tempo | **TBD** — non definito, la prassi attuale è chiedere una volta e poi decidere |

⚠️ Quanto sopra **non costituisce un SLA**: è il miglior sforzo dei manutentori. Modificare queste due righe rientra negli «impegni verso l'esterno» del §1 e richiede un annuncio esplicito.

## 8. Licenza e attribuzione

- Inviando, accetti che il tuo contributo sia distribuito sotto **Apache-2.0** (vedi [`../LICENSE`](../LICENSE), [`../NOTICE`](../NOTICE)).
- **DCO**: i commit devono usare `git commit -s` e riportare `Signed-off-by: Il tuo nome <email>`, certificando che hai il diritto di inviare il contenuto (testo su [developercertificate.org](https://developercertificate.org/)). Non è una cessione del copyright, che resta tuo.
- I contenuti di conoscenza di un **content pack** (`content/`) devono essere originali, oppure provenire da fonti con licenza compatibile con questo progetto; **non introdurre** testi o materiali da fonti CC-BY-NC, GPL o AGPL (criteri in [dependency-licenses §2](../docs/guides/dependency-licenses.md)). Una correzione dei contenuti non modifica l'attribuzione dell'autore originale.
- Codice o materiali di terzi vanno registrati **nella stessa PR** in [`../NOTICE`](../NOTICE) e nell'[elenco delle licenze delle dipendenze](../docs/guides/dependency-licenses.md).

## Appendice: ambiente locale

Le versioni di Flutter / Dart / Serverpod sono fissate in `app/pubspec.yaml` e `server/pubspec.yaml` e **non seguono l'ultima**. La configurazione dell'ambiente e le trappole note di una prima build su Windows (symlink, modalità sviluppatore) sono in [`docs/guides/environment.md`](../docs/guides/environment.md).
