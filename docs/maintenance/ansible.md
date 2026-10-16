# Ansible — L4D2 Zone server setup

🌐 **English** | [Português](ansible.pt.md) | [Español](ansible.es.md)

One-shot playbook ([`ansible/setup-server.yml`](../../ansible/setup-server.yml)) to bring up a fresh Ubuntu server for L4D2. It always runs
the **whole** thing (provision + deploy + crontab). It is meant to be run
**once**, when creating the server — any later change goes through the Azure
DevOps pipeline ([`azure-pipelines.yml`](../../azure-pipelines.yml)), not this playbook.

> ⚠️ **Not tested yet.** This playbook was written from the pipeline
> definitions but has not been run against a real server. Review it and do a
> first run against a disposable/test machine before trusting it in production.

## What it does

Every run does all of the following, in order:

**1. Provisioning** — mirrors the server creation script:
- enables the i386 architecture, runs `apt update` and a full upgrade (`dist`)
- installs `screen`, `libc6:i386`, `lib32z1`, `wget`, `tar`, `dos2unix`
- downloads and extracts SteamCMD into `/home/steam`
- runs `app_update 222860 validate` for the **linux** platform, installing the game into `/home/steam/l4d2`

**2. Deploy** — same destinations as the pipelines. Before copying from each local repository, it checks that the repository is there (`addons/` in the main repo, `whitelist.cfg` in the check repo, `materials/` in the assets repo) and stops with a message telling which path to pass if it is missing:

| Source (local)                                        | Destination (server)                        |
|-------------------------------------------------------|---------------------------------------------|
| `addons/ cfg/ bash/ scripts/` (main repo)             | `/home/steam/l4d2/left4dead2/<same folder>` |
| `host.txt`, `motd.txt` (main repo)                    | `/home/steam/l4d2/left4dead2/`              |
| `bash/*.sh`                                           | `dos2unix` + `chmod +x` applied             |
| `sound/` (`l4d2-zone-server-check` repo)              | `/home/steam/l4d2/left4dead2/sound/`        |
| `whitelist.cfg` (`l4d2-zone-server-check` repo)       | `/home/steam/l4d2/left4dead2/`              |
| `models/ materials/` (`l4d2-zone-server-assets` repo) | `/home/steam/l4d2/left4dead2/<same folder>` |

> `assets/` and `fastdl/` (assets repo) are **not** copied: in the pipelines they
> are uploaded to Azure Blob Storage, not to the server.

**3. Crontab** — adds a root `@reboot` entry (named `l4d2-bootstrap`) that runs the server bootstrap on
every boot, after a 5-second delay:

```cron
@reboot sleep 5 && /home/steam/l4d2/left4dead2/bash/bootstrap.sh
```

[`bootstrap.sh`](../../bash/bootstrap.sh) sets the time zone to `America/Sao_Paulo`, applies the firewall rules ([`iptables.sh`](../../bash/iptables.sh)) and starts the game server with [`start.sh`](../../bash/start.sh) on port `27015` (map `c2m1_highway`).

> Do not run `bootstrap.sh` or `iptables.sh` by hand over SSH: they rebuild the
> firewall and can lock you out of the server. To restart only the game, use
> [`stop.sh`](../../bash/stop.sh) `<port>` and `start.sh` `<port> <map>`.

## Prerequisites (on the machine running Ansible)

- **Ansible** and **sshpass** (required for password-based login).
- On **Windows**, run it inside **WSL** (Ansible does not run natively on
  Windows). Windows paths like `D:\...` become `/mnt/d/...` inside WSL.

```bash
sudo apt update && sudo apt install -y ansible sshpass
```

## Configuration

[`ansible.cfg`](../../ansible/ansible.cfg) points Ansible to `inventory.ini`, turns off SSH host key checking and enables pipelining. Edit [`inventory.ini`](../../ansible/inventory.ini) with the server address, user and password:

```ini
[l4d2]
zone-server ansible_host=YOUR_SERVER_ADDRESS

[l4d2:vars]
ansible_user=YOUR_USER
ansible_password=YOUR_PASSWORD
ansible_become_password=YOUR_PASSWORD
ansible_python_interpreter=/usr/bin/python3
```

> Do not commit real credentials. Prefer passing them on the command line (see
> below) or using [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html).

## Usage

From the `ansible/` folder (so `ansible.cfg` is picked up) — there is a single command, it always runs the full
setup:

```bash
ansible-playbook setup-server.yml
```

> If Ansible warns that it is ignoring `ansible.cfg` because the directory is
> world writable (common on `/mnt/...` inside WSL), point to it explicitly:
> `ANSIBLE_CONFIG=./ansible.cfg ansible-playbook setup-server.yml`.

### Passing parameters on the command line

Everything can be overridden with `-e`, without editing any file. Keeping
credentials out of the repo, this is the recommended way to run it:

```bash
ansible-playbook setup-server.yml \
  -e "ansible_host=YOUR_SERVER_ADDRESS ansible_user=YOUR_USER ansible_password=YOUR_PASSWORD ansible_become_password=YOUR_PASSWORD"
```

### Current paths on this machine (Windows + WSL)

The repositories live here on this PC:

| Repo                        | Windows path                              | WSL path                                          |
|-----------------------------|-------------------------------------------|---------------------------------------------------|
| `l4d2-zone-server` (main)   | `D:\Pessoal\L4D2\l4d2-zone-server`        | `/mnt/d/Pessoal/L4D2/l4d2-zone-server`            |
| `l4d2-zone-server-check`    | `D:\Pessoal\L4D2\l4d2-zone-server-check`  | `/mnt/d/Pessoal/L4D2/l4d2-zone-server-check`      |
| `l4d2-zone-server-assets`   | `D:\Pessoal\L4D2\l4d2-zone-server-assets` | `/mnt/d/Pessoal/L4D2/l4d2-zone-server-assets`     |

Since the three repos are sibling folders, the default `repo_path` / `check_path` /
`assets_path` already resolve correctly (they are relative to the playbook folder). If the repos are
somewhere else, pass them explicitly:

```bash
ansible-playbook setup-server.yml \
  -e "repo_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server" \
  -e "check_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server-check" \
  -e "assets_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server-assets"
```

### Available parameters

| Variable                  | Default                                  | Description                                 |
|---------------------------|------------------------------------------|---------------------------------------------|
| `ansible_host`            | (inventory)                              | server address                              |
| `ansible_user`            | (inventory)                              | SSH user                                    |
| `ansible_password`        | (inventory)                              | SSH password                                |
| `ansible_become_password` | (inventory)                              | `sudo` password                             |
| `repo_path`               | `{{ playbook_dir }}/..` (the main repo)  | local path to `l4d2-zone-server`            |
| `check_path`              | `{{ playbook_dir }}/../../l4d2-zone-server-check`  | local path to `l4d2-zone-server-check`      |
| `assets_path`             | `{{ playbook_dir }}/../../l4d2-zone-server-assets` | local path to `l4d2-zone-server-assets`     |
