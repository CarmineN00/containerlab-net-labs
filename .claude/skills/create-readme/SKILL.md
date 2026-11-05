---
name: create-readme
description: Crea o riscrive il README.md di un qualsiasi lab containerlab del repo (OSPF, EIGRP, BGP, DMVPN, ...). Avvia il lab se serve, entra in SSH sui router, cattura io stesso gli screenshot reali delle sessioni in Windows Terminal (pochi, sugli aspetti più evidenti) e scrive il README nello stile degli altri lab. Usare quando l'utente chiede di documentare un lab o di fare/aggiornare il README di un lab.
---

# Create README: lab → SSH → screenshot → README

Obiettivo: partendo da un lab già configurato (`configs/` completi, lab deployabile), produrre un `README.md` esplicativo con screenshot reali degli output dei nodi, coerente con i README esistenti del repo. Prima di scrivere, leggi 1–2 README di lab già documentati (es. `ospf/`, `dmvpn-p1/`, `dmvpn-p2-p3/`) come riferimento di stile.

Argomento atteso: la directory del lab. Se manca, chiederla.

**Faccio tutto io**, dall'avvio del lab alle catture: all'utente non si chiede di fare screenshot.

## Regole (non negoziabili)

- **Solo gli aspetti più evidenti.** Non eseguire tutte le prove possibili del concetto: per ogni obiettivo del lab scegli la verifica più diretta e leggibile (la config chiave, lo stato che dimostra che funziona, al massimo un prima/dopo). Tipicamente 4–6 screenshot più la topologia. Se due output dimostrano la stessa cosa, tienine uno.
- **Riusa il tooling esistente, non reinventarlo.** Deploy con `clab deploy` dentro la directory del lab; `scripts/lab_tools.py` (`export-configs`, `open-sessions`); `scripts/create_bridge.sh` per i bridge host. Per le catture usa gli script di questa skill (sotto), non scriverne di nuovi.
- **Gli screenshot sono catture reali di finestre Windows Terminal** con una sessione SSH vera verso il router. **Mai** generare immagini finte (PIL, HTML→PNG, render del testo, ecc.).
- Non modificare `configs/` né la config dei nodi senza chiedere: lo scopo è osservare e documentare. Comandi exec che non toccano la config (`clear crypto session`, `clear ip nhrp`, ping, traceroute) vanno bene. Se una dimostrazione richiede una modifica temporanea della config, proporla all'utente e alla fine verificare che la config sia tornata identica a `configs/`.
- Commit solo se l'utente lo chiede.

## Script di cattura (`scripts/` di questa skill)

- `shot.sh <TITOLO_TAB> <mgmt-ip> <out.png> <cols> <rows> <cmdfile> [delay]`: apre una nuova finestra `wt.exe` con tab titolata (es. `R1`, stile delle immagini esistenti), avvia una sessione SSH interattiva, "digita" i comandi del `cmdfile`, cattura la finestra in PNG e la chiude.
  - `cmdfile`: un comando per riga; `#sleep N` aggiunge una pausa (dopo ping/traceroute lunghi, così il comando successivo non viene digitato mentre il precedente gira).
  - `delay`: secondi tra un comando e l'altro (default 2).
  - Prima dei comandi la sessione fa `terminal length 0` / `terminal width 0` e pulisce lo schermo, così nello screenshot compaiono solo i comandi significativi.
- `session.sh`, `list_wt.ps1`, `capture.ps1`: usati da `shot.sh`.
- Scegli `cols`/`rows` in base all'output (di solito 100 colonne; righe ≈ righe di output + 4) in modo che non ci siano righe tagliate in alto né troppo vuoto in basso.
- Tieni i `cmdfile` nella scratchpad, non nel repo.

## Passi

### 1. Capire cosa insegna il lab
- Se nella directory c'è un PDF dell'esercitazione, leggilo: gli obiettivi e i task sono ciò che va documentato. Altrimenti ricava gli obiettivi da config e storia git, e chiedi all'utente se qualcosa non è chiaro.
- Leggi il `*.clab.yml` e `configs/*`; guarda `git log` / `git diff` sulla directory: i commit di configurazione dicono cosa è stato fatto e in che ordine.
- Segnala all'utente le differenze tra PDF e config (es. un parametro cambiato perché deprecato) e chiedi il motivo, per poterlo scrivere nel README.
- Se il lab continua un lab precedente, leggi quel README: il nuovo deve riprendere da lì con un link relativo, senza ripetere tutto. Se la topologia è identica, chiedi se riusare la sua immagine.

### 2. Lab attivo
- Verifica che i nodi rispondano in SSH (gli IP di management sono nel `.clab.yml`, credenziali default `admin`/`admin`). Se non sono su: crea eventuali bridge host richiesti con `scripts/create_bridge.sh`, poi `clab deploy` dalla directory del lab, e attendi il boot.

### 3. Esplorare via SSH (non interattivo)
Prima di catturare, guarda gli output in modo non interattivo per scegliere cosa mostrare. IOS accetta un solo comando per sessione `ssh host "cmd"`, quindi per più comandi usa netmiko dal `venv/` del repo (come fa `lab_tools.py`). I valori citati nel README (flag, stati, metriche, next hop, contatori) devono venire dagli output reali, non dalla teoria.

### 4. Catturare gli screenshot
- Per ogni concetto scelto, `shot.sh` con i comandi minimi che lo mostrano.
- Nomi file in snake_case descrittivo, stile delle `images/` esistenti (es. `hub_eigrp_neighbors_routes.png`), più `dmvpn_lab_topology.png` / `<lab>_lab_topology.png` per la topologia (il diagramma lo fornisce l'utente o lo si riusa da un lab con topologia identica: non generarlo).
- Per output dipendenti dallo stato (tunnel on-demand, SA, adiacenze), prepara lo stato iniziale con comandi exec via netmiko e verifica che sia quello atteso prima di lanciare `shot.sh`. Attenzione ai timer brevi (es. holdtime NHRP): metti prima/dopo nella stessa finestra invece che in due catture separate.
- **Apri ogni PNG con Read** e controlla: comando visibile in cima, nessuna riga troncata o con `$` (terminal width), nessuna sequenza di escape spuria, stato transitorio indesiderato (es. SA `deleted`). Se qualcosa non va, rifai la cattura.

### 5. Scrivere il README
In inglese, con questa struttura:
1. `# <Titolo lab>` e, se il lab deriva da materiale di corso, `## Credits` (es. ENARSI Hands-On v1.0, Magnetico Associazione Culturale, con link).
2. `## Topology`: paragrafo su cosa fa/aggiunge il lab, immagine della topologia, bullet sui livelli rilevanti, tabella config file / hostname / ruolo / indirizzi / mgmt IP, nota sul mapping `ethN` ↔ `Ethernet0/N` per IOL.
3. Una sezione `##` per concetto, ognuna con: perché serve → blocco di config rilevante (solo le righe utili, commentate `! R1`) → screenshot con alt text descrittivo → interpretazione dell'output con i valori reali.
4. `## Running the lab`: bridge da creare, `clab deploy` / `clab destroy --cleanup`, accesso ai nodi e uso di `lab_tools.py`.

Stile: prosa spiegata, non elenchi telegrafici dove serve un ragionamento; flag/stati/comandi esatti in backtick; link relativi agli altri lab quando un concetto è già spiegato lì.

Se il `README.md` del lab è ancora la copia di un altro lab (succede quando la struttura viene creata copiando quella precedente), riscrivilo per intero.

### 6. Chiusura
Riassumi sezioni e immagini usate, segnala immagini in `images/` non referenziate o riferimenti a immagini mancanti, e chiedi se committare.
