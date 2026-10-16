# Weapon Skins & Skin Shop — Wiki

🌐 **English** | [Português](README.pt.md)

This wiki explains, end to end, how the weapon skins of the **l4d2.com.br** server work: how the skin files are built and delivered, how the game server applies them, how players earn **stars** (MVPs) and spend them in the **skin shop**, and how admins manage everything. It is written for people who want to study the system, maintain it or extend it.

## Pages

| # | Page | What it covers |
|---|---|---|
| 1 | [Overview & architecture](01-overview.md) | The five repositories, how they talk to each other and the life of a purchase |
| 2 | [Skin assets](02-assets.md) | Texture-only skins, combined models with one skin family per skin, the assets repository, FastDL and how to add a new skin |
| 3 | [Game server plugin](03-game-plugin.md) | `l4d2_weapon_skins.sp`: downloads table, applying skins to view/world models, commands, caching, syncing with the site |
| 4 | [Stars (PlayStats API)](04-stars-api.md) | How all-time MVPs become stars, how they are computed and cached |
| 5 | [Skin shop (PlayStats web)](05-skin-shop.md) | Catalog, rarities and prices, Table Storage design, the purchase transaction, security, admin pages |
| 6 | [Operations & runbooks](06-operations.md) | Configuration and secrets, deployments, restarting the server, common tasks, troubleshooting and testing |

## The system in one paragraph

Each skinnable weapon (SMG, MAC-10, MP5, pump shotgun, chrome shotgun and nine melee weapons) has **one combined model** that contains every skin of that weapon as a separate *skin family*. Players earn **1 star per MVP** (SI damage or common infected) in competitive matches, counted over the whole history of the ranking. They buy skins on **l4d2.com.br/skins**; the purchase is stored in Azure Table Storage and the skin is equipped right away. The game server plugin reads which skins were bought and who owns what, adds **only the purchased skins** to the FastDL downloads table at map start, and swaps the weapon model and `m_nSkin` so the owner (and everyone around) sees the skin. A skin bought during a map shows up from the **next map change**.

## Repositories

| Repository | Role |
|---|---|
| [l4d2-zone-server](https://github.com/altair-sossai/l4d2-zone-server) | SourceMod plugins (including `l4d2_weapon_skins` and `l4d2_gameinfo_sync`), configs, docs and this wiki |
| [l4d2-zone-server-assets](https://github.com/altair-sossai/l4d2-zone-server-assets) | Models and materials of the skins, deployed to the game server and to the FastDL blob |
| l4d2-playstats-api | Azure Functions API that stores match statistics, builds the ranking and serves the **stars** |
| l4d2-playstats-web | The **l4d2.com.br** site: skin shop, admin pages and the API used by the plugin |
| l4d2-anti-cheat-client | The anti-cheat client, which keeps a manifest of the server assets |

> Secrets (tokens, keys, passwords) never appear in this wiki. Where a secret is needed, the page tells you **where** it is configured, never its value.
