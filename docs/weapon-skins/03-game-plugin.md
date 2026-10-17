# 3. Game server plugin — `l4d2_weapon_skins`

🌐 **English** | [Português](03-game-plugin.pt.md) | [Español](03-game-plugin.es.md) · [Wiki home](README.md)

**Source:** [`addons/sourcemod/scripting/l4d2_weapon_skins.sp`](../../addons/sourcemod/scripting/l4d2_weapon_skins.sp) (v3.2.0) · **Config:** [`addons/sourcemod/configs/weapon_skins.cfg`](../../addons/sourcemod/configs/weapon_skins.cfg) · **Translations:** `addons/sourcemod/translations/{,pt/,es/}l4d2_weapon_skins.phrases.txt`

The plugin loads from `plugins/` (auto-load), not `optional/`, so it is already running in the lobby and the skin files are in the downloads table when players first connect.

## Data it keeps in memory

| Variable | Content |
|---|---|
| `g_hSkins` / `g_hSkinsByName` | Skins from `weapon_skins.cfg` (`WeaponSkin` structs) and an id → index map |
| `g_hWeaponModels` | Combined/stock models per weapon and their precache indexes |
| `g_hPurchasedSkins` | Skin ids bought by at least one player (from `/api/skins`) |
| `g_hOwnedSkins` | Keys `"<steamid64>:<skin>"` for every owned skin (from `/api/players/skins`) |
| `g_hPlayerChoices` | Equipped skin per `"<steamid64>:<weapon>"` |
| `g_hLocalChanges` | When a player last changed a skin in game (protects recent changes, see below) |
| `g_hTestChoices` | Admin `!skin test` overrides, cleared on map start |

## Map start: building the downloads table

On `OnMapStart` the plugin reads `weapon_skins.cfg`:

1. **Every weapon's combined model folder** is added to the downloads table and precached, whether or not someone owns a skin.
2. **Each skin** is prepared only if someone bought it (or test mode is on):

```sourcepawn
bool PrepareSkin(WeaponSkin skin)
{
	...
	if (!models.ready || (!g_hPreviewAll.BoolValue && !g_hPurchasedSkins.ContainsKey(skin.name)))
	{
		return false;
	}
	...
	AddDirectoryToDownloadsTable(skin.materials);
	...
	return true;
}
```

`skin.ready` tells later code whether that skin's files are in **this** map's downloads table. A skin bought during the map is owned but not ready until the next map.

### Hibernation and the cache files

An empty L4D2 server hibernates: async HTTP callbacks are only processed after the first player connects — too late for that player's downloads. So the plugin saves the last valid API responses to disk and reads them when it has nothing in memory:

- `addons/sourcemod/data/weapon_skins_cache.json` — purchased skins (`/api/skins`);
- `addons/sourcemod/data/weapon_skins_players_cache.json` — owned and equipped skins (`/api/players/skins`).

## Talking to the site

Two cvars, shared with `l4d2_gameinfo_sync`, configure the site: `l4d2_web_url` (set in `cfg/server.cfg`) and `l4d2_web_secret` (set in `cfg/server_secrets.cfg`, which is git-ignored).

| Call | When | Purpose |
|---|---|---|
| `GET {url}/api/skins` | configs executed, round start, round end, every 2 min with players | Which skins must be downloaded |
| `GET {url}/api/players/skins` | same | Who owns what and what is equipped |
| `GET {url}/api/players/{id}/wallet` | `!skin status` | Stars and balance |
| `POST {url}/api/players/{id}/skins/equip` with `Authorization: <l4d2_web_secret>` | a player changes skin in game | Save the equipped skin on the site |

```sourcepawn
void RefreshShop()
{
	...
	FormatEx(endpoint, sizeof(endpoint), "%s/api/skins", apiUrl);
	HTTPRequest skinsRequest = new HTTPRequest(endpoint);
	skinsRequest.Get(OnPurchasedSkinsResponse);

	FormatEx(endpoint, sizeof(endpoint), "%s/api/players/skins", apiUrl);
	HTTPRequest playersRequest = new HTTPRequest(endpoint);
	playersRequest.Get(OnPlayerSkinsResponse, GetEngineTime());
}
```

Responses with missing fields are rejected and the last valid data is kept.

### Not losing a change made in game

A player can change the skin in game while a refresh is in flight; the site could answer with the old value. Each in-game change records `GetEngineTime()`; each refresh records when it was requested. Until 15 s after the change (`LOCAL_CHANGE_GRACE`), the local choice wins:

```sourcepawn
if (requestedAt > changedAt + LOCAL_CHANGE_GRACE)
{
	g_hLocalChanges.Remove(key);   // the site already has it
	continue;
}
// keep the local value over the site's answer
```

### New purchase notice

When a refresh shows a skin that the previous data did not have, the owner (if connected) gets a chat message: *"Purchase received: X (weapon). It is already equipped and shows up from the next map change."* If another player had already bought that skin (its files are in this map), the plugin applies it right away and says so.

### Refunds

When a purchase is refunded (by an admin or at the end of the ranking season), the next refresh no longer lists that skin for the player: weapons tracked from then on use the default skin, and from the next map the skin's files are only downloaded if someone else still owns it. A weapon that already has the skin keeps it until it leaves the game.

## Applying a skin

A skin is applied by swapping the model to the weapon's **combined model** and setting `m_nSkin` to the skin's family (simplified):

```sourcepawn
void ApplyWorldModel(int weapon, WeaponSkin skin)
{
	if (!g_bWorldModelsEnabled) return;

	if (GetEntProp(weapon, Prop_Send, "m_nModelIndex") == skin.defaultWorldModelIndex)
		SetEntityModel(weapon, skin.worldModel);

	if (HasEntProp(weapon, Prop_Send, "m_iWorldModelIndex") && GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex") != skin.worldModelIndex)
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", skin.worldModelIndex);

	if (GetEntProp(weapon, Prop_Send, "m_nSkin") != skin.family)
		SetEntProp(weapon, Prop_Send, "m_nSkin", skin.family);
}
```

- **World model** (what others see, and the weapon on the ground): set on equip, on pick-up, and 0.1 s after a drop (the engine resets the model when the weapon is dropped). When a player takes a weapon from a spawn (`weapon_*_spawn`), the weapon in the slot of the spawned weapon (pistols and melee: secondary; everything else: primary) gets the stock world model back before the use and its skin again right after it.
- **View model** (first person): the player's `m_hViewModel` entity gets the combined view model and the family in `OnPostThinkPost`, every frame, only while the active weapon has a skin.
- **No flicker in first person**: the client predicts the weapon animations and, whenever one restarts, briefly draws the stock view model until the server update arrives, so a player with ping sees the stock weapon blink over the skin. The idle animation restarts about once a second, so while the active weapon of a human player shows a skin the plugin keeps the weapon's `m_flTimeWeaponIdle` at least 5 s in the future (`HoldWeaponIdle`). The idle animation never restarts and that blink is gone; the idle sequence itself loops on its own. A short blink can still show at the start of firing, since that animation is predicted too.
- **Restoring**: when a weapon loses its skin, the stock model and the weapon's original `m_nSkin` are put back.

### Which skin does a weapon get?

Each weapon entity remembers the skin it got when first tracked (`g_iWeaponSkin[weapon]`). **The skin follows the weapon**: if the owner drops it, whoever picks it up uses it with the owner's skin. The skin for a player's weapon is chosen like this:

```sourcepawn
int GetPlayerWeaponSkin(int client, int weapon)
{
	... // key = "<steamid64>:<weapon key>"
	if (g_hTestChoices.GetString(key, name, sizeof(name)))
		return FindReadySkin(name);                       // admin test

	if (!g_hPlayerChoices.GetString(key, name, sizeof(name)))
		return -1;                                        // nothing equipped

	if (!HasPreviewAccess(client) && !SteamIdOwnsSkin(steamId, name))
		return -1;                                        // not owned any more

	return FindReadySkin(name);                           // -1 if not in this map's downloads
}
```

Melee weapons share the `weapon_melee` class, so the weapon key is built from the script name: `weapon_melee_<m_strMapSetScriptName>` (for example `weapon_melee_fireaxe`).

## Players without downloads

A player with `cl_allowdownload 0` (or `cl_downloadfilter` other than `all`/`nosounds`) would see an `ERROR` model. The plugin queries both cvars as soon as the player starts connecting (`OnClientConnected`):

- `weapon_skins_kick_no_downloads 1` (the value set in `shared_cvars.cfg`) → while skins are on, the player is kicked. The kick message names the cvar with the wrong value and the console command that fixes it (`cl_allowdownload 1` or `cl_downloadfilter all`), and tells the player to check that cvar in `autoexec.cfg` or `config.cfg` if it keeps happening. Each kick is written to the SourceMod log with `LogMessage` (player name and SteamID, never the IP):

  ```text
  [l4d2_weapon_skins.smx] Kicked Player<12><STEAM_1:0:12345><> because cl_allowdownload is "0"
  ```

- `0` → the player stays and **world models go back to stock for everyone** while that player is in the server (view models still show for players who can see them, except to someone spectating them in first person).

> The game menu option *Options > Multiplayer > Custom Server Content > Allow All* only changes `cl_downloadfilter`. `cl_allowdownload` has no menu option: it can only be changed in the console or in a config file. That is why a player who picked "Allow all" in the menu can still be kicked, and why the message gives the exact console command.

## Weapon pile cleanup

Swapping weapons over and over at infinite safe-room spawns can pile up dropped weapons and lag the server. When a primary weapon is dropped, the plugin counts the dropped primary weapons within `weapon_skins_pile_radius` and removes the oldest ones above `weapon_skins_pile_max`. Spawns, map-placed weapons, secondary weapons and held weapons are never removed.

## Commands

| Command | Who | What it does |
|---|---|---|
| `!skin` / `!skins` | all | Help and the shop link |
| `!skin <id>` | all | Use one of your skins (only during ready-up, as a survivor) |
| `!skin next` / `!skin prev` `[weapon]` | all | Cycle through your skins of the weapon; after the last one, back to default |
| `!skin default [weapon]` | all | Back to the default skin |
| `!skin status` | all | Skins on/off, your stars and how many skins you own |
| `!skin on` / `!skin off` | root | Turn skins on/off for everyone (survives map changes) |
| `!skin test <id\|default> [weapon]` | root | Try a skin on yourself until the map changes |

`[weapon]` accepts `smg` (or `uzi`), `mac` (or `mac10`, `mac-10`, `silenced`), `mp5`, `pump`, `chrome`, `magnum` (or `deagle`), `axe` (or `fireaxe`), `bat`, `cricket`, `guitar`, `golf`, `pan`, any other melee script name (`katana`, `machete`, `crowbar`) and the full keys (`weapon_smg`, `weapon_melee_katana`, …).

## Cvars

| Cvar | Default | Purpose |
|---|---|---|
| `weapon_skins_enabled` | `0` | Master switch (set to `1` in `shared_cvars.cfg`) |
| `l4d2_web_url` | `""` | Site URL, shared with `l4d2_gameinfo_sync` |
| `l4d2_web_secret` | `""` | Site secret, shared with `l4d2_gameinfo_sync` |
| `weapon_skins_kick_no_downloads` | `0` | Kick players without downloads (set to `1` in `shared_cvars.cfg`) |
| `weapon_skins_pile_radius` / `weapon_skins_pile_max` | `120` / `3` | Weapon pile cleanup (`weapon_skins_pile_max 0` turns it off) |
| `weapon_skins_preview_all` | `0` | Test mode: every skin downloaded and usable by root admins |
