# Custom Plugins — l4d2-zone-server

This document describes the plugins maintained in this repository:

- **Custom plugins** — written specifically for this server.
- **Adapted plugins** — created by other authors and modified here (fixes and adjustments) to fit this server. These are **not original work**; the original author and repository are credited in each section.

For the remaining third-party plugins that ship unmodified with the base [ZoneMod / L4D2 Competitive Rework](https://github.com/SirPlease/L4D2-Competitive-Rework), refer to their original authors.

- **Sources:** [`addons/sourcemod/scripting/`](../../addons/sourcemod/scripting/) (`.sp`)
- **Compiled:** [`addons/sourcemod/plugins/optional/`](../../addons/sourcemod/plugins/optional/) (`.smx`) — except `l4d2_gameinfo_sync`, which lives in `plugins/` (auto-load)
- **Compile script:** [`ps/compile-custom-plugins.ps1`](../../ps/compile-custom-plugins.ps1)

---

## How configuration works in this repo

Because these plugins live in `optional/`, they don't auto-load — they are loaded explicitly and configured through the ZoneMod config layer. There are three touch points:

| File | Purpose |
|------|---------|
| `cfg/cfgogl/<mod>/shared_plugins.cfg` | **Loads** each plugin (`sm plugins load optional/<name>.smx`) |
| `cfg/cfgogl/<mod>/shared_cvars.cfg`   | **Sets ConVars** via `confogl_addcvar <cvar> <value>` |
| `cfg/server_secrets.cfg`              | **Secrets** (API tokens/keys) via `sm_cvar` — **git-ignored**, never committed |

`<mod>` is the active config folder, primarily [`zonemod`](../../cfg/cfgogl/zonemod/) and [`neomod`](../../cfg/cfgogl/neomod/).

> **ConVars marked `PROTECTED`** (tokens/secrets) must be set in `cfg/server_secrets.cfg`, not in `shared_cvars.cfg`, so they never leak into the public repo.

Chat messages shown to players are defined in [`addons/sourcemod/translations/`](../../addons/sourcemod/translations/) (`<name>.phrases.txt`) and can be translated/edited there.

---

## Index

**Custom plugins**

| Plugin | One-liner |
|--------|-----------|
| [l4d2_queue](#l4d2_queue) | Player queue — shows who plays next and lets players claim a slot |
| [l4d2_friendly_fire_control](#l4d2_friendly_fire_control) | Kicks players who exceed a friendly-fire limit |
| [l4d2_early_victory](#l4d2_early_victory) | Lets the losing team give up and skip to another campaign when the match is already decided |
| [l4d2_afk_to_spec](#l4d2_afk_to_spec) | Moves AFK players to spectator during ready-up |
| [l4d2_block_spec_during_tank](#l4d2_block_spec_during_tank) | Blocks team changes while the tank is alive |
| [l4d2_no_skip_getup_animation](#l4d2_no_skip_getup_animation) | Prevents skipping the get-up animation via team change |
| [l4d2_alltalk_before_round_start](#l4d2_alltalk_before_round_start) | Enables all-talk before the first round goes live |
| [l4d2_tank_is_comming](#l4d2_tank_is_comming) | Warns everyone as the tank's spawn point approaches |
| [l4d2_spec_lister](#l4d2_spec_lister) | Lets spectators choose which team they hear |
| [l4d2_forced_names](#l4d2_forced_names) | Locks specific SteamIDs to a fixed name |
| [l4d2_ranking](#l4d2_ranking) | Shows the player ranking (in-game + MOTD panel) |
| [l4d2_show_patent_icon](#l4d2_show_patent_icon) | Displays each player's rank/patent icon |
| [l4d2_playstats_sync](#l4d2_playstats_sync) | Syncs match statistics to the PlayStats API |
| [l4d2_gameinfo_sync](#l4d2_gameinfo_sync) | Syncs live game info & chat to the Game Info API |

**Adapted plugins (third-party)**

| Plugin | Original author | One-liner |
|--------|-----------------|-----------|
| [l4d2_mix](#l4d2_mix-adapted) | Luckylock (LuckyServ) | Captain/team picking (mix) through in-game menus |

---

# Custom plugins

## l4d2_queue

**Source:** [`scripting/l4d2_queue.sp`](../../addons/sourcemod/scripting/l4d2_queue.sp)

**What it does** — Maintains an ordered waiting list for a full server. Spectators who want to play register in the queue; when a slot opens the plugin points to whoever is next. Behavior players see:

- `!fila` / `!queue` prints the current list, in order (`Queue:` … with each `Slot`).
- `!vaga` / `!slot` claims an available slot. On success the claimer sees *"You have claimed a slot, {player} was moved to spectators."*, and the bumped player is told *"{player} has claimed your slot because they were ahead of you in the queue."*
- If no slot is owed to them, they get *"Everyone on the teams is ahead of you in the queue."*
- Slots can only be claimed at the start of a new game and while no mix is running — otherwise: *"You can only request a slot at the start of a new game and while no mix is in progress."*
- When a slot becomes available, the next player is nudged: *"There is a spot for you in the game! Type !slot to take it."*
- While teams are being auto-arranged, actions are held with *"The teams are being arranged automatically, please wait a moment."*
- A disconnected player keeps their place for `l4d2_queue_disconnect_timeout` seconds before being dropped. At end of a map's second round, the queue is shown to everyone after `l4d2_queue_endmap_delay` seconds (so the MVP/stats panel is shown first).

**Objective** — Make rotation on a busy server fair and transparent, so nobody loses their turn and everyone can see who's next.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_queue_disconnect_timeout` | `300` | Seconds a disconnected player stays in the queue before removal |
| `l4d2_queue_endmap_delay` | `8.0` | Seconds after the map's 2nd round ends before showing the queue (waits for MVP/stats first) |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_fila` / `sm_queue` | all | Print the current queue |
| `sm_vaga` / `sm_slot` | all | Claim an available slot |
| `sm_fixteams` | `ADMFLAG_BAN` | Force a queue/teams fix |

**How to configure** — Set the ConVars in `shared_cvars.cfg`, e.g. `confogl_addcvar l4d2_queue_disconnect_timeout 300`.

---

## l4d2_friendly_fire_control

**Source:** [`scripting/l4d2_friendly_fire_control.sp`](../../addons/sourcemod/scripting/l4d2_friendly_fire_control.sp)

**What it does** — Continuously tracks friendly-fire damage between human survivors. Each player has an accumulator that goes up when they shoot a teammate and slowly decays over time. When the accumulator crosses the limit the player is kicked, everyone sees *"{player} was kicked for friendly fire."* and the kicked player gets the reason *"You were kicked for friendly fire."* Occasional accidental damage decays away and never triggers a kick; only sustained/repeated team damage does.

**Objective** — Automatically deter intentional or repeated team-damage without needing an admin online, while forgiving the odd stray shot.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_friendly_fire_control_enabled` | `1` | Enable (`1`) / disable (`0`) the plugin |
| `l4d2_friendly_fire_control_interval` | `1.0` | Interval (s) at which accumulated FF damage decays |
| `l4d2_friendly_fire_control_decrement` | `1.0` | Amount subtracted from the accumulator each interval |
| `l4d2_friendly_fire_control_limit` | `20.0` | Accumulated FF damage that triggers the kick |

**How to configure** — All four ConVars in `shared_cvars.cfg`. Lower `limit` for a stricter server; raise `decrement` or lower `interval` to forgive faster.

---

## l4d2_early_victory

**Source:** [`scripting/l4d2_early_victory.sp`](../../addons/sourcemod/scripting/l4d2_early_victory.sp)

**What it does** — Detects when a best-of series is effectively over before the final map and offers the losing team a surrender vote. There are two triggers on the configured chapter (default the 4th map):

- **Right after the ready-up of the first round**, if the campaign score gap carried from the previous chapter is at least `min_gap` → the losing team gets a vote titled *"The score gap is over {n} points, give up the match?"*.
- **During the second round**, if the leading team's advantage is at least `min_diff` → everyone is told *"Game decided ({score} x {score}). Losing team will vote."* and the losing team gets a vote titled *"Game decided, give up the match?"*.

In both cases the vote follows the usual Left 4 Dead 2 convention — **F1 (Yes) executes the action**:

- If the majority votes yes → *"Losing team chose to give up. Ending match."*, the plugin announces the next campaign (*"Next campaign: {name}"*), slays everyone after `slay_delay`, runs a short countdown (*"Next campaign: {name} - changing map in {n}s"*), and changes to the next official campaign after `change_delay`.
- If there's no majority → *"No majority to give up. The match continues."* and the match proceeds normally.
- While an early victory is pending, manual map changes are blocked: *"Map change blocked until the match ends."*

The next campaign comes from a preconfigured rotation queue (see below), or an admin can override it with a menu (*"Queue the next campaigns (in queue: {n})"* / *"Clear list"*).

**Objective** — Avoid playing out a meaningless final map when the result is already settled, and cleanly rotate the server to a fresh campaign.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_early_victory_enabled` | `1` | Enable / disable |
| `l4d2_early_victory_chapter` | `4` | Chapter (map index) that triggers the check |
| `l4d2_early_victory_min_diff` | `15` | Minimum score lead required to start the second-round vote |
| `l4d2_early_victory_min_gap` | `1000` | Minimum campaign score gap required to start the ready-up vote |
| `l4d2_early_victory_vote_duration` | `15` | Seconds the losing team has to vote to give up |
| `l4d2_early_victory_slay_delay` | `5.0` | Seconds after the announcement before slaying everyone |
| `l4d2_early_victory_change_delay` | `3.0` | Seconds after slaying before changing campaign |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `l4d2_early_victory_queue "<Campaign>"` | server cfg | Append one official campaign to the rotation queue (one per line) |
| `l4d2_early_victory_queue_lock` | server cfg | Lock the queue; later `_queue` calls are ignored |
| `sm_setnextcampaign` | `ADMFLAG_CHANGEMAP` | Menu to queue the next campaign(s) or clear them, instead of a random draw |
| `sm_early_victory_debug` | `ADMFLAG_ROOT` | Print internal scores/bonus breakdown for debugging |

**How to configure** — Set the ConVars via `confogl_addcvar` in `shared_cvars.cfg`, then build the campaign rotation right after with raw `l4d2_early_victory_queue` lines, ending with `l4d2_early_victory_queue_lock`. Example (from [`zonemod/shared_cvars.cfg`](../../cfg/cfgogl/zonemod/shared_cvars.cfg)):

```
confogl_addcvar l4d2_early_victory_chapter 4
confogl_addcvar l4d2_early_victory_min_diff 15
confogl_addcvar l4d2_early_victory_min_gap 1000
l4d2_early_victory_queue "The Parish"
l4d2_early_victory_queue "Hard Rain"
l4d2_early_victory_queue "Death Toll"
l4d2_early_victory_queue_lock
```

---

## l4d2_afk_to_spec

**Source:** [`scripting/l4d2_afk_to_spec.sp`](../../addons/sourcemod/scripting/l4d2_afk_to_spec.sp)

**What it does** — During ready-up, watches for players who are AFK. When at least one other player is waiting to play, an AFK player is moved to spectator to free their slot, and everyone sees *"{player} was moved to spectators after being AFK for {n} seconds."* Two different grace periods apply: a longer/shorter window depending on whether the game is fresh (score 0–0) or already underway. It only acts during ready-up, so a live round is never disrupted.

**Objective** — Stop AFK players from holding a slot while active players wait, without interfering with an ongoing round.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_afk_to_spec_new_game_timeout` | `180` | Seconds a player may stay AFK during ready-up while the score is 0–0 |
| `l4d2_afk_to_spec_ongoing_game_timeout` | `360` | Seconds a player may stay AFK during ready-up after the game has started |

**How to configure** — Set both timeouts in `shared_cvars.cfg`.

---

## l4d2_block_spec_during_tank

**Source:** [`scripting/l4d2_block_spec_during_tank.sp`](../../addons/sourcemod/scripting/l4d2_block_spec_during_tank.sp)

**What it does** — While the tank is alive, blocks survivors from changing team (`jointeam`, `sm_spectate`/`sm_spec`/`sm_s`). A blocked player is told *"Tank is alive, use !pause to change team."* The restriction is lifted while the game is paused, so legitimate swaps are still possible.

**Objective** — Prevent players from dodging tank duty or abusing spec-swaps mid-tank to reset control/aggro.

**ConVars** — None.

**Commands** — Hooks `sm_spectate`, `sm_spec`, `sm_s` and `jointeam` (no new commands registered).

**How to configure** — No configuration needed; just load it.

---

## l4d2_no_skip_getup_animation

**Source:** [`scripting/l4d2_no_skip_getup_animation.sp`](../../addons/sourcemod/scripting/l4d2_no_skip_getup_animation.sp)

**What it does** — Blocks the exploit where a player skips their get-up animation (after being pounced, charged, etc.) by quickly toggling spectate or `jointeam`. It intercepts those commands during the get-up so the animation always plays out.

**Objective** — Remove a movement/timing exploit and keep get-ups consistent for everyone.

**ConVars** — None.

**Commands** — Hooks `sm_spectate`, `sm_spec`, `sm_s` and `jointeam` (no new commands registered).

**How to configure** — No configuration needed; just load it.

---

## l4d2_alltalk_before_round_start

**Source:** [`scripting/l4d2_alltalk_before_round_start.sp`](../../addons/sourcemod/scripting/l4d2_alltalk_before_round_start.sp)

**What it does** — On the first map of a campaign (while the score is still 0–0), enables `sv_alltalk` during warm-up/ready-up so both teams can talk to each other, showing *"All talk: ON"*. Once the round goes live (live countdown), it turns all-talk off again and shows *"All talk: OFF"*, restoring competitive voice rules. Depends on `readyup`.

**Objective** — Allow friendly cross-team chat before the match starts, then automatically enforce team-only voice when it matters.

**ConVars** — None (drives the game's `sv_alltalk`).

**How to configure** — No configuration needed; just load it.

---

## l4d2_tank_is_comming

**Source:** [`scripting/l4d2_tank_is_comming.sp`](../../addons/sourcemod/scripting/l4d2_tank_is_comming.sp)

**What it does** — Tracks the map's flow progress against the tank's stored spawn percentage and, as the team approaches it, prints a countdown to chat: *"Tank in {n}%"* (green **Tank**, light-green percentage). Alerts fire only within a short window before the spawn and each percentage is announced once. They stop as soon as the tank actually spawns and reset every round. Ready-up and pause states are respected, so no spam during warm-up or pauses.

**Objective** — Give both teams a fair, consistent heads-up that the tank is imminent, instead of relying on people memorizing spawn points.

**ConVars** — None (reads `versus_boss_buffer` and boss-percent data).

**How to configure** — No configuration needed; just load it. Requires the `l4d2_boss_percents` / `readyup` / `pause` includes at compile time (already present in this repo).

---

## l4d2_spec_lister

**Source:** [`scripting/l4d2_spec_lister.sp`](../../addons/sourcemod/scripting/l4d2_spec_lister.sp)

**What it does** — Lets a spectator pick which playing team's voice they hear. `!hear` with no argument opens a menu (*"Who do you want to hear?"*) with options *Survivors + spectators*, *Infected + spectators*, *Spectators only*, and *Everyone*; or pass an argument directly (`!hear survivors|infected|spectators|all`). On change the spectator sees *"You are now hearing: {choice}."* Other spectators are always audible. Admins get a broadcast toggle (`sm_broadcast`): while on, everyone hears them (*"{admin} is now talking to everyone."* / *"{admin} stopped talking to everyone."*).

**Objective** — Improve spectating and casting by letting viewers isolate one team's comms while still hearing other spectators.

**ConVars** — None.

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_hear` | all | Choose who you hear as a spectator. No arg opens the menu; optional arg: `survivors` / `infected` / `spectators` / `all` |
| `sm_broadcast` | `ADMFLAG_CHAT` | Toggle broadcast mode — while on, everyone hears you |

**How to configure** — No configuration needed; just load it.

---

## l4d2_forced_names

**Source:** [`scripting/l4d2_forced_names.sp`](../../addons/sourcemod/scripting/l4d2_forced_names.sp)

**What it does** — Binds specific SteamIDs to a fixed display name. Mappings are read from a config file on plugin start and on every config execution; if a bound player renames themselves, they're immediately renamed back. Both `STEAM_0` and `STEAM_1` id formats are accepted.

**Objective** — Keep known players under a consistent, recognizable name — useful for stats/ranking integrity and moderation.

**ConVars** — None.

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_forcename "<steamid>" "<name>"` | server cfg | Map a SteamID to a forced name |

**How to configure** — Edit [`cfg/sourcemod/forced_names.cfg`](../../cfg/sourcemod/forced_names.cfg), one line per player:

```
sm_forcename "STEAM_0:1:67149995" "Xei"
sm_forcename "STEAM_0:1:28225724" "jon"
```

The plugin `exec`s this file automatically; no manual reload needed after a config re-exec.

---

## l4d2_ranking

**Source:** [`scripting/l4d2_ranking.sp`](../../addons/sourcemod/scripting/l4d2_ranking.sp)

**What it does** — Surfaces the player ranking hosted at `ranking_url`. Players can type `!ranking` to check their position; a chat hint is shown (*"Type !ranking to check your position."*). When `ranking_show_motd_panel` is on, an MOTD panel titled *"L4D2 | Player Rankings"* opens with the ranking website.

**Objective** — Bring the competitive ranking to players directly from the server, in chat and via a web panel.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `ranking_url` | `""` | Ranking site URL |
| `ranking_show_motd_panel` | `1` | Show the MOTD panel with the ranking URL (`1`/`0`) |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_ranking` | all | Show the ranking |

**How to configure** — Set `ranking_url` and `ranking_show_motd_panel` in `shared_cvars.cfg`.

---

## l4d2_show_patent_icon

**Source:** [`scripting/l4d2_show_patent_icon.sp`](../../addons/sourcemod/scripting/l4d2_show_patent_icon.sp)

**What it does** — Displays each player's rank/"patent" icon (retrieved from the PlayStats web service) based on their level, up to a configurable maximum. Different icon asset versions are supported via `patent_icon_version`.

**Objective** — Show competitive standing visually in-game, so a player's rank is recognizable at a glance.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `patent_icon_api_url` | `""` | PlayStats web URL (`PROTECTED`) |
| `patent_icon_version` | `1` | Icon asset version |
| `patent_icon_max_level` | `15` | Maximum patent level |

**How to configure** — Set the non-secret values (`patent_icon_version`, `patent_icon_max_level`) in `shared_cvars.cfg`; keep `patent_icon_api_url` there too unless you treat it as a secret.

---

## l4d2_playstats_sync

**Source:** [`scripting/l4d2_playstats_sync.sp`](../../addons/sourcemod/scripting/l4d2_playstats_sync.sp)

**What it does** — Bridges the `l4d2_playstats.smx` plugin to the external PlayStats API: it takes the match data that plugin produces and posts it to the configured endpoint, authenticated with an access token.

**Objective** — Persist per-match player statistics to the central stats service so rankings/patents stay up to date.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `playstats_url` | `""` | PlayStats API URL (`PROTECTED`) |
| `playstats_access_token` | `""` | PlayStats access token (`PROTECTED`) |

**How to configure** — Set `playstats_url` in `shared_cvars.cfg`; set the secret **`playstats_access_token` in `cfg/server_secrets.cfg`** (git-ignored):

```
sm_cvar playstats_access_token "your-token-here"
```

---

## l4d2_gameinfo_sync

**Source:** [`scripting/l4d2_gameinfo_sync.sp`](../../addons/sourcemod/scripting/l4d2_gameinfo_sync.sp)

**What it does** — Pushes live game info to the Game Info API and relays in-game chat to it by hooking `say` and `say_team`. This lets an external service (e.g. the server website) show real-time match state and chat. Requests are authenticated with a secret key. This plugin loads from `plugins/` (auto-load), not `optional/`.

**Objective** — Expose real-time server/match state and chat to the Game Info service for website/integration features.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `gameinfo_url` | `""` | Game Info API URL (`PROTECTED`) |
| `gameinfo_secret` | `""` | Game Info API secret key (`PROTECTED`) |

**Commands** — Hooks `say` and `say_team` to relay chat (no new commands registered).

**How to configure** — Set `gameinfo_url` in `shared_cvars.cfg`; set the secret **`gameinfo_secret` in `cfg/server_secrets.cfg`** (git-ignored):

```
sm_cvar gameinfo_url "https://your-domain"
sm_cvar gameinfo_secret "your-secret-here"
```

---

# Adapted plugins (third-party)

## l4d2_mix (adapted)

> **Not original work.** This plugin was created by **Luckylock (LuckyServ)** — original repository: <https://github.com/LuckyServ/>. The copy in this repo has been **modified with fixes and adjustments for this server** (integration with the queue, translated/localized messages, and behavior tweaks). All credit for the original plugin goes to its author.

**Source (this server's version):** [`scripting/l4d2_mix.sp`](../../addons/sourcemod/scripting/l4d2_mix.sp)

**What it does** — Runs a "mix": players vote to start, captains are chosen, and captains pick their teams through in-game menus. Messages players see (prefixed with *"Mix Manager:"*):

- Anyone can call `!mix` to vote to start. Progress is shown as votes come in (*"{player} has voted to start a mix."*), and it begins once enough votes are reached (*"Started by vote."*) or when an admin starts it (*"Started by admin {name}."*).
- Guards against invalid states: *"Mix has already started."*, *"A mix cannot be started during a live round."*, *"You cannot start a mix as a spectator."*, *"Mix is not available in 1v1 matches."*
- During picking, players can't self-assign: *"You cannot join a team without being picked."*
- An admin can stop it with `!stopmix` (*"Stopped by admin {name}."*); calling mix commands when nothing is running returns *"No mix is currently in progress."*

**Objective** — Provide fair, captain-based team selection for pug/mix games, driven by the players themselves with admin override.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_mix_start_votes` | `2` | Number of votes required to start a mix (1–8) |
| `l4d2_mix_additional_players_after_mix` | `2` | Extra players required to vote after each mix starts before the game goes live (`0` disables) |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_mix` | all | Vote to start / participate in a mix |
| `sm_stopmix` | `ADMFLAG_CHANGEMAP` | Stop the current mix |

**How to configure** — Set the ConVars in `shared_cvars.cfg`, e.g. `confogl_addcvar l4d2_mix_start_votes 2`.
