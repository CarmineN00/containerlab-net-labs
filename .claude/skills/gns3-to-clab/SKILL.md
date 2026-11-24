---
name: gns3-to-clab
description: Porta su containerlab un lab nato su GNS3 (lezioni ENARSI/magnetico). Dalle config iniziali GNS3 che l'utente incolla in chat e dal PDF dell'esercizio con la topologia, crea <nome_lab>.clab.yml e i file configs/rX.cfg di startup con il boilerplate standard di containerlab. Usare quando l'utente passa le config iniziali di un nuovo lab e chiede di prepararne il template containerlab.
---

# GNS3 → containerlab: topologia + startup config

Input (li fornisce sempre l'utente):
1. **Config iniziali GNS3** dei router, incollate in chat (solo la parte del lab: hostname, interfacce, eventuali route/protocolli già previsti).
2. **PDF dell'esercizio** nella directory del lab (`<repo>/<nome_lab>/*.pdf`), con disegno della topologia, ruoli dei router e indirizzamento.

Output, nella directory del lab:
- `<nome_lab>.clab.yml`
- `configs/r1.cfg` … `configs/rN.cfg`

Se manca il nome/la directory del lab o le config, chiederli. Il nome del lab è quello della directory.

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
- Nodi containerlab sempre `r1`…`rN` (ordine del PDF), anche se gli hostname sono A/B/C/D.
- **Hostname**: quello delle config GNS3 (così i prompt corrispondono al PDF).
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
    r2: { mgmt-ipv4: 172.20.20.20, mgmt-ipv6: 3fff:172:20:20::20, startup-config: configs/r2.cfg }
    # rN: 172.20.20.N0 / 3fff:172:20:20::N0

  links:
    - endpoints: ["r1:Ethernet0/1", "r2:Ethernet0/1"]
```

`mgmt-ipv6` va fissato: senza, Docker assegna l'IPv6 in modo dinamico e non coinciderebbe con quello scritto nel `.cfg`. Niente commenti superflui nel file.

### 4. `configs/rX.cfg`
Per ogni router: copiare `templates/base.cfg`, sostituire `{{HOSTNAME}}`, `{{N}}` (numero del router: r3 → `30`, `::30`) e `{{LAB_CONFIG}}` con la config GNS3 tradotta:
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
- eventuali task del PDF che con i link fisici non si possono riprodurre così come sono;
- eventuale bridge da creare prima del deploy;
- comandi di deploy;
- file pronti per il commit.
