# Politica di sicurezza

[English](SECURITY.md) · [简体中文](SECURITY.zh.md) · [Deutsch](SECURITY.de.md) · **Italiano** · [日本語](SECURITY.ja.md) · [Français](SECURITY.fr.md)

> Traduzione di [SECURITY.zh.md](SECURITY.zh.md) · 2026-10-17 · fa fede la versione cinese.

## Versioni supportate

Gli aggiornamenti di sicurezza sono forniti solo per le seguenti versioni:

| Versione | Supportata |
|---|---|
| L'ultima versione minor pubblicata | ✅ |
| Versioni minor precedenti / tutti i rami di sole patch | ❌ |

> Criterio: **solo l'ultima minor**. Chi usa versioni precedenti deve aggiornare all'ultima minor per ricevere le correzioni di sicurezza.

## Segnalare una vulnerabilità

**Non segnalare le vulnerabilità di sicurezza tramite issue pubbliche.**

Inviarle dalla pagina **Security** di questo repository → **Report a vulnerability** (canale privato di GitHub per le vulnerabilità).
Tale canale è visibile ai manutentori e non al pubblico, il che consente una collaborazione riservata fino al rilascio della correzione.

Includere quanto più possibile: versione interessata, passi di riproduzione, valutazione dell'impatto e, quando possibile, un esempio minimo di riproduzione.

## Tempi di risposta

Ci impegniamo a rispondere per la prima volta entro **7 giorni lavorativi** dalla ricezione della segnalazione.

> ⚠️ Questa politica **non costituisce un SLA**. Sia il termine sia il canale sono impegni verso l'esterno; ogni modifica richiede controllo delle modifiche e un annuncio esplicito in questo file.

## Fuori perimetro

Quanto segue è fuori dal perimetro di questa politica; usare il normale issue tracker:

- vulnerabilità nei progetti upstream da cui dipendiamo (segnalarle anche a monte)
- attacchi che richiedono accesso fisico al dispositivo, o che sono raggiungibili solo dopo averne ottenuto i privilegi amministrativi
- problemi di correttezza dei contenuti di conoscenza di un content pack (`content/`) — usare una issue di correzione contenuti
- semplici consigli di configurazione, suggerimenti di irrobustimento e avvisi di scanner privi di un percorso di riproduzione
