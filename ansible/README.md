# Ansible — L4D2 Zone server setup

One-shot playbook to bring up a fresh Ubuntu server for L4D2. It always runs
the **whole** thing (provision + deploy + crontab). It is meant to be run
**once**, when creating the server — any later change goes through the Azure
DevOps pipeline, not this playbook.

> ⚠️ **Not tested yet.** This playbook was written from the pipeline
> definitions but has not been run against a real server. Review it and do a
> first run against a disposable/test machine before trusting it in production.

## What it does

Every run does all of the following, in order:

**1. Provisioning** — mirrors the server creation script:
- enables the i386 architecture, `apt update` / `upgrade`
- installs `screen`, `libc6:i386`, `lib32z1`, `wget`, `tar`, `dos2unix`
- downloads and extracts SteamCMD into `/home/steam`
- runs `app_update 222860` for the **linux** platform

**2. Deploy** — same destinations as the pipelines:

| Source (local)                             | Destination (server)                        |
|--------------------------------------------|---------------------------------------------|
| `addons/ cfg/ bash/ scripts/ materials/`   | `/home/steam/l4d2/left4dead2/<same folder>` |
| `host.txt`, `motd.txt`                     | `/home/steam/l4d2/left4dead2/`              |
| `bash/*.sh`                                | `dos2unix` + `chmod +x` applied             |
| `sound/` (check repo)                      | `/home/steam/l4d2/left4dead2/sound/`        |
| `whitelist.cfg` (check repo)               | `/home/steam/l4d2/left4dead2/`              |

> `assets/` and `fastdl/` are **not** copied: in the pipelines they are uploaded
> to Azure Blob Storage, not to the server.

**3. Crontab** — adds a root `@reboot` entry that runs the server bootstrap on
every boot, after a 5-second delay:

```cron
@reboot sleep 5 && /home/steam/l4d2/left4dead2/bash/bootstrap.sh
```

## Prerequisites (on the machine running Ansible)

- **Ansible** and **sshpass** (required for password-based login).
- On **Windows**, run it inside **WSL** (Ansible does not run natively on
  Windows). Windows paths like `D:\...` become `/mnt/d/...` inside WSL.

```bash
sudo apt update && sudo apt install -y ansible sshpass
```

## Configuration

Edit [`inventory.ini`](inventory.ini) with the server IP, user and password:

```ini
[l4d2]
zone-server ansible_host=YOUR_IP

[l4d2:vars]
ansible_user=YOUR_USER
ansible_password=YOUR_PASSWORD
ansible_become_password=YOUR_PASSWORD
```

> Do not commit real credentials. Prefer passing them on the command line (see
> below) or using [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html).

## Usage

From the `ansible/` folder — there is a single command, it always runs the full
setup:

```bash
ansible-playbook setup-server.yml
```

### Passing parameters on the command line

Everything can be overridden with `-e`, without editing any file. Keeping
credentials out of the repo, this is the recommended way to run it:

```bash
ansible-playbook setup-server.yml \
  -e "ansible_host=YOUR_IP ansible_user=YOUR_USER ansible_password=YOUR_PASSWORD ansible_become_password=YOUR_PASSWORD"
```

### Current paths on this machine (Windows + WSL)

The repositories live here on this PC:

| Repo                        | Windows path                              | WSL path                                          |
|-----------------------------|-------------------------------------------|---------------------------------------------------|
| `l4d2-zone-server` (main)   | `D:\Pessoal\L4D2\l4d2-zone-server`        | `/mnt/d/Pessoal/L4D2/l4d2-zone-server`            |
| `l4d2-zone-server-check`    | `D:\Pessoal\L4D2\l4d2-zone-server-check`  | `/mnt/d/Pessoal/L4D2/l4d2-zone-server-check`      |

Since the two repos are sibling folders, the default `repo_path` / `check_path`
already resolve correctly when you run the playbook from
`/mnt/d/Pessoal/L4D2/l4d2-zone-server/ansible`. If you ever run it from a
different location, pass them explicitly:

```bash
ansible-playbook setup-server.yml \
  -e "repo_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server" \
  -e "check_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server-check"
```

### Available parameters

| Variable                  | Default                                  | Description                                 |
|---------------------------|------------------------------------------|---------------------------------------------|
| `ansible_host`            | (inventory)                              | server IP                                   |
| `ansible_user`            | (inventory)                              | SSH user                                    |
| `ansible_password`        | (inventory)                              | SSH password                                |
| `ansible_become_password` | (inventory)                              | `sudo` password                             |
| `repo_path`               | `..` (the main repo itself)              | local path to `l4d2-zone-server`            |
| `check_path`              | `../../l4d2-zone-server-check`           | local path to `l4d2-zone-server-check`      |
