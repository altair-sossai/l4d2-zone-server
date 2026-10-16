# Ansible — configuração do servidor L4D2 Zone

🌐 [English](ansible.md) | **Português** | [Español](ansible.es.md)

Playbook de execução única ([`ansible/setup-server.yml`](../../ansible/setup-server.yml)) para preparar um servidor Ubuntu novo para o L4D2. Ele sempre executa
**tudo** (provisionamento + deploy + crontab). Foi feito para ser executado
**uma vez**, na criação do servidor — qualquer mudança posterior passa pelo pipeline do Azure
DevOps ([`azure-pipelines.yml`](../../azure-pipelines.yml)), não por este playbook.

> ⚠️ **Ainda não testado.** Este playbook foi escrito a partir das definições
> dos pipelines, mas ainda não foi executado em um servidor real. Revise-o e faça
> uma primeira execução em uma máquina descartável/de teste antes de confiar nele em produção.

## O que ele faz

Toda execução faz tudo o que está abaixo, nesta ordem:

**1. Provisionamento** — reproduz o script de criação do servidor:
- habilita a arquitetura i386, executa `apt update` e um upgrade completo (`dist`)
- instala `screen`, `libc6:i386`, `lib32z1`, `wget`, `tar`, `dos2unix`
- baixa e extrai o SteamCMD em `/home/steam`
- executa `app_update 222860 validate` para a plataforma **linux**, instalando o jogo em `/home/steam/l4d2`

**2. Deploy** — mesmos destinos dos pipelines. Antes de copiar de cada repositório local, ele confere se o repositório está lá (`addons/` no repo principal, `whitelist.cfg` no repo check, `materials/` no repo assets) e para com uma mensagem dizendo qual caminho passar se ele não for encontrado:

| Origem (local)                                        | Destino (servidor)                          |
|-------------------------------------------------------|---------------------------------------------|
| `addons/ cfg/ bash/ scripts/` (repo principal)        | `/home/steam/l4d2/left4dead2/<mesma pasta>` |
| `host.txt`, `motd.txt` (repo principal)               | `/home/steam/l4d2/left4dead2/`              |
| `bash/*.sh`                                           | `dos2unix` + `chmod +x` aplicados           |
| `sound/` (repo `l4d2-zone-server-check`)              | `/home/steam/l4d2/left4dead2/sound/`        |
| `whitelist.cfg` (repo `l4d2-zone-server-check`)       | `/home/steam/l4d2/left4dead2/`              |
| `models/ materials/` (repo `l4d2-zone-server-assets`) | `/home/steam/l4d2/left4dead2/<mesma pasta>` |

> `assets/` e `fastdl/` (repo assets) **não** são copiados: nos pipelines eles
> são enviados para o Azure Blob Storage, não para o servidor.

**3. Crontab** — adiciona uma entrada `@reboot` do root (chamada `l4d2-bootstrap`) que executa o bootstrap do servidor a
cada inicialização, após um atraso de 5 segundos:

```cron
@reboot sleep 5 && /home/steam/l4d2/left4dead2/bash/bootstrap.sh
```

O [`bootstrap.sh`](../../bash/bootstrap.sh) define o fuso horário como `America/Sao_Paulo`, aplica as regras de firewall ([`iptables.sh`](../../bash/iptables.sh)) e inicia o servidor do jogo com o [`start.sh`](../../bash/start.sh) na porta `27015` (mapa `c2m1_highway`).

> Não execute o `bootstrap.sh` nem o `iptables.sh` manualmente por SSH: eles recriam o
> firewall e podem bloquear o seu acesso ao servidor. Para reiniciar só o jogo, use
> [`stop.sh`](../../bash/stop.sh) `<port>` e `start.sh` `<port> <map>`.

## Pré-requisitos (na máquina que executa o Ansible)

- **Ansible** e **sshpass** (necessário para login com senha).
- No **Windows**, execute dentro do **WSL** (o Ansible não roda nativamente no
  Windows). Caminhos do Windows como `D:\...` viram `/mnt/d/...` dentro do WSL.

```bash
sudo apt update && sudo apt install -y ansible sshpass
```

## Configuração

O [`ansible.cfg`](../../ansible/ansible.cfg) aponta o Ansible para o `inventory.ini`, desliga a verificação da chave de host SSH e habilita o pipelining. Edite o [`inventory.ini`](../../ansible/inventory.ini) com o endereço do servidor, o usuário e a senha:

```ini
[l4d2]
zone-server ansible_host=YOUR_SERVER_ADDRESS

[l4d2:vars]
ansible_user=YOUR_USER
ansible_password=YOUR_PASSWORD
ansible_become_password=YOUR_PASSWORD
ansible_python_interpreter=/usr/bin/python3
```

> Não faça commit de credenciais reais. Prefira passá-las pela linha de comando (veja
> abaixo) ou usar o [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html).

## Uso

A partir da pasta `ansible/` (para que o `ansible.cfg` seja carregado) — existe um único comando, que sempre executa a
configuração completa:

```bash
ansible-playbook setup-server.yml
```

> Se o Ansible avisar que está ignorando o `ansible.cfg` porque a pasta tem
> permissão de escrita para todos (comum em `/mnt/...` dentro do WSL), aponte para ele explicitamente:
> `ANSIBLE_CONFIG=./ansible.cfg ansible-playbook setup-server.yml`.

### Passando parâmetros pela linha de comando

Tudo pode ser sobrescrito com `-e`, sem editar nenhum arquivo. Como mantém as
credenciais fora do repositório, esta é a forma recomendada de executar:

```bash
ansible-playbook setup-server.yml \
  -e "ansible_host=YOUR_SERVER_ADDRESS ansible_user=YOUR_USER ansible_password=YOUR_PASSWORD ansible_become_password=YOUR_PASSWORD"
```

### Caminhos atuais nesta máquina (Windows + WSL)

Os repositórios ficam aqui neste PC:

| Repo                        | Caminho no Windows                        | Caminho no WSL                                    |
|-----------------------------|-------------------------------------------|---------------------------------------------------|
| `l4d2-zone-server` (principal) | `D:\Pessoal\L4D2\l4d2-zone-server`     | `/mnt/d/Pessoal/L4D2/l4d2-zone-server`            |
| `l4d2-zone-server-check`    | `D:\Pessoal\L4D2\l4d2-zone-server-check`  | `/mnt/d/Pessoal/L4D2/l4d2-zone-server-check`      |
| `l4d2-zone-server-assets`   | `D:\Pessoal\L4D2\l4d2-zone-server-assets` | `/mnt/d/Pessoal/L4D2/l4d2-zone-server-assets`     |

Como os três repositórios são pastas irmãs, os valores padrão de `repo_path` / `check_path` /
`assets_path` já resolvem corretamente (eles são relativos à pasta do playbook). Se os repositórios
estiverem em outro lugar, passe-os explicitamente:

```bash
ansible-playbook setup-server.yml \
  -e "repo_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server" \
  -e "check_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server-check" \
  -e "assets_path=/mnt/d/Pessoal/L4D2/l4d2-zone-server-assets"
```

### Parâmetros disponíveis

| Variável                  | Padrão                                   | Descrição                                   |
|---------------------------|------------------------------------------|---------------------------------------------|
| `ansible_host`            | (inventário)                             | endereço do servidor                        |
| `ansible_user`            | (inventário)                             | usuário SSH                                 |
| `ansible_password`        | (inventário)                             | senha SSH                                   |
| `ansible_become_password` | (inventário)                             | senha do `sudo`                             |
| `repo_path`               | `{{ playbook_dir }}/..` (o repo principal) | caminho local do `l4d2-zone-server`       |
| `check_path`              | `{{ playbook_dir }}/../../l4d2-zone-server-check`  | caminho local do `l4d2-zone-server-check`   |
| `assets_path`             | `{{ playbook_dir }}/../../l4d2-zone-server-assets` | caminho local do `l4d2-zone-server-assets`  |
