# 6. Operations & runbooks

🌐 **English** | [Português](06-operations.pt.md) | [Español](06-operations.es.md) · [Wiki home](README.md)

## Configuration and secrets

> Values of secrets are never written in repositories, docs or chat. This page only says **where** each one lives.

### Game server

| Setting | File | Versioned? |
|---|---|---|
| `l4d2_web_url` (site URL, shared by `l4d2_weapon_skins` and `l4d2_gameinfo_sync`) | `cfg/server.cfg` | yes |
| `l4d2_web_secret` (= the site `SecretKey`) | `cfg/server_secrets.cfg` | **no** (git-ignored, exists only on the server) |
| `weapon_skins_enabled`, `weapon_skins_kick_no_downloads`, pile settings | `cfg/cfgogl/{zonemod,neomod}/shared_cvars.cfg` | yes |
| `sv_downloadurl` (FastDL) | `cfg/server.cfg` | yes |

`cfg/server.cfg` runs `exec server_secrets.cfg` at the top, so the secrets are loaded on every map start.

### Site (`appsettings.json`, only on the web host)

| Key | Purpose |
|---|---|
| `AzureWebJobsStorage` | Storage account (tables `SkinShop`, `SkinPrices`, `ChatBans`, …) |
| `PlayStatsApiUrl`, `ServerId`, `PlayStatsSecret` | Calls to the PlayStats API (stars, ranking) |
| `SecretKey` | Shared secret checked by `[RequiredSecretKey]` (game server → site) |
| `ServerAdmins` | SteamID64 list of admins (`;`-separated) |
| `SteamApiKey` | Steam Web API (names and avatars) |

### API (Azure Functions app settings)

`AzureWebJobsStorage` — the same storage account. The `Statistics` table is the source of the ranking and the stars: **never delete or edit it**.

## Deployments

| Repository | Trigger | What happens |
|---|---|---|
| l4d2-zone-server | push to `master` (changes only to `docs/` or `*.md` files do not trigger it) | `addons/`, `cfg/`, `bash/`, `scripts/` are packed and extracted into the game folder. `server_secrets.cfg` is not touched |
| l4d2-zone-server-assets | push to `main` | `models/` and `materials/` go to the game folder and to the FastDL blob; `fastdl/` and `assets/` go to blobs |
| l4d2-playstats-api | push to `main` | Build, tests and the `function` build artifact that is published to the Azure Functions app |
| l4d2-playstats-web | push to `main` | Self-contained publish, copied to the web host and restarted in the `l4d2-playstats-web` screen session |
| l4d2-anti-cheat-client | push to `main` | Build, tests and a signed client package uploaded to blob storage; players get the new version (with the new server assets manifest) when the version number changes |

**Order when a change spans repositories:** API → site → zone-server. The plugin depends on site endpoints, and the site depends on the API. When skin files change, the anti-cheat client and the assets come first: see the next section.

**Plugins and configs** only take effect after the server reloads them: restart the game server after a zone-server deploy that changes plugins.

### When the combined models change

Adding, removing or changing a skin changes the combined models and the skin files. Follow this order:

1. **Anti-cheat client** — publish the new client (new server assets manifest + version bump) and make sure it is available to players.
2. **Assets** — push the assets repository (game folder + FastDL).
3. **Site** — push the catalog (`skins.json`) and the thumbnails.
4. **Zone-server** — push `weapon_skins.cfg` (family indexes).
5. **Restart the game server while it is empty** (see below).

Why: the anti-cheat verifies the server-sent skin files against its manifest, so a player whose client still has the old manifest and downloads the new model is kicked. And a changed model must be downloaded on connect, not on a map change, which is why the server is restarted.

## Restarting the game server

1. Check that nobody is playing: send `status` to the `27015` screen session and read the player count.
2. Restart with the server scripts only: `bash/stop.sh 27015`, wait a few seconds, `bash/start.sh 27015 c2m1_highway`.
3. Check `sm plugins info l4d2_weapon_skins` (status `running`) and the SourceMod error log of the day.

> Do **not** run the bootstrap or firewall scripts remotely: they can lock the SSH session out.

## Common tasks

| Task | How |
|---|---|
| Change a skin price | Admin → Skin prices → click the skin → change → Save (or Reset to default). Applies to new purchases only |
| Refund a purchase | Admin → Skin purchases → click the purchase → *Refund purchase* → *Confirm refund*. Stars go back; the skin is unequipped |
| Refund everything | Admin tool for exceptional cases (for example, after recalculating prices). Admin → Skin purchases → *Refund everything* → tick the confirmation → *Refund everything*. Every purchase **and every gift** of every player is refunded (same rules as a single refund); players' stars do not change, only what was spent goes back. It cannot be undone. If some items fail, run it again |
| Season refund | Automatic at the ranking reset (00:00 UTC on the 1st of Jan, Mar, May, Jul, Sep and Nov = 21:00 the day before in Brasília). Look for `Skin purchases made before the season of ... refunded` in the site log. Gifts are kept. Nothing to do; if the site was down at the reset, it catches up within 10 minutes of starting |
| Give a skin | Admin → Skin purchases → *Give a skin* (or from the price modal, or from the shop's skin details). Pick the player and the skin. Gifts are never refunded by the season refund |
| Ban a player from the chat | Admin → Chat bans → *Add ban* → pick from recent senders or *Choose from the list* |
| Try every skin in game | `!cvar weapon_skins_preview_all 1`, change the map, reconnect; root admins can use any skin. Turn it off and change the map afterwards (every player who connects meanwhile downloads all skins, ~300 MB) |
| Add a new skin | See [Skin assets → Adding a new skin](02-assets.md#adding-a-new-skin-checklist) |
| Rotate the shared secret | Change `SecretKey` on the site **and** `l4d2_web_secret` in `server_secrets.cfg` to the same new value, then restart the site and the game server |

## Troubleshooting

| Symptom | Likely cause | What to do |
|---|---|---|
| Bought skin does not show | It only shows from the next map change | Change map; check `/api/skins` lists it |
| A player's skins disappeared at the start of a month | Season refund at the ranking reset | Expected: the stars came back and the player can buy again. Gifts are kept |
| Weapon shows `ERROR` | Models were downloaded during a map change | Restart the game; models are meant to be downloaded on connect |
| Skin shows for some players only | A player has downloads off and `weapon_skins_kick_no_downloads` is `0` | Turn the kick on, or ask the player to enable downloads |
| Player kicked for downloads although "Allow all" is set in the menu | `cl_allowdownload` is `0` (it has no menu option) | The kick message gives the command: `cl_allowdownload 1` in the console, and remove `cl_allowdownload 0` from `autoexec.cfg`/`config.cfg`. Kicks are in the SourceMod log (`Kicked ... because ...`) |
| Players kicked by the anti-cheat right after a skin deploy | The assets were deployed before the anti-cheat client with the new manifest | Publish the new client; see [When the combined models change](#when-the-combined-models-change) |
| "We could not load your stars" in the shop | The site could not reach the API | Check the API; purchases are blocked until it answers |
| New MVPs not counted yet | API cache (up to 1 h) | Wait; the next upload clears the cache on that instance |
| First map after a restart downloads skins nobody bought | Old `weapon_skins_cache.json` from another version | Delete the cache files in `addons/sourcemod/data/` and restart |
| Chat/game info stopped reaching the site | `l4d2_web_url`/`l4d2_web_secret` missing or different from `SecretKey` | Check `server.cfg`, `server_secrets.cfg` and the site's `SecretKey` |

## Testing

- **Shop service** — during development, integration tests ran the real `SkinShopService` and repositories against **Azurite** (the local Azure Storage emulator), with a fake stars service: purchase, duplicate purchase, insufficient stars, API down, concurrent purchases, equip/unequip, gift, refund, price overrides. The test project is not versioned; test shop changes against Azurite, never against production tables.
- **Site locally** — run the web app with a separate content root whose `appsettings.json` points `AzureWebJobsStorage` to `UseDevelopmentStorage=true`, so nothing touches production tables. Keep in mind that the season refund runs on startup: purchases in Azurite dated before the current season are refunded.
- **Stars** — compare `/api/stars` with the stored all-time ranking plus the current period.
- **Plugin** — compile with the bundled `spcomp` ([`addons/sourcemod/scripting/sourcemod/spcomp.exe`](../../addons/sourcemod/scripting/sourcemod/spcomp.exe)) and test on the server, ideally with nobody playing.
