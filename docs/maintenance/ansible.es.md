# Ansible — configuración del servidor L4D2 Zone

🌐 [English](ansible.md) | [Português](ansible.pt.md) | **Español**

Playbook de ejecución única ([`ansible/setup-server.yml`](../../ansible/setup-server.yml)) para preparar un servidor Ubuntu nuevo para L4D2. Siempre ejecuta
**todo** (aprovisionamiento + deploy + crontab). Está pensado para ejecutarse
**una sola vez**, al crear el servidor — cualquier cambio posterior pasa por el pipeline de Azure
DevOps ([`azure-pipelines.yml`](../../azure-pipelines.yml)), no por este playbook.

> ⚠️ **Todavía no probado.** Este playbook se escribió a partir de las definiciones
> de los pipelines, pero todavía no se ha ejecutado en un servidor real. Revísalo y haz
> una primera ejecución en una máquina desechable/de prueba antes de confiar en él en producción.

## Qué hace

Cada ejecución hace todo lo siguiente, en este orden:

**1. Aprovisionamiento** — reproduce el script de creación del servidor:
- habilita la arquitectura i386, ejecuta `apt update` y una actualización completa (`dist`)
- instala `screen`, `libc6:i386`, `lib32z1`, `wget`, `tar`, `dos2unix`
- descarga y extrae SteamCMD en `/home/steam`
- ejecuta `app_update 222860 validate` para la plataforma **linux**, instalando el juego en `/home/steam/l4d2`

**2. Deploy** — los mismos destinos que los pipelines. Antes de copiar desde cada repositorio local, comprueba que el repositorio esté ahí (`addons/` en el repo principal, `whitelist.cfg` en el repo check, `materials/` en el repo assets) y se detiene con un mensaje que indica qué ruta pasar si no lo encuentra:

| Origen (local)                                        | Destino (servidor)                          |
|-------------------------------------------------------|---------------------------------------------|
| `addons/ cfg/ bash/ scripts/` (repo principal)        | `/home/steam/l4d2/left4dead2/<misma carpeta>` |
| `host.txt`, `motd.txt` (repo principal)               | `/home/steam/l4d2/left4dead2/`              |
| `bash/*.sh`                                           | se aplica `dos2unix` + `chmod +x`           |
| `sound/` (repo `l4d2-zone-server-check`)              | `/home/steam/l4d2/left4dead2/sound/`        |
| `whitelist.cfg` (repo `l4d2-zone-server-check`)       | `/home/steam/l4d2/left4dead2/`              |
| `models/ materials/` (repo `l4d2-zone-server-assets`) | `/home/steam/l4d2/left4dead2/<misma carpeta>` |

> `assets/` y `fastdl/` (repo assets) **no** se copian: en los pipelines se
> suben a Azure Blob Storage, no al servidor.

**3. Crontab** — añade una entrada `@reboot` de root (llamada `l4d2-bootstrap`) que ejecuta el bootstrap del servidor en
cada arranque, después de una espera de 5 segundos:

```cron
@reboot sleep 5 && /home/steam/l4d2/left4dead2/bash/bootstrap.sh
```

[`bootstrap.sh`](../../bash/bootstrap.sh) configura la zona horaria como `America/Sao_Paulo`, aplica las reglas del firewall ([`iptables.sh`](../../bash/iptables.sh)) e inicia el servidor del juego con [`start.sh`](../../bash/start.sh) en el puerto `27015` (mapa `c2m1_highway`).

> No ejecutes `bootstrap.sh` ni `iptables.sh` a mano por SSH: reconstruyen el
> firewall y pueden dejarte sin acceso al servidor. Para reiniciar solo el juego, usa
> [`stop.sh`](../../bash/stop.sh) `<port>` y `start.sh` `<port> <map>`.

## Requisitos previos (en la máquina que ejecuta Ansible)

- **Ansible** y **sshpass** (necesario para iniciar sesión con contraseña).
- En **Windows**, ejecútalo dentro de **WSL** (Ansible no funciona de forma nativa en
  Windows). Las rutas de Windows como `D:\...` pasan a ser `/mnt/d/...` dentro de WSL.

```bash
sudo apt update && sudo apt install -y ansible sshpass
```

## Configuración

[`ansible.cfg`](../../ansible/ansible.cfg) indica a Ansible que use `inventory.ini`, desactiva la verificación de la clave de host SSH y habilita el pipelining. Edita [`inventory.ini`](../../ansible/inventory.ini) con la dirección del servidor, el usuario y la contraseña:

```ini
[l4d2]
zone-server ansible_host=YOUR_SERVER_ADDRESS

[l4d2:vars]
ansible_user=YOUR_USER
ansible_password=YOUR_PASSWORD
ansible_become_password=YOUR_PASSWORD
ansible_python_interpreter=/usr/bin/python3
```

> No hagas commit de credenciales reales. Es mejor pasarlas por la línea de comandos (ver
> abajo) o usar [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html).

## Uso

Desde la carpeta `ansible/` (para que se cargue `ansible.cfg`) — hay un único comando, que siempre ejecuta la
configuración completa:

```bash
ansible-playbook setup-server.yml
```

> Si Ansible avisa que ignora `ansible.cfg` porque la carpeta tiene permiso de
> escritura para todos (algo común en `/mnt/...` dentro de WSL), indícalo explícitamente:
> `ANSIBLE_CONFIG=./ansible.cfg ansible-playbook setup-server.yml`.

### Pasar parámetros por la línea de comandos

Todo se puede sobrescribir con `-e`, sin editar ningún archivo. Como mantiene las
credenciales fuera del repositorio, esta es la forma recomendada de ejecutarlo:

```bash
ansible-playbook setup-server.yml \
  -e "ansible_host=YOUR_SERVER_ADDRESS ansible_user=YOUR_USER ansible_password=YOUR_PASSWORD ansible_become_password=YOUR_PASSWORD"
```

### Rutas actuales en esta máquina (Windows + WSL)

Los repositorios están aquí en este PC:

| Repo                        | Ruta en Windows                           | Ruta en WSL                                       |
|-----------------------------|-------------------------------------------|---------------------------------------------------|
| `l4d2-zone-server` (principal) | `D:\Pessoal\L4D2\l4d2-zone-server`     | `/mnt/d/Pessoal/L4D2/l4d2-zone-server`            |
| `l4d2-zone-server-check`    | `D:\Pessoal\L4D2\l4d2-zone-server-check`  | `/mnt/d/Pessoal/L4D2/l4d2-zone-server-check`      |
| `l4d2-zone-server-assets`   | `D:\Pessoal\L4D2\l4d2-zone-server-assets` | `/mnt/d/Pessoal/L4D2/l4d2-zone-server-assets`     |

Como los tres repositorios son carpetas hermanas, los valores predeterminados de `repo_path` / `check_path` /
`assets_path` ya se resuelven correctamente (son relativos a la carpeta del playbook). Si los repositorios
están en otro lugar, pásalos explícitamente:

```bash
ansible-playbook setup-server.yml \
  -e "repo_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server" \
  -e "check_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server-check" \
  -e "assets_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server-assets"
```

### Parámetros disponibles

| Variable                  | Predeterminado                           | Descripción                                 |
|---------------------------|------------------------------------------|---------------------------------------------|
| `ansible_host`            | (inventario)                             | dirección del servidor                      |
| `ansible_user`            | (inventario)                             | usuario SSH                                 |
| `ansible_password`        | (inventario)                             | contraseña SSH                              |
| `ansible_become_password` | (inventario)                             | contraseña de `sudo`                        |
| `repo_path`               | `{{ playbook_dir }}/..` (el repo principal) | ruta local de `l4d2-zone-server`         |
| `check_path`              | `{{ playbook_dir }}/../../l4d2-zone-server-check`  | ruta local de `l4d2-zone-server-check`      |
| `assets_path`             | `{{ playbook_dir }}/../../l4d2-zone-server-assets` | ruta local de `l4d2-zone-server-assets`     |
