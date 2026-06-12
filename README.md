# containerlab-net-labs
containerlab deploy -t topology_name --reconfigure

containerlab save -t srl-srl.clab.yml --node-filter node_name --copy ./devices-config

sshpass -p "password" ssh -o StrictHostKeyChecking=no user@node_ip "show startup-config" > ./devices-config/iol-1.cfg (--copy not supported for cisco iol)

containerlab destroy --cleanup

