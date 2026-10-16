# Compilar los plugins personalizados

🌐 [English](compile-custom-plugins.md) | [Português](compile-custom-plugins.pt.md) | **Español**

Este documento explica cómo compilar los plugins de SourceMod personalizados de este
repositorio usando [`ps/compile-custom-plugins.ps1`](../../ps/compile-custom-plugins.ps1).

## Qué hace el script

El script compila los archivos fuente `.sp` personalizados en plugins `.smx` usando el
**compilador de SourcePawn incluido en este repositorio** — no uno instalado en tu
máquina. Así los builds son reproducibles: cualquiera obtiene exactamente el mismo
resultado, sin importar lo que tenga instalado localmente.

- **Compilador:** `addons/sourcemod/scripting/sourcemod/spcomp.exe`
  (SourceMod `1.12.0.7230`, compatible con los includes y con el SourceMod que corre en
  el servidor).
- **Fuentes:** los archivos `.sp` de la lista de build del script, todos en
  `addons/sourcemod/scripting/` (ver [Plugins en la lista de build](#plugins-en-la-lista-de-build)).
- **Salida:** `addons/sourcemod/plugins/...` (cada plugin va a la subcarpeta
  asignada — `optional/` o la raíz de plugins).
- **Rutas de include** se pasan explícitamente:
  - `addons/sourcemod/scripting/include` (includes personalizados)
  - `addons/sourcemod/scripting/sourcemod/include` (includes estándar de SourceMod)

Si algún plugin no compila, el script indica cuál y termina con un
error al final.

## Requisitos

- **Windows** — el script ejecuta `spcomp.exe`.
- **PowerShell 5.1+** (Windows PowerShell o PowerShell 7 / `pwsh`).
- Nada más — el compilador y todos los includes ya están en el repositorio.

## Cómo compilar todos los plugins

Para compilar todos los plugins de la lista de build, ejecuta el script sin argumentos.
Se puede ejecutar desde cualquier lugar — las rutas se resuelven a partir del script (los
ejemplos de abajo lo ejecutan desde la raíz del repositorio).

```powershell
./ps/compile-custom-plugins.ps1
```

## Cómo compilar plugin por plugin

Pasa el nombre del plugin (con o sin la extensión `.sp`, sin distinguir mayúsculas y minúsculas) para
compilar solo ese. También puedes pasar varios nombres separados por espacios.

Si pasas un nombre que no está en la lista de build, el script se detiene de inmediato
y muestra los nombres disponibles — no se compila nada.

Elige una línea de abajo, cópiala y ejecútala:

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

## Notas

- Compilar regenera los archivos `.smx` en `addons/sourcemod/plugins/...`,
  así que aparecerán como modificados en `git status`. Haz stage y commit de los
  que quieras.
- El deploy (pipeline de Azure) **no** compila — envía los archivos `.smx`
  del repositorio. Así que recuerda hacer commit del `.smx` recompilado para que tu cambio
  llegue al servidor.
- El workflow de GitHub Actions [Check all plugins](../../.github/workflows/check_plugins.yml)
  no usa este script: en pushes y pull requests a `master` que cambian
  archivos `.sp`/`.inc`, compila todos los `.sp` de `addons/sourcemod/scripting/`
  con el compilador oficial (SourceMod 1.12 y 1.13) solo para comprobar que
  compilan. No hace commit de ningún `.smx`.

## Plugins en la lista de build

Copia cualquier nombre de esta lista para compilarlo individualmente.

| Nombre del plugin | Ruta de salida (dentro de `addons/sourcemod/plugins/`) |
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

### Todos los nombres en una línea (para copiar y pegar rápido)

```
l4d2_alltalk_before_round_start l4d2_queue l4d2_friendly_fire_control l4d2_mix l4d2_spectating_cheat l4d2_connect_announce l4d2_tank_is_comming l4d_death_item_glow l4d2_playstats_sync l4d2_ranking l4d2_show_patent_icon l4d2_no_skip_getup_animation l4d2_jockey_no_deadstops l4d2_gameinfo_sync l4d2_admin_hp l4d2_admin_spec_lock map-decals l4d2_early_victory l4d2_afk_to_spec l4d2_spec_lister l4d2_block_spec_during_tank l4d2_custom_commands l4d2_campaign_vote l4d2_forced_names l4d2_lerp_advisor l4d2_weapon_skins slots_vote
```
