import argparse
import argparse
import json
import re
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


def clean_config(config):
    # Rimuove i blocchi crypto pki self-signed (certificato orfano
    # se riusato in un nuovo container/NVRAM)
    config = re.sub(r"crypto pki trustpoint TP-self-signed.*?\n!\n", "", config, flags=re.DOTALL)
    config = re.sub(r"crypto pki certificate chain TP-self-signed.*?quit\n", "", config, flags=re.DOTALL)
    return config


def natural_key(node):
    match = re.search(r"(\d+)$", node["name"])
    return int(match.group(1)) if match else 0


def cmd_export(args):
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    nodes = get_lab_nodes(args.topo)
    for node in nodes:
        if node["kind"] != "cisco_iol":
            continue
        config = export_config(node["mgmt_ip"], args.username, args.password)
        config = clean_config(config)
        out_file = outdir / f"{node['name']}.cfg"
        out_file.write_text(config + "\n")
        print(f"[{node['name']}] salvato in {out_file}")


def cmd_open_sessions(args):
    nodes = get_lab_nodes(args.topo)
    routers = sorted(
        (n for n in nodes if n["kind"] == "cisco_iol"),
        key=natural_key,
    )
    if not routers:
        print(f"Nessun router 'cisco_iol' trovato nella topologia '{args.topo}'.")
        return

    wt_args = ["wt.exe", "-w", "0"]
    for i, node in enumerate(routers):
        if i > 0:
            wt_args.append(";")
        wt_args += [
            "new-tab", "--title", node["name"].upper(),
            "wsl.exe", "sshpass", "-p", args.password,
            "ssh", "-o", "StrictHostKeyChecking=no",
            f"{args.username}@{node['mgmt_ip']}",
        ]
        print(f"[{node['name']}] tab -> {node['mgmt_ip']}")

    subprocess.run(wt_args)


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    export_parser = subparsers.add_parser("export-configs", help="Esporta le running-config dei nodi cisco_iol")
    export_parser.add_argument("--topo", required=True)
    export_parser.add_argument("--outdir", default="configs")
    export_parser.add_argument("--username", default="admin")
    export_parser.add_argument("--password", default="admin")
    export_parser.set_defaults(func=cmd_export)

    sessions_parser = subparsers.add_parser("open-sessions", help="Apre una tab Windows Terminal per ogni nodo cisco_iol")
    sessions_parser.add_argument("--topo", required=True)
    sessions_parser.add_argument("--username", default="admin")
    sessions_parser.add_argument("--password", default="admin")
    sessions_parser.set_defaults(func=cmd_open_sessions)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
