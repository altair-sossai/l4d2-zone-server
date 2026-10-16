# Compilando os plugins customizados

🌐 [English](compile-custom-plugins.md) | **Português** | [Español](compile-custom-plugins.es.md)

Este documento explica como compilar os plugins SourceMod customizados deste
repositório usando o [`ps/compile-custom-plugins.ps1`](../../ps/compile-custom-plugins.ps1).

## O que o script faz

O script compila os arquivos-fonte `.sp` customizados em plugins `.smx` usando o
**compilador SourcePawn que está no próprio repositório** — e não um instalado na sua
máquina. Isso mantém os builds reproduzíveis: qualquer pessoa obtém exatamente o mesmo
resultado, independentemente do que estiver instalado localmente.

- **Compilador:** `addons/sourcemod/scripting/sourcemod/spcomp.exe`
  (SourceMod `1.12.0.7230`, compatível com os includes e com o SourceMod que roda no
  servidor).
- **Fontes:** os arquivos `.sp` da lista de build do script, todos em
  `addons/sourcemod/scripting/` (veja [Plugins na lista de build](#plugins-na-lista-de-build)).
- **Saída:** `addons/sourcemod/plugins/...` (cada plugin vai para a subpasta
  definida para ele — `optional/` ou a raiz de plugins).
- **Caminhos de include** são passados explicitamente:
  - `addons/sourcemod/scripting/include` (includes customizados)
  - `addons/sourcemod/scripting/sourcemod/include` (includes padrão do SourceMod)

Se algum plugin falhar ao compilar, o script informa qual foi e termina com
erro no final.

## Requisitos

- **Windows** — o script executa o `spcomp.exe`.
- **PowerShell 5.1+** (Windows PowerShell ou PowerShell 7 / `pwsh`).
- Mais nada — o compilador e todos os includes já estão no repositório.

## Como compilar todos os plugins

Para compilar todos os plugins da lista de build, execute o script sem argumentos.
Ele pode ser executado de qualquer lugar — os caminhos são resolvidos a partir do script (os
exemplos abaixo o executam a partir da raiz do repositório).

```powershell
./ps/compile-custom-plugins.ps1
```

## Como compilar plugin por plugin

Passe o nome do plugin (com ou sem a extensão `.sp`, sem diferenciar maiúsculas e minúsculas) para
compilar só ele. Você também pode passar vários nomes separados por espaço.

Se você passar um nome que não está na lista de build, o script para na hora
e mostra os nomes disponíveis — nada é compilado.

Escolha uma linha abaixo, copie e execute:

```powershell
# l4d2_alltalk_before_round_start
./ps/compile-custom-plugins.ps1 l4d2_alltalk_before_round_start

# l4d2_queue
./ps/compile-custom-plugins.ps1 l4d2_queue

# l4d2_friendly_fire_control
./ps/compile-custom-plugins.ps1 l4d2_friendly_fire_control

# l4d2_mix
./ps/compile-custom-plugins.ps1 l4d2_mix

# l4d2_spectating_cheat
./ps/compile-custom-plugins.ps1 l4d2_spectating_cheat

# l4d2_connect_announce
./ps/compile-custom-plugins.ps1 l4d2_connect_announce

# l4d2_tank_is_comming
./ps/compile-custom-plugins.ps1 l4d2_tank_is_comming

# l4d_death_item_glow
./ps/compile-custom-plugins.ps1 l4d_death_item_glow

# l4d2_playstats_sync
./ps/compile-custom-plugins.ps1 l4d2_playstats_sync

# l4d2_ranking
./ps/compile-custom-plugins.ps1 l4d2_ranking

# l4d2_show_patent_icon
./ps/compile-custom-plugins.ps1 l4d2_show_patent_icon

# l4d2_no_skip_getup_animation
./ps/compile-custom-plugins.ps1 l4d2_no_skip_getup_animation

# l4d2_jockey_no_deadstops
./ps/compile-custom-plugins.ps1 l4d2_jockey_no_deadstops

# l4d2_gameinfo_sync
./ps/compile-custom-plugins.ps1 l4d2_gameinfo_sync

# l4d2_admin_hp
./ps/compile-custom-plugins.ps1 l4d2_admin_hp

# l4d2_admin_spec_lock
./ps/compile-custom-plugins.ps1 l4d2_admin_spec_lock

# map-decals
./ps/compile-custom-plugins.ps1 map-decals

# l4d2_early_victory
./ps/compile-custom-plugins.ps1 l4d2_early_victory

# l4d2_afk_to_spec
./ps/compile-custom-plugins.ps1 l4d2_afk_to_spec

# l4d2_spec_lister
./ps/compile-custom-plugins.ps1 l4d2_spec_lister

# l4d2_block_spec_during_tank
./ps/compile-custom-plugins.ps1 l4d2_block_spec_during_tank

# l4d2_custom_commands
./ps/compile-custom-plugins.ps1 l4d2_custom_commands

# l4d2_campaign_vote
./ps/compile-custom-plugins.ps1 l4d2_campaign_vote

# l4d2_forced_names
./ps/compile-custom-plugins.ps1 l4d2_forced_names

# l4d2_lerp_advisor
./ps/compile-custom-plugins.ps1 l4d2_lerp_advisor

# l4d2_weapon_skins
./ps/compile-custom-plugins.ps1 l4d2_weapon_skins

# slots_vote
./ps/compile-custom-plugins.ps1 slots_vote
```

## Observações

- Compilar gera de novo os arquivos `.smx` em `addons/sourcemod/plugins/...`,
  então eles vão aparecer como modificados no `git status`. Faça stage e commit dos
  que você quiser.
- O deploy (pipeline do Azure) **não** compila — ele envia os arquivos `.smx`
  que estão no repositório. Então lembre de fazer commit do `.smx` recompilado para que a sua mudança
  chegue ao servidor.
- O workflow do GitHub Actions [Check all plugins](../../.github/workflows/check_plugins.yml)
  não usa este script: em pushes e pull requests para a `master` que mudam
  arquivos `.sp`/`.inc`, ele compila todos os `.sp` de `addons/sourcemod/scripting/`
  com o compilador oficial (SourceMod 1.12 e 1.13) só para verificar se
  compilam. Ele não faz commit de nenhum `.smx`.

## Plugins na lista de build

Copie qualquer nome desta lista para compilá-lo individualmente.

| Nome do plugin | Caminho de saída (dentro de `addons/sourcemod/plugins/`) |
| --- | --- |
| `l4d2_alltalk_before_round_start` | `optional/l4d2_alltalk_before_round_start.smx` |
| `l4d2_queue` | `optional/l4d2_queue.smx` |
| `l4d2_friendly_fire_control` | `optional/l4d2_friendly_fire_control.smx` |
| `l4d2_mix` | `optional/l4d2_mix.smx` |
| `l4d2_spectating_cheat` | `optional/l4d2_spectating_cheat.smx` |
| `l4d2_connect_announce` | `optional/l4d2_connect_announce.smx` |
| `l4d2_tank_is_comming` | `optional/l4d2_tank_is_comming.smx` |
| `l4d_death_item_glow` | `optional/l4d_death_item_glow.smx` |
| `l4d2_playstats_sync` | `optional/l4d2_playstats_sync.smx` |
| `l4d2_ranking` | `optional/l4d2_ranking.smx` |
| `l4d2_show_patent_icon` | `optional/l4d2_show_patent_icon.smx` |
| `l4d2_no_skip_getup_animation` | `optional/l4d2_no_skip_getup_animation.smx` |
| `l4d2_jockey_no_deadstops` | `optional/l4d2_jockey_no_deadstops.smx` |
| `l4d2_gameinfo_sync` | `l4d2_gameinfo_sync.smx` |
| `l4d2_admin_hp` | `optional/l4d2_admin_hp.smx` |
| `l4d2_admin_spec_lock` | `optional/l4d2_admin_spec_lock.smx` |
| `map-decals` | `optional/map-decals.smx` |
| `l4d2_early_victory` | `optional/l4d2_early_victory.smx` |
| `l4d2_afk_to_spec` | `optional/l4d2_afk_to_spec.smx` |
| `l4d2_spec_lister` | `optional/l4d2_spec_lister.smx` |
| `l4d2_block_spec_during_tank` | `optional/l4d2_block_spec_during_tank.smx` |
| `l4d2_custom_commands` | `optional/l4d2_custom_commands.smx` |
| `l4d2_campaign_vote` | `optional/l4d2_campaign_vote.smx` |
| `l4d2_forced_names` | `optional/l4d2_forced_names.smx` |
| `l4d2_lerp_advisor` | `optional/l4d2_lerp_advisor.smx` |
| `l4d2_weapon_skins` | `l4d2_weapon_skins.smx` |
| `slots_vote` | `optional/slots_vote.smx` |

### Todos os nomes em uma linha (para copiar e colar rápido)

```
l4d2_alltalk_before_round_start l4d2_queue l4d2_friendly_fire_control l4d2_mix l4d2_spectating_cheat l4d2_connect_announce l4d2_tank_is_comming l4d_death_item_glow l4d2_playstats_sync l4d2_ranking l4d2_show_patent_icon l4d2_no_skip_getup_animation l4d2_jockey_no_deadstops l4d2_gameinfo_sync l4d2_admin_hp l4d2_admin_spec_lock map-decals l4d2_early_victory l4d2_afk_to_spec l4d2_spec_lister l4d2_block_spec_during_tank l4d2_custom_commands l4d2_campaign_vote l4d2_forced_names l4d2_lerp_advisor l4d2_weapon_skins slots_vote
```
