---
name: gns3-to-clab
description: Porta su containerlab un lab nato su GNS3 (lezioni ENARSI/magnetico). Dalle config iniziali GNS3 che l'utente incolla in chat e dal PDF dell'esercizio con la topologia, crea <nome_lab>.clab.yml e i file configs/<nodo>.cfg di startup (nodi chiamati come nel disegno della topologia) con il boilerplate standard di containerlab. Usare quando l'utente passa le config iniziali di un nuovo lab e chiede di prepararne il template containerlab.
---

# GNS3 → containerlab: topologia + startup config

Input (li fornisce sempre l'utente):
1. **Config iniziali GNS3** dei router, incollate in chat (solo la parte del lab: hostname, interfacce, eventuali route/protocolli già previsti).
2. **PDF dell'esercizio** nella directory del lab (`<repo>/<nome_lab>/*.pdf`), con disegno della topologia, ruoli dei router e indirizzamento.

Output, nella directory del lab:
- `<nome_lab>.clab.yml`
- `configs/<nodo>.cfg` per ogni router, con `<nodo>` = nome dell'apparato nel disegno della topologia (es. `configs/r1.cfg`, `configs/pe1.cfg`)

Se manca il nome/la directory del lab o le config, chiederli. Il nome del lab è quello della directory e segue il PDF: `rs-labnn-<titolo>`, cioè `rs-` (routing e switching, cioè ENARSI) seguito dal nome del PDF senza il prefisso `ENARSI-Hands-on-v1.0-`, **tutto in minuscolo** (es. `ENARSI-Hands-on-v1.0-LAB05-BGP-Path-selection.pdf` → `rs-lab05-bgp-path-selection/`). Lo stesso nome vale per il file `<nome_lab>.clab.yml` e per il campo `name:`. Se il PDF ha ancora il numero in fondo (`...-TITOLO-LABnn.pdf`), segnalarlo e usare comunque `rs-labnn-titolo`.

## Regole (non negoziabili)

- **Solo lo stato iniziale.** I `.cfg` contengono esattamente le config GNS3 fornite, tradotte. Niente di ciò che i task del PDF chiedono di configurare (l'utente fa i lab per imparare). Se una config GNS3 sembra "sbagliata" apposta (guasto da trovare), lasciarla così.
- **Boilerplate clab completo, mai ridotto.** Ogni `.cfg` parte da `templates/base.cfg` di questa skill, che riproduce la config standard che `clab deploy` genera per `cisco_iol`: VRF `clab-mgmt` (AF v4+v6), Ethernet0/0 con IPv4 **e** IPv6 di mgmt, default route v4 **e** v6 nella VRF, `ip http server` + `ip http secure-server`, utente `admin`, `ip ssh bulk-mode`, line con/aux/vty con `activation-character 13`, `login local`, `transport input ssh`. Non togliere righe "che sembrano inutili": `ip http secure-server` genera il certificato self-signed e quindi la chiave RSA, senza la quale SSH rifiuta la connessione.
- **Link fisici, non sotto-interfacce dot1Q.** Se in GNS3 i collegamenti sono sottointerfacce/VLAN su una sola porta, ogni VLAN diventa un link punto-punto tra porte fisiche. Togliere `encapsulation dot1Q` e spostare indirizzi/comandi sulla porta fisica. Non aggiungere `description` alle interfacce dei link. Se il PDF ha un task che dipende proprio dalla VLAN (es. cambiare il tag dot1Q), segnalarlo all'utente nel riepilogo finale.
- **Segmenti multi-accesso** (3+ router sulla stessa rete, NBMA DMVPN, ecc.) → nodo `kind: bridge` (`br-<lab>`, es. `br-lab09`), da creare sull'host con `scripts/create_bridge.sh <nome>` prima del deploy (lo lancia l'utente, serve sudo).
- **Non lanciare `clab deploy`/`destroy`** (richiedono sudo): dare all'utente i comandi.
- Commit mai: a fine lavoro elencare i file pronti.

## Procedura

### 1. Leggere il PDF
Con Read sul PDF ricavare: numero di router, corrispondenza ruoli ↔ R1..RN (es. "R1 = A (Spoke 1)"), link tra chi e chi, subnet di ogni link, eventuali link usati solo in alcuni scenari, segmenti condivisi. Incrociare con le config: ogni subnet presente su due router = un link.

### 2. Nodi e mappa delle interfacce
- **Hostname**: quello delle config GNS3 (così i prompt corrispondono al PDF).
- **Nome del nodo containerlab = nome dell'apparato nel disegno della topologia del PDF**, in minuscolo e senza trattini (`R1` → `r1`, `PE1 (R3)` → `pe1`, `A (Spoke 1)` → `a`). Se il disegno e l'hostname delle config GNS3 non coincidono, vale il disegno, e la differenza va segnalata all'utente. Niente trattini perché `scripts/lab_tools.py` ricava il nome del nodo dall'ultimo pezzo dopo `-` del nome del container.
- Il file di startup ha lo stesso nome del nodo (`configs/pe1.cfg`): `lab_tools.py export-configs` salva in `configs/<nodo>.cfg`, quindi con nomi diversi l'export non aggiornerebbe il file usato dal deploy.
- **Numero N del router** = posizione nel PDF (R3 = PE1 → N = 3): determina l'IP di management `172.20.20.N0` / `3fff:172:20:20::N0`, indipendentemente dal nome.
- Interfacce IOL: `Ethernet0/0` è riservata al management. Le porte dati sono `Ethernet0/1`–`0/3`, poi `Ethernet1/0`–`1/3`, ecc. (4 per slot).
- Le interfacce GNS3 (`GigabitEthernet0/0`, `Ethernet0/0.17`, …) si mappano sulle porte dati in ordine, router per router. Mostrare la mappa all'utente in una tabella link → porte (vedi riepilogo).

### 3. `<nome_lab>.clab.yml`
Stile dei lab esistenti:

```yaml
name: <nome_lab>
topology:
  defaults:
    kind: cisco_iol
    image: vrnetlab/cisco_iol:17.18.02

  nodes:
    r1: { mgmt-ipv4: 172.20.20.10, mgmt-ipv6: 3fff:172:20:20::10, startup-config: configs/r1.cfg }
    pe1: { mgmt-ipv4: 172.20.20.30, mgmt-ipv6: 3fff:172:20:20::30, startup-config: configs/pe1.cfg }
    # <nodo>: 172.20.20.N0 / 3fff:172:20:20::N0 (N = posizione nel PDF)

  links:
    - endpoints: ["r1:Ethernet0/1", "pe1:Ethernet0/1"]
```

`mgmt-ipv6` va fissato: senza, Docker assegna l'IPv6 in modo dinamico e non coinciderebbe con quello scritto nel `.cfg`. Niente commenti superflui nel file.

### 4. `configs/<nodo>.cfg`
Per ogni router: copiare `templates/base.cfg`, sostituire `{{HOSTNAME}}`, `{{N}}` (posizione nel PDF: R3 = PE1 → `30`, `::30`) e `{{LAB_CONFIG}}` con la config GNS3 tradotta:
- interfacce del lab (Loopback e porte dati della mappa), ognuna chiusa da `!`;
- le porte dati non usate dello slot 0 (`Ethernet0/1`–`0/3`) come `no ip address` + `shutdown`;
- eventuali comandi globali del lab presenti nelle config GNS3 (route statiche, processi di routing già previsti, ecc.).

Scartare dalle config GNS3 ciò che il template copre già (`hostname`, `ipv6 unicast-routing`, `ip cef`, …) o che è specifico di GNS3 (management/tftp di GNS3, `configure replace`, line/aaa diversi).

### 5. Verifica dopo il deploy
Dare all'utente:

```bash
cd /home/carnapolit/containerlab-net-labs/<nome_lab>
```

```bash
sudo clab deploy --reconfigure
```

Quando conferma che il lab è su, collegarsi io in SSH (netmiko dal `venv/` del repo, utente/password `admin`/`admin`, mgmt `172.20.20.N0`) con uno script nello scratchpad e controllare per ogni router `show ip interface brief` e `show ipv6 interface brief` contro le config GNS3; se il PDF ha un primo task di ping di verifica, eseguirlo. Riportare una tabella router → indirizzi verificati, senza anticipare le risposte alle domande dei task (es. "quali interfacce hanno un link-local").

### 6. Riepilogo all'utente
- tabella link (subnet/ex VLAN) → porte per router;
- eventuali nomi del disegno della topologia diversi dagli hostname delle config GNS3;
- eventuali task del PDF che con i link fisici non si possono riprodurre così come sono;
- eventuale bridge da creare prima del deploy;
- comandi di deploy;
- file pronti per il commit.
