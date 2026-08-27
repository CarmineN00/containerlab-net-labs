import argparse
import json
import subprocess
from pathlib import Path
from netmiko import ConnectHandler

def get_lab_nodes(topo_file):
    result = subprocess.run(
        ["sudo", "clab", "inspect", "-t", topo_file, "--format", "json"],
        capture_output=True, text=True, check=True,
    )
    data = json.loads(result.stdout)
    containers = next((v for v in data.values() if isinstance(v, list)), [])

    nodes = []
    for c in containers:
        full_name = c["name"]
        short_name = full_name.split("-")[-1]
        mgmt_ip = c["ipv4_address"].split("/")[0]
        nodes.append({"name": short_name, "kind": c["kind"], "mgmt_ip": mgmt_ip})
    return nodes

def export_config(mgmt_ip, username, password):
    device = {
        "device_type": "cisco_ios",
        "host": mgmt_ip,
        "username": username,
        "password": password,
    }
    with ConnectHandler(**device) as conn:
        conn.send_command("terminal length 0")
        return conn.send_command("show running-config", read_timeout=30)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--topo", required=True)
    parser.add_argument("--outdir", default="configs")
    parser.add_argument("--username", default="admin")
    parser.add_argument("--password", default="admin")
    args = parser.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    nodes = get_lab_nodes(args.topo)

    for node in nodes:
        if node["kind"] != "cisco_iol":
            continue
        config = export_config(node["mgmt_ip"], args.username, args.password)
        out_file = outdir / f"{node['name']}.cfg"
        out_file.write_text(config + "\n")
        print(f"[{node['name']}] salvato in {out_file}")

if __name__ == "__main__":
    main()
