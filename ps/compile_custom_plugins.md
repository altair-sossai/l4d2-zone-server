# Compiling the custom plugins

This document explains how to compile the custom SourceMod plugins in this
repository using `ps/compile-custom-plugins.ps1`.

## What the script does

The script compiles the custom `.sp` source files into `.smx` plugins using the
**SourcePawn compiler committed in this repository** — not one installed on your
machine. This keeps builds reproducible: anyone (or the CI) gets the exact same
result regardless of what is installed locally.

- **Compiler:** `addons/sourcemod/scripting/sourcemod/spcomp.exe`
  (SourceMod `1.12.0.7230`, matching the includes and the SourceMod running on
  the server).
- **Sources:** `addons/sourcemod/scripting/*.sp`
- **Output:** `addons/sourcemod/plugins/...` (each plugin goes to its mapped
  subfolder — e.g. `optional/`, `fixes/`, or the plugins root).
- **Include paths** are passed explicitly:
  - `addons/sourcemod/scripting/include` (custom includes)
  - `addons/sourcemod/scripting/sourcemod/include` (standard SourceMod includes)

If any plugin fails to compile, the script reports which one and exits with an
error at the end.

## Requirements

- **PowerShell 5.1+** (Windows PowerShell or PowerShell 7 / `pwsh`).
- Nothing else — the compiler and all includes are already in the repository.

## How to run all plugins

To compile every plugin in the build list, run the script with no arguments.
It can be run from anywhere — paths are resolved relative to the script.

```powershell
./ps/compile-custom-plugins.ps1
```

## How to run plugin by plugin

Pass the plugin name (with or without the `.sp` extension, case-insensitive) to
compile only that one. You can also pass several names separated by spaces.

If you pass a name that is not in the build list, the script stops immediately
and prints the available names — nothing is compiled.

Pick a line below, copy it, and run it:

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
```

## Notes

- Compiling regenerates the `.smx` files under `addons/sourcemod/plugins/...`,
  so they will show up as modified in `git status`. Stage and commit the ones
  you want.
- Deployment (Azure pipeline) does **not** compile — it ships the committed
  `.smx` files. So remember to commit the recompiled `.smx` for your change to
  reach the server.

## Plugins in the build list

Copy any name from this list to compile it individually.

| Plugin name | Output path (under `addons/sourcemod/plugins/`) |
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

### All names on one line (for quick copy-paste)

```
l4d2_alltalk_before_round_start l4d2_queue l4d2_friendly_fire_control l4d2_mix l4d2_spectating_cheat l4d2_connect_announce l4d2_tank_is_comming l4d_death_item_glow l4d2_playstats_sync l4d2_ranking l4d2_show_patent_icon l4d2_no_skip_getup_animation l4d2_jockey_no_deadstops l4d2_gameinfo_sync l4d2_admin_hp l4d2_admin_spec_lock map-decals l4d2_early_victory l4d2_afk_to_spec l4d2_spec_lister l4d2_block_spec_during_tank l4d2_custom_commands l4d2_campaign_vote l4d2_forced_names
```
