# OSPF Lab

A [containerlab](https://containerlab.dev/) topology with 7 Cisco IOL routers running single-process OSPFv2 (`router ospf 1`) across 3 areas, used to practice multi-area design, DR/BDR election on a shared segment, the point-to-point network type, and inter-area (IA) route propagation through ABRs.

## Topology

![OSPF lab topology](images/ospf_lab_topology.png)

- **Area 0 (backbone)**: R1 — R2 — R3, chained by point-to-point links.
- **Area 1 (multi-access)**: R1, R4, R7 share a single broadcast segment via a containerlab bridge (`ospf-br-area1`), triggering DR/BDR election.
- **Area 2**: R3 — R5 — R6, chained by point-to-point links. The topology reserves this area for an NSSA demo (see [note below](#area-2)), though no `area 2 nssa` command has been applied yet — it currently runs as a plain OSPF area.
- **R1** and **R3** are the two Area Border Routers (ABRs), each sitting between Area 0 and one of the other areas.

| Config file | Hostname | Loopback0 (RID) | Area(s) | Mgmt IP |
|---|---|---|---|---|
| `configs/r1.cfg` | r1 | 1.1.1.1 | 0, 1 (ABR) | 172.20.20.10 |
| `configs/r2.cfg` | R2 | 2.2.2.2 | 0 | 172.20.20.20 |
| `configs/r3.cfg` | R3 | 3.3.3.3 | 0, 2 (ABR) | 172.20.20.30 |
| `configs/r4.cfg` | R4 | 4.4.4.4 | 1 | 172.20.20.40 |
| `configs/r5.cfg` | R5 | 5.5.5.5 | 2 | 172.20.20.50 |
| `configs/r6.cfg` | R6 | 6.6.6.6 | 2 | 172.20.20.60 |
| `configs/r7.cfg` | R7 | 7.7.7.7 | 1 | 172.20.20.70 |

Every node advertises its Loopback0 into OSPF, so the router-id matches the loopback address shown above — confirmed with `show ip ospf` on r1:

![Router-ID taken from Loopback0](images/RID_loopback.png)

Before touching OSPF at all, base L3 addressing was verified on all 7 nodes with `show ip interface brief`:

![Base interface addressing on all 7 routers](images/basic_config.png)

## Area 0 — backbone

R1, R2 and R3 form the backbone over three /30 point-to-point links:

| Link | Subnet |
|---|---|
| R1 Et0/2 ↔ R2 Et0/1 | 10.0.12.0/30 |
| R2 Et0/2 ↔ R3 Et0/1 | 10.0.23.0/30 |

Base config (R2, a pure Area 0 router with no ABR role):

```
! R2
interface Loopback0
 ip address 2.2.2.2 255.255.255.255
interface Ethernet0/1
 ip address 10.0.12.2 255.255.255.252
 ip ospf network point-to-point
interface Ethernet0/2
 ip address 10.0.23.1 255.255.255.252
 ip ospf network point-to-point
!
router ospf 1
 network 2.2.2.2 0.0.0.0 area 0
 network 10.0.12.0 0.0.0.3 area 0
 network 10.0.23.0 0.0.0.3 area 0
```

## Area 1 — multi-access segment and DR/BDR election

R1, R4 and R7 all connect to `ospf-br-area1`, a shared Linux bridge acting as a single broadcast (multi-access) segment on 10.0.1.0/24 — the one part of the topology where OSPF's default broadcast network type applies and a DR/BDR election is actually needed:

```
! R1 (also ABR for area 0/1)
interface Ethernet0/1
 ip address 10.0.1.1 255.255.255.0
!
router ospf 1
 network 1.1.1.1 0.0.0.0 area 0
 network 10.0.1.0 0.0.0.255 area 1
 network 10.0.12.0 0.0.0.3 area 0
```

R1 won the election and became DR, R4 became BDR, and R7 stayed DROTHER — note this is a consequence of **arrival order**, not router-id (R7's RID 7.7.7.7 is numerically highest but it came up after R1 had already declared itself DR):

![R7 neighbor table on the multi-access segment: FULL/DR with R1, FULL/BDR with R4](images/scenario_where_dr-bdr_election_is_needed.png)

Right after OSPF was first enabled everywhere (still with the default broadcast network type on every link, before point-to-point was applied to the Area 0/Area 2 links below), `show ip ospf interface brief` was captured on all 7 routers just to confirm the process was up and adjacencies had formed:

![show ip ospf interface brief across all 7 routers, right after enabling OSPF](images/ospf_config.png)

## Area 2

R3 — R5 — R6 form a second point-to-point chain off R3, on 10.0.35.0/30 and 10.0.56.0/30. The topology comment marks this area as an NSSA candidate, but the configs only place these routers/links in `area 2` — no `nssa` keyword is configured yet, so it currently behaves as a standard (non-stub) area.

## Point-to-point network type

Every Ethernet link that is logically a point-to-point connection (all Area 0 and Area 2 links) has `ip ospf network point-to-point` applied instead of being left as the OSPF default (broadcast), which skips DR/BDR election entirely on those segments — only the genuinely multi-access Area 1 segment still needs one. The effect is shown live on R1's Et0/2 (its link to R2): before the change the interface elects a DR/BDR like any broadcast segment (R1 itself DR, neighbor 2.2.2.2 FULL/BDR); after `ip ospf network point-to-point` is applied, the interface state flips to `P2P` and the neighbor relationship drops the DR/BDR role entirely (`FULL/-`):

```
r1(config)#interface Ethernet0/2
r1(config-if)# ip ospf network point-to-point
```

![R1 Et0/2 before/after switching to point-to-point network type](images/p2p_ospf_linktype_effect.png)

Applying this consistently across every Area 0/Area 2 link, `show ip ospf interface brief` on all 7 routers confirms the expected final states — `LOOP` on loopbacks, `P2P` (no DR/BDR) on every backbone/area 2 link, and DR/BDR/DROTHER only on the Area 1 broadcast segment (a later, simultaneous re-election here also handed the DR role to R7, the highest router-id, instead of R1):

![show ip ospf interface brief across all 7 routers after applying point-to-point](images/br-p2p_difference.png)

## ABR behavior and inter-area routes

`show ip protocols` on R1 confirms it is an area border router serving 2 areas (0 and 1):

![R1 show ip protocols — area border router, 2 areas](images/r1_ospf.png)

Because R3 is the ABR for Area 2, prefixes originating there (5.5.5.5, 6.6.6.6, 10.0.35.0/30, 10.0.56.0/30) show up on R1 as `O IA` (inter-area) routes via R3, while Area 0-local prefixes (2.2.2.2, 3.3.3.3) show up as plain `O`:

![R1 OSPF routing table — O vs O IA routes](images/ospf_routes.png)

## Running the lab

```bash
# from scripts/, creates the ospf-br-area1 bridge if missing, then deploys
./scripts/deploy.sh

# or directly
sudo containerlab deploy -t cisco-iol.clab.yml
sudo containerlab destroy -t cisco-iol.clab.yml --cleanup
```

Nodes `r1`–`r7` are reachable via containerlab console/exec or SSH on 172.20.20.10–70 (user `admin`). `scripts/open_sessions.sh` opens an SSH session to all 7 routers at once, each in its own Windows Terminal tab (run from WSL).
