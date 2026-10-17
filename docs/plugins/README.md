# Custom Plugins — l4d2-zone-server

🌐 **English** | [Português](README.pt.md) | [Español](README.es.md)

This document describes the plugins maintained in this repository:

- **Custom plugins** — written specifically for this server.
- **Adapted plugins** — created by other authors and modified here (fixes and adjustments) to fit this server. These are **not original work**; the original author and repository are credited in each section.

For the remaining third-party plugins that ship unmodified with the base [ZoneMod / L4D2 Competitive Rework](https://github.com/SirPlease/L4D2-Competitive-Rework), refer to their original authors.

- **Sources:** [`addons/sourcemod/scripting/`](../../addons/sourcemod/scripting/) (`.sp`)
- **Compiled:** [`addons/sourcemod/plugins/optional/`](../../addons/sourcemod/plugins/optional/) (`.smx`) — except `l4d2_gameinfo_sync` and `l4d2_weapon_skins`, which live in `plugins/` (auto-load), and `annoyance_exploit_fixes`, which lives in `plugins/fixes/`
- **Compile script:** [`ps/compile-custom-plugins.ps1`](../../ps/compile-custom-plugins.ps1) — see [Compiling the custom plugins](../maintenance/compile-custom-plugins.md)

---

## How configuration works in this repo

Most of these plugins live in `optional/`, so they don't auto-load — they are loaded explicitly and configured through the ZoneMod config layer. These are the touch points:

| File | Purpose |
|------|---------|
| `cfg/cfgogl/<mod>/shared_plugins.cfg`  | **Loads** each plugin (`sm plugins load optional/<name>.smx`) |
| `cfg/cfgogl/<mod>/shared_cvars.cfg`    | **Sets ConVars** via `confogl_addcvar <cvar> <value>` |
| `cfg/cfgogl/<mod>/shared_settings.cfg` | Also sets ConVars via `confogl_addcvar` (used for `l4d2_spec_lister_hint`) |
| `cfg/server.cfg`                       | Server-wide values that must exist before any match config is loaded (`l4d2_web_url`) |
| `cfg/server_secrets.cfg`               | **Secrets** (API tokens/keys) via `sm_cvar` — **git-ignored**, never committed; executed at the top of `server.cfg` |

`<mod>` is the active config folder, primarily [`zonemod`](../../cfg/cfgogl/zonemod/) and [`neomod`](../../cfg/cfgogl/neomod/).

> **ConVars marked `PROTECTED`** are created with `FCVAR_PROTECTED`, so their value is never shown to clients. Only real secrets (`playstats_access_token`, `l4d2_web_secret`) go in `cfg/server_secrets.cfg`, so they never leak into the public repo; the other protected ConVars (URLs) are set in the versioned cfg files.

Chat messages shown to players are defined in [`addons/sourcemod/translations/`](../../addons/sourcemod/translations/) (`<name>.phrases.txt`) and can be translated/edited there.

---

## Index

**Custom plugins**

| Plugin | One-liner |
|--------|-----------|
| [l4d2_queue](#l4d2_queue) | Player queue — shows who plays next and lets players claim a slot |
| [l4d2_friendly_fire_control](#l4d2_friendly_fire_control) | Kicks players who exceed a friendly-fire limit |
| [l4d2_early_victory](#l4d2_early_victory) | Skips the last map when the match is already decided |
| [l4d2_afk_to_spec](#l4d2_afk_to_spec) | Moves AFK players to spectator during ready-up |
| [l4d2_block_spec_during_tank](#l4d2_block_spec_during_tank) | Blocks survivors from changing team while the tank is alive |
| [l4d2_no_skip_getup_animation](#l4d2_no_skip_getup_animation) | Prevents skipping the get-up animation via team change |
| [l4d2_alltalk_before_round_start](#l4d2_alltalk_before_round_start) | Enables all-talk before the first round goes live |
| [l4d2_tank_is_comming](#l4d2_tank_is_comming) | Warns everyone as the tank's spawn point approaches |
| [l4d2_spec_lister](#l4d2_spec_lister) | Lets spectators choose which team they hear |
| [l4d2_forced_names](#l4d2_forced_names) | Locks specific SteamIDs to a fixed name |
| [l4d2_ranking](#l4d2_ranking) | Shows the player ranking (in-game + MOTD panel) |
| [l4d2_show_patent_icon](#l4d2_show_patent_icon) | Displays each player's rank/patent icon during ready-up |
| [l4d2_playstats_sync](#l4d2_playstats_sync) | Uploads match statistics to the PlayStats API |
| [l4d2_gameinfo_sync](#l4d2_gameinfo_sync) | Syncs live game info, events and chat with the site |
| [l4d2_campaign_vote](#l4d2_campaign_vote) | Lets any player vote to change to any installed campaign |
| [l4d2_lerp_advisor](#l4d2_lerp_advisor) | Tells players with an invalid lerp which network commands to run |
| [l4d2_weapon_skins](#l4d2_weapon_skins) | Weapon skins per player, bought in the skin shop with MVP stars |

**Adapted plugins (third-party)**

| Plugin | Original author | One-liner |
|--------|-----------------|-----------|
| [l4d2_mix](#l4d2_mix-adapted) | Luckylock (LuckyServ) | Captain/team picking (mix) through in-game menus |
| [annoyance_exploit_fixes](#annoyance_exploit_fixes-adapted) | Sir (SirPlease) | Blocks callvote abuse and chat-flooding via `bugpause` |

---

# Custom plugins

## l4d2_queue

**Source:** [`scripting/l4d2_queue.sp`](../../addons/sourcemod/scripting/l4d2_queue.sp) · **Version:** 2.0.0

**What it does** — Keeps an ordered queue of every human player on the server, in the order they connected, and uses it to decide who plays next. The queue is saved to `addons/sourcemod/data/l4d2_queue.txt`, so it survives map changes and plugin reloads. Behavior players see:

- When a new game starts after a finished one, the queue is reordered: the winning team goes to the front and the losing team goes to the back, behind everyone who was waiting. For about 60 seconds after the round starts, the teams are arranged automatically so that the first players in the queue (skipping anyone with an invalid lerp) are the ones playing. Using `!slot` meanwhile shows *"The teams are being arranged automatically, please wait a moment."*
- `!fila` / `!queue` prints the waiting list in order (`Queue:` followed by `1º`, `2º`…). Players from the starting teams are left out, players currently on a team are highlighted, and nothing is printed while there are no more players than slots.
- `!vaga` / `!slot` during the ready-up of a new game (score 0–0):
  - If a team has a free spot, the player joins it: *"You have taken a slot in the game."*
  - Otherwise they take the slot of the player furthest back in the queue among those playing behind them. The claimer sees *"You have claimed a slot, {player} was moved to spectators."* and the bumped player is told *"{player} has claimed your slot because they were ahead of you in the queue."*
  - If everyone playing is ahead of them: *"Everyone on the teams is ahead of you in the queue."*
  - A player can claim a slot from the same player only `l4d2_queue_max_claims` times before the game goes live: *"You have already claimed a slot from {player} too many times."*
- During an ongoing game, only players from the starting teams can use `!slot`, to return to their original team in place of a substitute: *"During the game only players from the starting teams can request a slot."* If the substitute is controlling the tank, the claim waits: *"{player} is controlling the tank, request your slot again when the tank dies."* `!slot` does nothing after the round ends.
- No slot can be claimed while a mix is running: *"You can only request a slot at the start of a new game and while no mix is in progress."*
- A player with an invalid lerp (outside `lerpmonitor`'s `sm_min_lerp` / `sm_max_lerp`) can't claim a slot: *"Your lerp ({n}ms) is invalid. Adjust it between {min}ms and {max}ms before requesting a slot."*
- 30 seconds after a round starts, during the ready-up of a new game with more players than slots, every spectator is reminded: *"Check the !queue. If you are ahead of someone playing, use !slot."*
- A disconnected player keeps their place for `l4d2_queue_disconnect_timeout` seconds before being dropped. At the end of a map's second round, the queue is shown to everyone after `l4d2_queue_endmap_delay` seconds (so the MVP/stats panel is shown first).

**Objective** — Make rotation on a busy server fair and transparent, so nobody loses their turn and everyone can see who's next.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_queue_disconnect_timeout` | `300` | Seconds a disconnected player stays in the queue before removal |
| `l4d2_queue_endmap_delay` | `8.0` | Seconds after the map's 2nd round ends before showing the queue (waits for MVP/stats first) |
| `l4d2_queue_max_claims` | `2` | How many times a player can claim a slot from the same player before the game goes live |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_fila` / `sm_queue` | all | Print the current queue |
| `sm_vaga` / `sm_slot` | all | Claim an available slot |

**How to configure** — Set the ConVars in `shared_cvars.cfg`, e.g. `confogl_addcvar l4d2_queue_disconnect_timeout 300`.

---

## l4d2_friendly_fire_control

**Source:** [`scripting/l4d2_friendly_fire_control.sp`](../../addons/sourcemod/scripting/l4d2_friendly_fire_control.sp) · **Version:** 1.0.0

**What it does** — While a round is live, tracks friendly-fire damage between human survivors. Each player has an accumulator that goes up by the damage they deal to a teammate and goes down by `decrement` every `interval` seconds. When the accumulator reaches `limit`, the player is kicked and the game is paused (players unpause normally with `!unpause`, same as a crash pause); everyone sees *"{player} was kicked for friendly fire."* and the kicked player gets the reason *"You were kicked for friendly fire."* Occasional accidental damage decays away and never triggers a kick; only sustained/repeated team damage does.

Damage is ignored when the victim is incapacitated, hanging from or falling off a ledge, pinned by a special infected, or has total health (permanent + temporary) at or below `min_health` (e.g. mercy downs on low-health teammates). The counters are reset when the round ends.

**Objective** — Automatically deter intentional or repeated team-damage without needing an admin online, while forgiving the odd stray shot.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_friendly_fire_control_enabled` | `1` | Enable (`1`) / disable (`0`) the plugin |
| `l4d2_friendly_fire_control_interval` | `1.0` | Interval (s) at which accumulated FF damage decays |
| `l4d2_friendly_fire_control_decrement` | `1.0` | Amount subtracted from the accumulator each interval |
| `l4d2_friendly_fire_control_limit` | `20.0` | Accumulated FF damage that triggers the kick |
| `l4d2_friendly_fire_control_min_health` | `10.0` | FF is ignored when the victim's total health is at or below this value |

**Commands** — None.

**How to configure** — All five ConVars in `shared_cvars.cfg`. Lower `limit` for a stricter server; raise `decrement` or lower `interval` to forgive faster.

---

## l4d2_early_victory

**Source:** [`scripting/l4d2_early_victory.sp`](../../addons/sourcemod/scripting/l4d2_early_victory.sp) · **Version:** 1.6.0

**What it does** — Detects when a versus campaign is already decided before its last map. During the second round of the configured chapter (default the 4th map, never a finale), it checks the score every 5 seconds (not while a tank is alive or a survivor is incapacitated). The match is decided when the team playing survivors leads by at least `min_diff`, or can no longer get within `min_diff` of the other team even with the maximum score left on the map. Then everyone is told *"Game decided ({score} x {score}). Losing team will vote."* and the losing team gets a short vote titled *"Game decided, keep playing?"*:

- If at least half of the losing team votes Yes (missing votes count as No) → *"Losing team chose to continue."* and the match proceeds normally. If the vote is cancelled → *"Vote cancelled. Match continues."*
- Otherwise → *"No majority to continue. Ending match."*, a victory sound plays, the next campaign is announced (*"Next campaign: {name}"*) with a countdown hint (*"Next campaign: {name} - changing map in {n}s"*), everyone is slain after `slay_delay`, and the server changes to the first map of the next campaign after `change_delay` more seconds.
- During the second round of that chapter, change-campaign votes are blocked: *"Map change blocked until the match ends."*

The next campaign is the first entry of a rotation queue (see below); when the queue is empty, it is a random one of the 10 official campaigns the plugin knows (Dead Center, Dark Carnival, Swamp Fever, Hard Rain, The Parish, No Mercy, Death Toll, Dead Air, Blood Harvest, Cold Stream). The campaign being played is removed from the queue on map start. An admin can add campaigns to the queue or clear it with a menu (*"Queue the next campaigns (in queue: {n})"* / *"Clear list"*); each change is announced (*"The next campaigns are: …"*).

**Objective** — Avoid playing out a meaningless final map when the result is already settled, and cleanly rotate the server to a fresh campaign.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_early_victory_enabled` | `1` | Enable / disable |
| `l4d2_early_victory_chapter` | `4` | Chapter (map index) that triggers the check |
| `l4d2_early_victory_min_diff` | `15` | Minimum score difference required to start the vote |
| `l4d2_early_victory_vote_duration` | `15` | Seconds the losing team has to vote to continue |
| `l4d2_early_victory_slay_delay` | `5.0` | Seconds after the announcement before slaying everyone |
| `l4d2_early_victory_change_delay` | `3.0` | Seconds after slaying before changing campaign |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `l4d2_early_victory_queue "<Campaign>"` | server (cfg) | Append one official campaign to the rotation queue (one per line); unknown names are logged as errors |
| `l4d2_early_victory_queue_lock` | server (cfg) | Lock the queue; later `l4d2_early_victory_queue` calls are ignored |
| `sm_setnextcampaign` | `ADMFLAG_CHANGEMAP` | Menu to add campaigns to the queue or clear it |
| `sm_early_victory_debug` | `ADMFLAG_ROOT` | Print internal scores/bonus breakdown for debugging |

**How to configure** — Set the ConVars via `confogl_addcvar` in `shared_cvars.cfg`, then build the campaign rotation right after with raw `l4d2_early_victory_queue` lines, ending with `l4d2_early_victory_queue_lock`. Example (abridged from [`zonemod/shared_cvars.cfg`](../../cfg/cfgogl/zonemod/shared_cvars.cfg)):

```
confogl_addcvar l4d2_early_victory_chapter 4
confogl_addcvar l4d2_early_victory_min_diff 15
l4d2_early_victory_queue "The Parish"
l4d2_early_victory_queue "Hard Rain"
l4d2_early_victory_queue "Death Toll"
l4d2_early_victory_queue_lock
```

---

## l4d2_afk_to_spec

**Source:** [`scripting/l4d2_afk_to_spec.sp`](../../addons/sourcemod/scripting/l4d2_afk_to_spec.sp) · **Version:** 1.0.0

**What it does** — During ready-up, watches for players who are AFK (no mouse movement, key press or chat message). When both teams are full and at least one spectator is waiting to play, a player who has been AFK longer than the timeout is moved to spectator to free their slot, and everyone sees *"{player} was moved to spectators after being AFK for {n} seconds."* The timeout depends on the game: `new_game_timeout` while the score is 0–0, `ongoing_game_timeout` after the game has started. It only acts during ready-up, so a live round is never disrupted.

**Objective** — Stop AFK players from holding a slot while active players wait, without interfering with an ongoing round.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_afk_to_spec_new_game_timeout` | `180` | Seconds a player may stay AFK during ready-up while the score is 0–0 |
| `l4d2_afk_to_spec_ongoing_game_timeout` | `360` | Seconds a player may stay AFK during ready-up after the game has started |

**Commands** — None.

**How to configure** — Set both timeouts in `shared_cvars.cfg`.

---

## l4d2_block_spec_during_tank

**Source:** [`scripting/l4d2_block_spec_during_tank.sp`](../../addons/sourcemod/scripting/l4d2_block_spec_during_tank.sp) · **Version:** 1.0.0

**What it does** — While the tank is alive, blocks survivors from changing team (`jointeam`, `sm_spectate`/`sm_spec`/`sm_s`). A blocked player is told *"Tank is alive, use !pause to change team."* The restriction is lifted while the game is paused, so legitimate swaps are still possible.

**Objective** — Prevent players from dodging tank duty or abusing spec-swaps mid-tank to reset control/aggro.

**ConVars** — None.

**Commands** — Hooks `sm_spectate`, `sm_spec`, `sm_s` and `jointeam` (no new commands registered).

**How to configure** — No configuration needed; just load it.

---

## l4d2_no_skip_getup_animation

**Source:** [`scripting/l4d2_no_skip_getup_animation.sp`](../../addons/sourcemod/scripting/l4d2_no_skip_getup_animation.sp) · **Version:** 1.0.0

**What it does** — Blocks the exploit where a player skips their get-up animation (after being pounced, charged, etc.) by quickly going to spectator and back. A survivor who took any damage in the last 5 seconds can't go to spectator: `sm_spectate`/`sm_spec`/`sm_s` and `jointeam` to any team other than the survivors are silently ignored, so the animation always plays out.

**Objective** — Remove a movement/timing exploit and keep get-ups consistent for everyone.

**ConVars** — None.

**Commands** — Hooks `sm_spectate`, `sm_spec`, `sm_s` and `jointeam` (no new commands registered).

**How to configure** — No configuration needed; just load it.

---

## l4d2_alltalk_before_round_start

**Source:** [`scripting/l4d2_alltalk_before_round_start.sp`](../../addons/sourcemod/scripting/l4d2_alltalk_before_round_start.sp) · **Version:** 1.1.0

**What it does** — 10 seconds after a map starts, turns `sv_alltalk` on if the score is still 0–0 (the first map of a game), so both teams can talk to each other during warm-up/ready-up, and off on any other map. Once the live countdown starts (from `readyup`), it turns all-talk off again, restoring competitive voice rules. Each change is announced with *"All talk: ON"* / *"All talk: OFF"*.

**Objective** — Allow friendly cross-team chat before the match starts, then automatically enforce team-only voice when it matters.

**ConVars** — None (drives the game's `sv_alltalk`).

**Commands** — None.

**How to configure** — No configuration needed; just load it.

---

## l4d2_tank_is_comming

**Source:** [`scripting/l4d2_tank_is_comming.sp`](../../addons/sourcemod/scripting/l4d2_tank_is_comming.sp) · **Version:** 1.0.0

**What it does** — Tracks the survivors' flow progress against the tank's stored spawn percentage and, as the team approaches it, prints a countdown to chat: *"Tank in {n}%"* (green **Tank**, light-green percentage). Alerts are shown at 15%, 10% and then every 1% from 5% down to 1%, each one only once. They stop as soon as the tank actually spawns and reset when the round goes live. Nothing is printed during ready-up or pauses.

**Objective** — Give both teams a fair, consistent heads-up that the tank is imminent, instead of relying on people memorizing spawn points.

**ConVars** — None (reads `versus_boss_buffer` and boss-percent data).

**Commands** — None.

**How to configure** — No configuration needed; just load it. Requires the `l4d2_boss_percents` / `readyup` / `pause` includes at compile time (already present in this repo).

---

## l4d2_spec_lister

**Source:** [`scripting/l4d2_spec_lister.sp`](../../addons/sourcemod/scripting/l4d2_spec_lister.sp) · **Version:** 2.0.0

**What it does** — Lets a spectator pick which playing team's voice they hear (default: everyone). `!hear` with no argument opens a menu (*"Who do you want to hear?"*) with options *Survivors + spectators*, *Infected + spectators*, *Spectators only*, and *Everyone*; or pass an argument directly (`!hear survivors|infected|spectators|all`), which confirms with *"You are now hearing: {choice}."* Other spectators are always audible. The choice has no effect while `sv_alltalk` is on. 15 seconds after a map starts (first round only), spectators get a hint about `!hear` when `l4d2_spec_lister_hint` is `1`. Admins get a broadcast toggle (`sm_broadcast`): while on, everyone hears them (*"{admin} is now talking to everyone."* / *"{admin} stopped talking to everyone."*).

**Objective** — Improve spectating and casting by letting viewers isolate one team's comms while still hearing other spectators.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_spec_lister_hint` | `1` | Show spectators a hint about the `!hear` command. `0`:hide, `1`:show |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_hear` | all (spectators) | Choose who you hear as a spectator. No arg opens the menu; optional arg: `survivors` / `infected` / `spectators` / `all` |
| `sm_broadcast` | `ADMFLAG_CHAT` | Toggle broadcast mode — while on, everyone hears you |

**How to configure** — Set `l4d2_spec_lister_hint` in `shared_settings.cfg` (`zonemod` sets it to `0`).

---

## l4d2_forced_names

**Source:** [`scripting/l4d2_forced_names.sp`](../../addons/sourcemod/scripting/l4d2_forced_names.sp) · **Version:** 1.0.0

**What it does** — Binds specific SteamIDs to a fixed display name. A bound player gets the name when they join, and if they rename themselves they're immediately renamed back. Both `STEAM_0` and `STEAM_1` id formats are accepted.

**Objective** — Keep known players under a consistent, recognizable name — useful for stats/ranking integrity and moderation.

**ConVars** — None.

**Commands** — None.

**How to configure** — Edit [`configs/forced_names.cfg`](../../addons/sourcemod/configs/forced_names.cfg), one `"<steamid>" "<name>"` pair per player, in KeyValues format:

```
"ForcedNames"
{
	"STEAM_0:1:67149995" "Xei" // https://steamcommunity.com/profiles/76561198094565719
	"STEAM_0:1:28225724" "jon" // https://steamcommunity.com/profiles/76561198016717177
}
```

The plugin reads this file with the `KeyValues` API (not `exec`), on plugin start and on every config execution — no manual reload needed, and unicode names aren't stripped like they would be through an `exec`'d cfg.

---

## l4d2_ranking

**Source:** [`scripting/l4d2_ranking.sp`](../../addons/sourcemod/scripting/l4d2_ranking.sp) · **Version:** 1.0.0

**What it does** — Surfaces the player ranking hosted at `ranking_url`. `!ranking` opens an MOTD panel titled *"L4D2 | Player Rankings"* with the ranking website. While a new game (score 0–0) hasn't gone live yet, the plugin also prints the site name and *"Type !ranking to check your position."* every 200 seconds, and opens the panel once for each player 60 seconds after they join. All panels depend on `ranking_show_motd_panel`; with `0`, `!ranking` does nothing.

**Objective** — Bring the competitive ranking to players directly from the server, in chat and via a web panel.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `ranking_url` | `""` | Ranking site URL (`PROTECTED`) |
| `ranking_show_motd_panel` | `1` | Show the MOTD panel with the ranking URL (`1`/`0`) |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_ranking` | all | Open the ranking panel |

**How to configure** — Set `ranking_url` and `ranking_show_motd_panel` in `shared_cvars.cfg`.

---

## l4d2_show_patent_icon

**Source:** [`scripting/l4d2_show_patent_icon.sp`](../../addons/sourcemod/scripting/l4d2_show_patent_icon.sp) · **Version:** 1.1.0

**What it does** — During the ready-up of a new game (score 0–0), shows each playing player's rank/"patent" icon as a sprite above their head. Levels come from `GET {l4d2_web_url}/api/players/patents`, refreshed on map start and when a new game starts. `l4d2_web_url` is created by `l4d2_gameinfo_sync` and `l4d2_weapon_skins` and set in `cfg/server.cfg`; while it does not exist or is empty, the levels are not loaded. The sprites (`materials/sprites/patent_<level>_v<version>.vmt/.vtf`, levels 1 to `patent_icon_max_level`) are added to the downloads table. Survivors don't see the infected players' icons, and every icon is removed when the round goes live.

**Objective** — Show competitive standing visually in-game, so a player's rank is recognizable at a glance.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `patent_icon_version` | `1` | Icon asset version (`PROTECTED`) |
| `patent_icon_max_level` | `15` | Maximum patent level (`PROTECTED`) |

**Commands** — None.

**How to configure** — Set both ConVars in `shared_cvars.cfg` (neither is a secret; `zonemod` uses icon version `2`). The site URL comes from `l4d2_web_url`.

---

## l4d2_playstats_sync

**Source:** [`scripting/l4d2_playstats_sync.sp`](../../addons/sourcemod/scripting/l4d2_playstats_sync.sp) · **Version:** 1.1.0

**What it does** — Bridges the `l4d2_playstats.smx` plugin to the external PlayStats API. 10 seconds after each round starts, it uploads every stats log file that plugin wrote to `addons/sourcemod/logs/` to `POST {playstats_url}/api/statistics`, with the access token in the `Authorization` header. Files the API marks as processed are deleted, and after each successful upload it asks the site (`{l4d2_web_url}/api/cache/clear`, with `l4d2_web_secret` in the `Authorization` header) to clear its ranking cache. Both ConVars are created by `l4d2_gameinfo_sync` and `l4d2_weapon_skins`; when either is empty the cache is not cleared and the site refreshes it within an hour.

**Objective** — Persist per-match player statistics to the central stats service so rankings/patents stay up to date.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `playstats_url` | `""` | PlayStats API URL (`PROTECTED`) |
| `playstats_access_token` | `""` | PlayStats access token (`PROTECTED`) |

**Commands** — None.

**How to configure** — Set `playstats_url` in `shared_cvars.cfg`; set the secret **`playstats_access_token` in `cfg/server_secrets.cfg`** (git-ignored):

```
sm_cvar playstats_access_token "your-token-here"
```

---

## l4d2_gameinfo_sync

**Source:** [`scripting/l4d2_gameinfo_sync.sp`](../../addons/sourcemod/scripting/l4d2_gameinfo_sync.sp) · **Version:** 1.1.0

**What it does** — Keeps the site (`l4d2_web_url`) up to date with what is happening on the server, so it can show the live match state and chat. Every request carries `l4d2_web_secret` in the `Authorization` header. This plugin loads from `plugins/` (auto-load), not `optional/`.

- **Sends** the match configuration, round info, scoreboard and players (every 5 seconds), match events (round live/ended, pauses, mix started, tank spawned/died, skeets, levels, crowns, boomer vomits that hit at least `gameinfo_boomer_vomit_min_survivors` survivors, and others) and the chat, by hooking `say` and `say_team` (messages starting with `!` or `/` are not sent).
- **Receives** messages written on the site, shown in game as *"(External) {name}: {text}"*, and server commands queued on the site, which it runs.
- **On connect**, reports the player's connection to the site. If the site finds other accounts that connected from the same IP address, their names are printed in everyone's console and, when `gameinfo_related_accounts_chat` is `1`, announced in chat (*"{player} previously connected as {name}…"*).

**Objective** — Expose real-time server/match state and chat to the site for website/integration features.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_web_url` | `""` | L4D2 web URL, shared with `l4d2_weapon_skins` (`PROTECTED`) |
| `l4d2_web_secret` | `""` | L4D2 web secret key (the site `SecretKey`), shared with `l4d2_weapon_skins` (`PROTECTED`) |
| `gameinfo_related_accounts_chat` | `1` | Announce related accounts in chat (`1`/`0`); the console listing is always printed |
| `gameinfo_boomer_vomit_min_survivors` | `3` | Minimum number of survivors hit to report a boomer vomit event |

**Commands** — Hooks `say` and `say_team` to relay chat (no new commands registered).

**How to configure** — `l4d2_web_url` is set in `cfg/server.cfg`; set the secret **`l4d2_web_secret` in `cfg/server_secrets.cfg`** (git-ignored). Both cvars are shared by every plugin that talks to the site. Set `gameinfo_related_accounts_chat` and `gameinfo_boomer_vomit_min_survivors` in `shared_cvars.cfg` (`zonemod` turns the chat announcement off).

```
sm_cvar l4d2_web_secret "your-secret-here"
```

---

## l4d2_campaign_vote

**Source:** [`scripting/l4d2_campaign_vote.sp`](../../addons/sourcemod/scripting/l4d2_campaign_vote.sp) · **Version:** 1.0.0

**What it does** — Lets any player browse every installed campaign — official and custom — and start a map change vote from a menu, without needing admin rights. Typing `!votecampaign` (or `!votecamp`) opens a menu titled *"Choose a campaign to start a map change vote:"* listing all campaigns alphabetically. The list is built by reading the `missions/*.txt` files from inside the mounted VPK addons (via the Valve filesystem), so it always reflects what is actually installed. The 14 official campaigns show their English names (Dead Center, Dark Carnival, …); custom campaigns show the display title from their own VPK. Selecting an entry runs `callvote changemission <Name>` as if the player had typed it, starting the standard change-mission vote. If the campaign list can't be read, the player is told *"Could not read the campaign list."*

**Objective** — Give players a simple, self-service way to propose a campaign change through the game's native vote, covering custom campaigns too.

**ConVars** — None.

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_votecampaign` / `sm_votecamp` | all | Open the campaign menu and start a map change vote for the chosen campaign |
| `sm_listcampaigns` | `ADMFLAG_GENERIC` | Print the raw name and DisplayTitle of every campaign found in the missions folder to console |
| `sm_refreshcampaigns` | `ADMFLAG_GENERIC` | Reload `campaign_vote.cfg` and clear the cached campaign list so it's read again on the next menu open |

**How to configure** — Optionally edit [`configs/campaign_vote.cfg`](../../addons/sourcemod/configs/campaign_vote.cfg) (KeyValues format) to hide campaigns from the menu (`IgnoredCampaigns`) or override a campaign's display title (`CustomTitles`); `<name>` must match the mission's raw `Name` exactly (see `sm_listcampaigns`). The file is read again on every config execution. Player-facing UI text (menu title and messages) is defined in [`addons/sourcemod/translations/l4d2_campaign_vote.phrases.txt`](../../addons/sourcemod/translations/l4d2_campaign_vote.phrases.txt) (English, Portuguese and Spanish). The `changemission` vote itself must be enabled in the server's vote settings for the vote to actually start.

---

## l4d2_lerp_advisor

**Source:** [`scripting/l4d2_lerp_advisor.sp`](../../addons/sourcemod/scripting/l4d2_lerp_advisor.sp) · **Version:** 2.0.0

**What it does** — Works alongside `lerpmonitor`: it does **not** change anyone's settings (the server cannot force client CVars), it only *advises*. When a player connects (about 5 seconds after they are authorized and in the server) or joins the survivor/infected team, the plugin checks their lerp and, if it is outside the allowed range, shows a short two-line message — a colored heading (*"Invalid lerp! Paste this in the game console:"*) followed by the exact commands the player should paste into their game console (the command line itself is left uncolored for a clean copy/paste, and is also echoed to their console). Connect-time checks fire even while the player is a spectator, so they're warned before trying to play. The advice is only shown during ready-up (when `readyup` is loaded), and a 3-second cooldown prevents duplicate messages.

The lerp value and the valid range are taken **entirely from `lerpmonitor`** — the current lerp comes from its `LM_GetCurrentLerpTime` native and the bounds from its `sm_min_lerp` / `sm_max_lerp` CVars — so changing the limits there automatically changes when this advisory fires, with nothing to update here. If `lerpmonitor` isn't loaded, the plugin stays silent.

**Objective** — Give players with a bad/default lerp a clear, self-service fix instead of only being moved to spectators by `lerpmonitor`, without duplicating any of its detection logic.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_lerp_advisor_enabled` | `1` | Enable / disable the advisory message |

The suggested commands (`cl_interp 0; cl_interp_ratio 0; rate 100000; cl_cmdrate 100; cl_updaterate 100`) are hardcoded in the plugin, so they are shown to the player intact (a CVar value set through `confogl_addcvar` would be truncated at the first `;`).

**Commands** — None.

**How to configure** — Set `l4d2_lerp_advisor_enabled` in `shared_cvars.cfg`. Requires `lerpmonitor` to be loaded (it provides the lerp value and the `sm_min_lerp` / `sm_max_lerp` range). Player-facing text is defined in [`addons/sourcemod/translations/l4d2_lerp_advisor.phrases.txt`](../../addons/sourcemod/translations/l4d2_lerp_advisor.phrases.txt) (English, Portuguese and Spanish).

---

## l4d2_weapon_skins

**Source:** [`scripting/l4d2_weapon_skins.sp`](../../addons/sourcemod/scripting/l4d2_weapon_skins.sp) · **Version:** 3.3.0

> The full documentation of the skin system (assets, plugin internals, stars, skin shop and operations) is in the [Weapon Skins & Skin Shop wiki](../weapon-skins/README.md). This section is a summary.

**What it does** — Lets each player use the weapon skins they bought in the skin shop of the site (`{l4d2_web_url}/skins`) with **stars** — 1 star per all-time MVP (SI damage or common infected) in competitive matches. Skins exist for the SMG, MAC-10 (silenced SMG), MP5, pump shotgun, chrome shotgun, Magnum (Desert Eagle) and nine melee weapons (fireaxe, katana, machete, baseball bat, cricket bat, electric guitar, crowbar, golf club and frying pan). They are texture-only and delivered through FastDL, so players don't need to install any `.vpk`: the plugin swaps the weapon to a combined model and selects the skin family of the chosen skin. The skin follows the weapon: if it is dropped, whoever picks it up uses it with the same skin.

- **Only purchased skins are downloaded.** At map start, only the materials of skins bought by at least one player (`GET {l4d2_web_url}/api/skins`) are added to the downloads table. Owned and equipped skins come from `GET {l4d2_web_url}/api/players/skins`. Both are refreshed when the configs run, on round start and end, and every 2 minutes while there are players; the last valid answers are cached in `addons/sourcemod/data/` for the first map after a restart, because an empty server hibernates.
- **New purchases** are equipped right away and show up from the next map change (or right away, when the skin's files are already in this map's downloads because someone else had bought it). A connected player is told in chat when a purchase is received.
- **Changing skins in game:** only survivors, only during ready-up (when `readyup` is loaded) and only skins the player owns. Each change is saved on the site (`POST {l4d2_web_url}/api/players/{communityId}/skins/equip`, authenticated with `l4d2_web_secret`), so the equipped skins stay in sync between the game and the site.
- **Season refund:** purchased skins last one ranking season. At every ranking reset (every 2 months) purchases are refunded automatically and the stars spent come back; skins received as gifts are kept.
- **Players without downloads:** when `weapon_skins_kick_no_downloads` is `1` (and the skins are on), a player whose game has `cl_allowdownload` other than `1` or `cl_downloadfilter` other than `all`/`nosounds` is kicked. The kick message names the wrong setting and its value, gives the console command that fixes it (`cl_allowdownload 1` or `cl_downloadfilter all`) and suggests checking `autoexec.cfg`/`config.cfg`; each kick is logged. When it is `0`, those players stay and the skins seen in third person go back to the default for everyone while they are in the server, so no one ever sees an ERROR model.
- **Weapon pile cleanup:** every time a primary weapon is dropped, the plugin counts the primary weapons dropped by players within `weapon_skins_pile_radius` and removes the oldest ones above `weapon_skins_pile_max` (for example, when players swap weapons over and over at the infinite spawns of a safe room). Weapon spawns, weapons placed by the map, secondary weapons, items and held weapons are never removed.
- **First person without flicker:** for the six firearms and the nine melee weapons with skins the first-person model is always the combined model, with the skin's family or, without a skin, the weapon's original family (the original families come first in the combined models, see `stock_skins` in the cfg). The anti-cheat client points the game at the same model while the player is on the server, so the stock weapon no longer blinks over the skin on every shot, swing, reload and weapon switch. Details in the [wiki](../weapon-skins/03-game-plugin.md).

This plugin loads from `plugins/` (auto-load), not `optional/`, so the files are in the downloads table when players first connect.

**Objective** — Reward MVP performance with cosmetic weapon skins bought in the skin shop, without forcing players to install anything.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `weapon_skins_enabled` | `0` | Enable the weapon skins |
| `l4d2_web_url` | `""` | L4D2 web URL, shared with `l4d2_gameinfo_sync`. Used to read the purchased and equipped skins, save the skins equipped in game and build the `/skins` link (`PROTECTED`) |
| `l4d2_web_secret` | `""` | L4D2 web secret key (the site `SecretKey`), shared with `l4d2_gameinfo_sync`. Sent in the `Authorization` header to save the skins equipped in game (`PROTECTED`) |
| `weapon_skins_kick_no_downloads` | `0` | Kick players whose game does not download the server files. The kick message names the wrong setting and the console command that fixes it |
| `weapon_skins_pile_radius` | `120.0` | Radius, in game units, used to find primary weapons dropped close to each other |
| `weapon_skins_pile_max` | `3` | Maximum number of dropped primary weapons kept inside that radius; the oldest ones are removed (`0` = off) |
| `weapon_skins_preview_all` | `0` | Test mode. On the next map every skin in `weapon_skins.cfg` is added to the downloads table, bought or not, and root admins can use any skin (`!skin <id>`, `!skin next`, `!skin prev`), ignoring purchases, team and ready-up. Every player who connects while it is on downloads all the skins; turn it off and change the map to go back to downloading only the purchased skins |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_skin` / `sm_skins` | all | Without arguments, shows the help and the skin shop link |
| `sm_skin <id>` | all | Selects one of the player's skins by id (e.g. `hellsing-gold`) |
| `sm_skin next [weapon]` / `sm_skin prev [weapon]` | all | Cycles through the skins the player owns for that weapon, wrapping through the default skin |
| `sm_skin default [weapon]` | all | Goes back to the default skin |
| `sm_skin status` | all | Shows whether the skins are on and, in game, the player's stars and number of skins |
| `sm_skin on` / `sm_skin off` | `ADMFLAG_ROOT` | Turns the skins on or off for everyone. Overrides `weapon_skins_enabled` and stays in effect across map changes |
| `sm_skin test <id\|default> [weapon]` | `ADMFLAG_ROOT` | Tests on yourself, until the map changes, any skin already in this map's downloads, without buying it and outside the ready-up |

`sm_skins` accepts the same arguments as `sm_skin`. Root access is checked through the `sm_weaponskins_admin` override, so it can be changed in `admin_overrides.cfg`. `[weapon]` accepts `smg`/`uzi`, `mac`/`mac10`/`mac-10`/`silenced`, `mp5`, `pump`, `chrome`, `magnum`/`deagle`, `axe`/`fireaxe`, `bat`, `cricket`, `guitar`, `pan`, `golf`, the melee script names (`katana`, `machete`, `crowbar`…) and the full keys (`weapon_smg_mp5`, `weapon_melee_katana`…). Without it, the weapon in the player's hand is used, then the primary weapon, then the secondary weapon (melee or Magnum).

**How to configure** — `l4d2_web_url` is set in `cfg/server.cfg`, so the plugin knows which skins can be downloaded before any match config is loaded, and the secret **`l4d2_web_secret` in `cfg/server_secrets.cfg`** (git-ignored); both are shared with `l4d2_gameinfo_sync`. Set `weapon_skins_enabled`, `weapon_skins_kick_no_downloads`, `weapon_skins_pile_radius` and `weapon_skins_pile_max` in `shared_cvars.cfg`. Weapons and skins are defined in [`configs/weapon_skins.cfg`](../../addons/sourcemod/configs/weapon_skins.cfg): the `Weapons` section has the combined and default models of each weapon, and the `Skins` section maps each skin id to its weapon, skin family index (`skin`) and materials folder. The `skin` index must match the skin family inside the combined models, so the models must be rebuilt when skins are added or removed. Models and materials live in the [`l4d2-zone-server-assets`](https://github.com/altair-sossai/l4d2-zone-server-assets) repo, whose pipeline deploys them to the server and the FastDL blob. Skin titles, rarities, prices and images, purchases, gifts and refunds are managed on the site (see the [wiki](../weapon-skins/README.md)). Player-facing text is defined in [`addons/sourcemod/translations/l4d2_weapon_skins.phrases.txt`](../../addons/sourcemod/translations/l4d2_weapon_skins.phrases.txt) (English, Portuguese and Spanish).

---

# Adapted plugins (third-party)

## l4d2_mix (adapted)

> **Not original work.** This plugin was created by **Luckylock (LuckyServ)** — original repository: <https://github.com/LuckyServ/>. The copy in this repo has been **modified with fixes and adjustments for this server** (integration with the queue, translated/localized messages, and behavior tweaks). All credit for the original plugin goes to its author.

**Source (this server's version):** [`scripting/l4d2_mix.sp`](../../addons/sourcemod/scripting/l4d2_mix.sp) · **Version:** 5.0.0

**What it does** — Runs a "mix": players vote to start, everyone is moved to spectators, captains are chosen by vote, and the captains pick their teams through in-game menus. Messages players see (prefixed with *"Mix Manager:"*):

- A mix can only be started during the ready-up of a new game (score 0–0), with both teams full (*"Both teams must be full to start a mix."*).
- Anyone on a team can call `!mix` to vote to start. Progress is shown as votes come in (*"{player} has voted to start a mix. (votes needed: {n})"*), and it begins once enough votes are reached (*"Started by vote."*) or when an admin starts it (*"Started by admin {name}."*). After each completed mix, the next one in the same ready-up needs `l4d2_mix_additional_players_after_mix` more votes.
- `!mix <captain1> <captain2>` proposes two captains (players on the teams, by name or start of the name) and starts a yes/no vote among the players on the teams (*"{player} proposed {a} and {b} as captains."*); it passes with more than half of them voting Yes (*"Captains approved!"*). An admin using it starts the mix with those captains right away.
- Guards against invalid states: *"Mix has already started."*, *"A mix cannot be started during a live round."*, *"You cannot start a mix as a spectator."*, *"Mix is not available in 1v1 matches."*
- During picking, players can't self-assign: *"You cannot join a team without being picked."*
- If a player from the teams leaves during the mix, it is cancelled. The first time, they are warned that abandoning again gets them banned; the second time (before the game goes live) they are banned for `l4d2_mix_abandon_ban_time` minutes.
- `sm_kickspecs` is blocked during a mix and for `l4d2_mix_kickspecs_block_time` seconds after it ends.
- An admin can stop it with `!stopmix` (*"Stopped by admin {name}."*); calling it when nothing is running returns *"No mix is currently in progress."*

**Objective** — Provide fair, captain-based team selection for pug/mix games, driven by the players themselves with admin override.

**ConVars**

| ConVar | Default | Description |
|--------|---------|-------------|
| `l4d2_mix_start_votes` | `2` | Number of votes required to start a mix (1–8) |
| `l4d2_mix_additional_players_after_mix` | `2` | Extra players required to vote after each mix starts before the game goes live (`0` disables) |
| `l4d2_mix_kickspecs_block_time` | `40` | Seconds after a mix ends during which `sm_kickspecs` stays blocked (`0` disables) |
| `l4d2_mix_abandon_ban_time` | `30` | Minutes a player is banned when they abandon a mix for the second time (`0` disables the ban) |
| `l4d2_mix_captain_vote_duration` | `20` | Seconds the captain proposal vote (`!mix <captain1> <captain2>`) stays open |

**Commands**

| Command | Access | Description |
|---------|--------|-------------|
| `sm_mix` | all | Vote to start a mix; an admin with `ADMFLAG_CHANGEMAP` starts it right away |
| `sm_mix <captain1> <captain2>` | all | Propose two captains and start a vote among the players on the teams; an admin starts the mix with them right away |
| `sm_mix <captain>` | `ADMFLAG_CHANGEMAP` | Start the mix with that player as the first captain; the second captain is voted as usual |
| `sm_stopmix` | `ADMFLAG_CHANGEMAP` | Stop the current mix |

**How to configure** — Set the ConVars in `shared_cvars.cfg`, e.g. `confogl_addcvar l4d2_mix_start_votes 2`.

---

## annoyance_exploit_fixes (adapted)

> **Not original work.** This plugin was created by **Sir** as part of [SirPlease/L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework). The copy in this repo has been **modified with a fix for this server** (blocking `bugpause`, see below). All credit for the original plugin goes to its author.

**Source (this server's version):** [`scripting/annoyance_exploit_fixes.sp`](../../addons/sourcemod/scripting/annoyance_exploit_fixes.sp) · **Version:** 0.2.1

**What it does** — A compilation of small fixes for annoying/exploitable client behavior. Originally: blocks a vote while a new vote isn't allowed yet (*"A vote can't be called right now, try again in {n}s!"*), blocks kickvotes not aimed at a teammate, blocks self-kick, and (for CEDAPug games) blocks return-to-lobby/change-mission votes mid-match. This server's copy additionally blocks the client's native `bugpause` command outright, every time, for every client. `bugpause` fires when a player opens L4D2's built-in "Report a Bug" window — a legacy feature Valve no longer reads reports from — and the engine broadcasts a chat notification with no rate limit built in, so a player can bind a key to it and flood everyone's chat ([Valve issue #2765](https://github.com/ValveSoftware/Source-1-Games/issues/2765)). Since the feature serves no real purpose anymore, the block is unconditional.

**Objective** — Close off small client-side ways to grief or annoy other players, including `bugpause` chat-flooding.

**ConVars** — None.

**Commands** — Hooks `callvote` and `bugpause` (no new commands registered).

**How to configure** — No configuration needed; loaded server-wide via [`cfg/generalfixes.cfg`](../../cfg/generalfixes.cfg) (`sm plugins load fixes/annoyance_exploit_fixes.smx`), independent of which mod is active.
