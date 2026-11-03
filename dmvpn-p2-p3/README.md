# DMVPN Phase 1 Lab

## Credits

This lab is based on "LAB01 - DMVPN" from the ENARSI Hands-On v1.0 course material
by [Magnetico Associazione Culturale](https://www.magnetico.cloud/).

## Topology

A [containerlab](https://containerlab.dev/) topology with 4 Cisco IOL routers building a **DMVPN Phase 1** hub-and-spoke overlay: one hub (R1) with a multipoint GRE tunnel acting as NHRP server, and three spokes (R2–R4) with classic point-to-point GRE tunnels pointed at the hub. EIGRP (AS 90) runs over the overlay to exchange the LAN prefixes (simulated by loopbacks), with the spokes configured as stubs. The lab is used to practice NHRP registration, the hub vs. spoke view of the DMVPN cloud, EIGRP split-horizon over an mGRE interface, and the Phase 1 behaviour where all spoke-to-spoke traffic goes through the hub.

![DMVPN Phase 1 lab topology](images/dmvpn_lab_topology.png)

- **Underlay (NBMA)**: all four routers share a single segment, 10.1.234.0/24, through a containerlab bridge (`br-nbma`). It plays the role of the transport network (e.g. the Internet or an MPLS cloud): the tunnel endpoints (NBMA addresses) live here.
- **Overlay (DMVPN)**: the tunnel network 192.168.234.0/24. R1 is the hub and Next Hop Server (NHS); R2, R3 and R4 are spokes.
- **Routing**: EIGRP AS 90 runs only on the tunnel and loopback interfaces. Loopback0 on each router stands in for the site LAN (192.168.X.0/24).

| Config file | Hostname | Role | Et0/1 (NBMA) | Tunnel0 | Loopback0 | Mgmt IP |
|---|---|---|---|---|---|---|
| `configs/r1.cfg` | R1 | Hub / NHS | 10.1.234.1/24 | 192.168.234.1/24 (mGRE) | 192.168.1.1/24 | 172.20.20.10 |
| `configs/r2.cfg` | R2 | Spoke | 10.1.234.2/24 | 192.168.234.2/24 (GRE p2p) | 192.168.2.1/24 | 172.20.20.20 |
| `configs/r3.cfg` | R3 | Spoke | 10.1.234.3/24 | 192.168.234.3/24 (GRE p2p) | 192.168.3.1/24 | 172.20.20.30 |
| `configs/r4.cfg` | R4 | Spoke | 10.1.234.4/24 | 192.168.234.4/24 (GRE p2p) | 192.168.4.1/24 | 172.20.20.40 |

containerlab's `ethN` maps to IOL's `Ethernet0/N`; `Ethernet0/0` is always the management interface (in the `clab-mgmt` VRF).

## Hub configuration — multipoint GRE

The hub has a single tunnel interface that terminates every spoke. There's no `tunnel destination`: with `tunnel mode gre multipoint` the destination of each GRE packet is looked up in the NHRP table, which the hub fills dynamically as the spokes register. All routers in the cloud must agree on the NHRP `network-id`, the NHRP authentication string and the `tunnel key`:

```
! R1
interface Tunnel0
 ip address 192.168.234.1 255.255.255.0
 no ip redirects
 no ip split-horizon eigrp 90
 ip nhrp authentication enarsi
 ip nhrp network-id 100
 ip nhrp holdtime 15
 tunnel source Ethernet0/1
 tunnel mode gre multipoint
 tunnel key 100
```

`show interfaces Tunnel0` confirms the transport is `multi-GRE/IP`, sourced from the NBMA address 10.1.234.1:

![R1 Tunnel0 configuration and multi-GRE/IP transport](images/hub_tunnel_config.png)

(`no ip split-horizon eigrp 90` is explained in [EIGRP over the hub-and-spoke overlay](#eigrp-over-the-hub-and-spoke-overlay) below.)

## Spoke configuration — point-to-point GRE

What makes this **Phase 1** is the spokes: each one uses a regular point-to-point GRE tunnel with a static `tunnel destination` set to the hub's NBMA address, so a spoke can only ever send traffic into the hub. `ip nhrp nhs` points at the hub's tunnel address, so the spoke registers its tunnel-to-NBMA mapping with it:

```
! R2 (R3 and R4 are identical apart from the addresses)
interface Tunnel0
 ip address 192.168.234.2 255.255.255.0
 ip nhrp authentication enarsi
 ip nhrp network-id 100
 ip nhrp holdtime 15
 ip nhrp nhs 192.168.234.1
 tunnel source Ethernet0/1
 tunnel destination 10.1.234.1
 tunnel key 100
```

The transport here is plain `GRE/IP`, with a fixed destination of 10.1.234.1:

![R2 Tunnel0 configuration and GRE/IP point-to-point transport](images/spoke_tunnel_config.png)

## NHRP registration

Each spoke sends an NHRP Registration Request to the NHS telling it "tunnel address 192.168.234.X is reachable at NBMA address 10.1.234.X". With `ip nhrp holdtime 15`, the registrations are valid for 15 seconds and the spokes refresh them periodically (by default every holdtime/3, so every 5 seconds). A spoke that stops registering ages out of the hub's table quickly.

On the hub, `show dmvpn` reports `Type:Hub` with 3 NHRP peers, all **dynamic** (`D`): none of them is configured on R1, they were all learned from the registrations. `show ip nhrp` shows the same entries with the `registered` flag and the `expire` timer that keeps going back to ~15 seconds:

![R1 show dmvpn (3 dynamic peers) and show ip nhrp (registered entries)](images/hub_dmvpn_nhrp.png)

The same registrations also create the **multicast mappings** on the hub (`show ip nhrp multicast` lists 10.1.234.2/.3/.4 as `dynamic`). That's what lets the EIGRP hellos (multicast to 224.0.0.10) get replicated as unicast GRE packets to every registered spoke. There's no need for `ip nhrp map multicast dynamic`, because IOS-XE adds these entries automatically when a spoke registers.

On a spoke, `show dmvpn` is empty: a point-to-point GRE tunnel doesn't need NHRP to resolve the destination, so there are no NHRP peer entries to show. The relationship with the hub is visible with `show ip nhrp nhs detail` instead: 192.168.234.1 is in state **RE** (Expecting replies / Responding), and the request/reply counters keep increasing with every registration refresh:

![R2: empty show dmvpn, and NHS 192.168.234.1 in state RE](images/spoke_nhrp_registration.png)

## EIGRP over the hub-and-spoke overlay

EIGRP is enabled on the tunnel and on the loopback of every router (classic mode, AS 90). The spokes are configured as **stubs** (`eigrp stub connected`): they advertise only their connected LAN and are never queried by the hub. That's the right choice for branch routers that should never be used as transit.

```
! R1
router eigrp 90
 network 192.168.1.1 0.0.0.0
 network 192.168.234.1 0.0.0.0
!
! R2 (R3 and R4 the same, with their own addresses)
router eigrp 90
 network 192.168.2.1 0.0.0.0
 network 192.168.234.2 0.0.0.0
 eigrp stub connected
```

The hub forms 3 adjacencies, all on Tu0, and learns each spoke's LAN directly from that spoke (`show ip eigrp neighbors detail` also reports each of them as `Stub Peer Advertising (CONNECTED) Routes`):

![R1: three EIGRP neighbors on Tu0 and the three spoke LANs](images/hub_eigrp_neighbors_routes.png)

A spoke only peers with the hub, since that's the only endpoint its p2p tunnel can reach. Spokes never form adjacencies with each other. Still, R2 learns the LANs of R3 and R4 too, all with the hub (192.168.234.1) as next hop and a higher metric than the hub's own LAN, because they are one extra hop away:

![R2: a single EIGRP neighbor (the hub) and all remote LANs via 192.168.234.1](images/spoke_eigrp_routes.png)

### Why split-horizon must be disabled on the hub

For the hub, all spokes sit behind the **same interface**, Tunnel0. Split-horizon forbids advertising a route out of the interface it was learned on, so by default R1 would learn 192.168.3.0/24 from R3 on Tu0 and then refuse to advertise it back out of Tu0 to R2 and R4. Temporarily re-enabling it on the hub proves it: once the adjacencies come back up, R2 only knows the hub's own LAN, 192.168.1.0/24, and the other spokes have disappeared:

```
! R1
interface Tunnel0
 ip split-horizon eigrp 90
```

![R2 routing table with split-horizon enabled on the hub: only 192.168.1.0/24](images/spoke_routes_with_split-horizon_on_hub.png)

That's why the hub keeps `no ip split-horizon eigrp 90` on Tunnel0. With it removed again, R2 relearns 192.168.3.0/24 and 192.168.4.0/24, as in the previous screenshot.

## Spoke-to-spoke traffic in Phase 1

In Phase 1, the spokes have no way to build a direct tunnel to each other. Their GRE tunnel has a fixed destination (the hub), and the routes to the other spokes point at the hub anyway. A traceroute from R2's LAN to R3's LAN shows the two hops: first the hub (192.168.234.1), then R3 (192.168.234.3). Every packet between two branches has to go through the hub, entering and leaving on the same Tunnel0, which is exactly the limitation that Phase 2 (spoke-to-spoke tunnels with mGRE on the spokes) and Phase 3 (NHRP redirect/shortcut) address:

![Traceroute from R2 to R3's LAN going through the hub](images/spoke-to-spoke_via_hub.png)

## Running the lab

```bash
# create the NBMA bridge if missing (it's a host bridge, so it must exist before deploy)
./scripts/create_bridge.sh br-nbma

# deploy / destroy (from the dmvpn-p1 directory)
clab deploy
clab destroy --cleanup
```

Nodes `r1`–`r4` are reachable via containerlab console/exec or SSH on 172.20.20.10–40 (user `admin`). `scripts/lab_tools.py` can export the running configs back into `configs/` (`export-configs`) and open an SSH session to every router at once (`open-sessions`).
