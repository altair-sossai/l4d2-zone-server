# Weapon skins

🌐 **English** | [Português](README.pt.md) | [Español](README.es.md)

This folder covers the part of the weapon skins that belongs to the game server and its assets: how the skin files are built, the combined models, FastDL, the credits and how to add a skin. It is part of the [server documentation](../README.md).

## Pages

| Page | What it covers |
|---|---|
| [Skin assets](02-assets.md) | Texture-only skins, combined models with one skin family per skin, the assets repository, FastDL, credits, adding a skin, the anti-cheat manifest, the deploy order and restarting the game server |

## Shop, stars and plugin

The skin shop, the stars, the purchases, gifts and refunds, and the `l4d2_weapon_skins` plugin with its `weapon_skins.cfg` are part of [l4d2-playstats-hub](https://github.com/altair-sossai/l4d2-playstats-hub), the project that runs l4d2.com.br:

- [Weapon skin shop](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/skin-shop.md) — stars, the shop page, purchases, equipping, refunds at the end of a season, gifts and the admin pages.
- [Connecting a game server](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/game-server.md) — the plugins, their ConVars and commands.
- [Plugins folder](https://github.com/altair-sossai/l4d2-playstats-hub/tree/main/plugins) — sources, compiled plugins and `weapon_skins.cfg`.

The pipeline of this repository copies the plugins and `weapon_skins.cfg` of the latest hub release to the game server. See [Custom plugins → Statistics plugins](../plugins/README.md#statistics-plugins-l4d2-playstats-hub).

## Repositories

| Repository | Role |
|---|---|
| [l4d2-zone-server](https://github.com/altair-sossai/l4d2-zone-server) | Configs of the game server, including the per-mode `weapon_skins_*` ConVars and the stripper filters |
| [l4d2-zone-server-assets](https://github.com/altair-sossai/l4d2-zone-server-assets) | Models and materials of the skins, deployed to the game server and to the FastDL blob; its README credits the author of every skin |
| [l4d2-playstats-hub](https://github.com/altair-sossai/l4d2-playstats-hub) | The l4d2.com.br site with the skin shop, the skin catalog and thumbnails, and the `l4d2_weapon_skins` plugin |
| l4d2-anti-cheat-client | The anti-cheat client, which verifies the server-sent skin files against a manifest |
