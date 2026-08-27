# containerlab-net-labs

A collection of [containerlab](https://containerlab.dev/) network labs used to explore containerlab itself and to practice networking concepts as CCNP preparation. Containerlab makes it possible to spin up realistic, container-based network topologies (Cisco IOL, Nokia SR Linux, etc.) with a very light footprint compared to traditional VM-based labs (GNS3, EVE-NG), which makes it a convenient tool for quick, repeatable, hands-on practice.

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
