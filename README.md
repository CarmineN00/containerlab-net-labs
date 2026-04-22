# containerlab-net-labs
containerlab deploy -t topology_name --reconfigure
containerlab save -t srl-srl.clab.yml --node-filter node_name --copy ./devices-config
containerlab destroy --cleanup
