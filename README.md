# containerlab-net-labs

A collection of [containerlab](https://containerlab.dev/) network labs used to explore containerlab itself and to practice networking concepts as CCNP preparation. Containerlab makes it possible to spin up realistic, container-based network topologies (Cisco IOL, Nokia SR Linux, etc.) with a very light footprint compared to traditional VM-based labs (GNS3, EVE-NG), which makes it a convenient tool for quick, repeatable, hands-on practice.

## Lab status

Labs from the ENARSI and ENCOR Hands-On v1.0 courses by [Magnetico Associazione Culturale](https://www.magnetico.cloud/). ENARSI labs live in `rs-labnn-<title>/` directories.

✅ done (configured and documented) · 🧩 template ready (initial configs in place, exercise not done yet) · ⬜ to do (not in the repo yet)

### ENARSI (routing and switching)

| # | Lab | Directory | Status |
|---|---|---|---|
| LAB01 | DMVPN | [`rs-lab01-dmvpn`](rs-lab01-dmvpn/) | ✅ done |
| LAB02 | DMVPN phase 2 and 3 | [`rs-lab02-dmvpn-fase-2-e-3`](rs-lab02-dmvpn-fase-2-e-3/) | ✅ done |
| LAB03 | DMVPN tunnel protection | [`rs-lab03-dmvpn-tunnel-protection`](rs-lab03-dmvpn-tunnel-protection/) | ✅ done |
| LAB04 | VRF-Lite | [`rs-lab04-vrf-lite`](rs-lab04-vrf-lite/) | ✅ done |
| LAB05 | BGP path selection | [`rs-lab05-bgp-path-selection`](rs-lab05-bgp-path-selection/) | ✅ done |
| LAB06 | CoPP | [`rs-lab06-copp`](rs-lab06-copp/) | ✅ done |
| LAB07 | OSPF | [`rs-lab07-ospf`](rs-lab07-ospf/) | ✅ done |
| LAB08 | PBR and route redistribution | [`rs-lab08-pbr-route-redistribution`](rs-lab08-pbr-route-redistribution/) | ✅ done |
| LAB09 | uRPF, IP SLA, NetFlow, Archive | [`rs-lab09-rpf-ip-sla-netflow-archive`](rs-lab09-rpf-ip-sla-netflow-archive/) | ✅ done |
| LAB10 | OSPFv3 address families | [`rs-lab10-ospfv3-af`](rs-lab10-ospfv3-af/) | ✅ done |
| LAB11 | BGP TTL control, loopback peering and IPv6 | [`rs-lab11-bgp-ttl-peering-ipv6`](rs-lab11-bgp-ttl-peering-ipv6/) | 🧩 template ready |
| LAB12 | MPLS LDP and L3VPN | [`rs-lab12-mpls-ldp-l3vpn`](rs-lab12-mpls-ldp-l3vpn/) | 🧩 template ready |

### ENCOR

| # | Lab | Directory | Status |
|---|---|---|---|
| LAB01 | EIGRP and OSPF | — | ⬜ to do |
| LAB02 | OSPF adjacencies | — | ⬜ to do |
| LAB03 | OSPF multi-area | — | ⬜ to do |
| LAB04 | OSPFv3 | — | ⬜ to do |
| LAB05 | eBGP | — | ⬜ to do |
| LAB06 | BGP best path | — | ⬜ to do |
| LAB07 | PBR | — | ⬜ to do |
| LAB08 | VRF-Lite | — | ⬜ to do |
| LAB09 | GRE with VRF | — | ⬜ to do |
| LAB10 | IPsec crypto map | — | ⬜ to do |
| LAB11 | GRE over IPsec and VTI | — | ⬜ to do |
| LAB12 | LISP | — | ⬜ to do |
| LAB13 | HSRP | — | ⬜ to do |
| LAB14 | VRRP | — | ⬜ to do |
| LAB15 | GLBP | — | ⬜ to do |
| LAB16 | NAT and PAT | — | ⬜ to do |
| LAB17 | NTP | — | ⬜ to do |
| LAB18 | Multicast PIM-SM | — | ⬜ to do |
| LAB19 | Multicast SSM, Bidir-PIM and MSDP | — | ⬜ to do |
| LAB20 | Diagnostics: Syslog and SNMP | — | ⬜ to do |
| LAB21 | IP SLA and object tracking | — | ⬜ to do |
| LAB22 | Flexible NetFlow | — | ⬜ to do |
| LAB23 | SSH access and AAA | — | ⬜ to do |
| LAB24 | ACL and CoPP | — | ⬜ to do |
| LAB25 | QoS with MQC | — | ⬜ to do |
| LAB26 | EEM | — | ⬜ to do |
| LAB27 | Programmability: RESTCONF and NETCONF | — | ⬜ to do |

## Common containerlab commands

```bash
# Deploy a topology
containerlab deploy -t topology_name.clab.yml

# Redeploy, reapplying startup-configs
containerlab deploy -t topology_name.clab.yml --reconfigure

# List running labs
containerlab inspect

# List running labs with topology details
containerlab inspect -t topology_name.clab.yml --details

# Open a shell/console on a node
containerlab exec -t topology_name.clab.yml --label clab-node-name=node_name --cmd "bash"

# Destroy a lab (and remove its lab directory)
containerlab destroy -t topology_name.clab.yml --cleanup

# Graph the topology (generates an HTML/mermaid graph)
containerlab graph -t topology_name.clab.yml
```

## Repo layout

Each lab directory typically contains:

- `*.clab.yml` — the containerlab topology definition.
- `configs/` — per-node startup configs.
- `scripts/` — helper scripts.
- `images/` — screenshots showing the results/outcomes of what was done in the lab (e.g. `show` command output, verifying a configuration change), referenced in the lab's README.

## Lab tools
python3 lab_tools.py export-configs --topo topo_name.clab.yml

python3 lab_tools.py open-sessions --topo topo_name.clab.yml
