# 2. Skin assets

🌐 **English** | [Português](02-assets.pt.md) | [Español](02-assets.es.md) · [Wiki home](README.md)

## Texture-only skins

Every skin comes from a **texture-only** Steam Workshop addon: it replaces the textures (`.vtf`) and materials (`.vmt`) of a stock weapon but keeps the stock geometry. Addons that replace the gun model, and addons made for another addon's custom model, were rejected, because:

- a texture-only skin fits the stock model layout, so all skins of a weapon can live in **one combined model**;
- players never need to install `.vpk` files: everything is delivered through FastDL.

The catalog has **196 skins** for 15 weapons (number of skins in parentheses):

| Firearms | Melee (`weapon_melee_<script>`) |
|---|---|
| `weapon_smg` (8), `weapon_smg_silenced` (MAC-10, 30), `weapon_smg_mp5` (20), `weapon_pumpshotgun` (33), `weapon_shotgun_chrome` (34), `weapon_pistol_magnum` (Magnum / Desert Eagle, 26) | `fireaxe` (15), `katana` (7), `machete` (5), `baseball_bat` (4), `cricket_bat` (3), `electric_guitar` (6), `crowbar` (2), `golfclub` (2), `frying_pan` (1) |

The largest combined model is the chrome shotgun's, with 34 skin families.

## Folder layout (assets repository)

```
models/l4d2br/weapons/<weapon>/            ← one combined model per weapon
    v.mdl  v.vvd  v.dx90.vtx                 view model (first person)
    w.mdl  w.vvd  w.dx90.vtx                 world model (third person / ground)
materials/models/l4d2br/weapons/<weapon>_<workshopId>/   ← one folder per skin
    *.vmt  *.vtf
```

`<weapon>` is the weapon key without the `weapon_` prefix: `smg_silenced`, `pistol_magnum`, `melee_katana`, …

Example — the **Dark Matter** MAC-10 skin:

```
materials/models/l4d2br/weapons/smg_silenced_3377651383/
    smg_a.vmt   smg_a.vtf   smg_a_nrm.vtf   smg_a_worn.vmt
```

```text
VertexLitGeneric
{
$baseTexture "models/l4d2br/weapons/smg_silenced_3377651383/smg_a"
$bumpmap "models/l4d2br/weapons/smg_silenced_3377651383/smg_a_nrm"
...
}
```

Every texture the addon brings lives in the skin's own folder. Textures the addon does not replace (for example the `$phongexponenttexture` or the texture of the worn variant) still point to the game's stock textures, which players already have. So skins never overwrite stock files or each other.

## Combined models and skin families

A Source `.mdl` has a **texture table** and a **skin family table**. Each family is a row that says which texture to use for every material slot of the model. `m_nSkin` on an entity selects the row.

The combined model of a weapon is the **stock model** with those two tables rebuilt:

- the texture table lists the textures of **every skin** of the weapon (`<folder>/<texture>`), with the material search path `models\l4d2br\weapons\`, and the stock textures of the weapon at the end;
- the first families are the **original** families of the weapon (`stock_skins`, see [below](#original-families-of-the-weapons)), and family `stock_skins + i` points every material slot to the textures of skin `i`.

A real example: the MAC-10 `v.mdl` has 2 material slots, 62 textures and 32 families (2 original + 30 skins):

| Family | Slot 0 | Slot 1 | What it is |
|---|---|---|---|
| 0 | `models/v_models/weapons/smg/smg_A` | `smg_a_worn` | Stock MAC-10 |
| 1 | `smg_a_worn` | `smg_a_worn` | Stock worn MAC-10 |
| 2 | `smg_silenced_2926162402/smg_a` | `smg_silenced_2926162402/smg_a_worn` | printstream-mac |
| 3 | `smg_silenced_3377651383/smg_a` | `smg_silenced_3377651383/smg_a_worn` | dark-matter |
| 4 | `smg_silenced_1883809532/smg_a` | `smg_silenced_1883809532/smg_a_worn` | urban |
| … | | | |

```mermaid
flowchart LR
    M["v.mdl (MAC-10)"] --> S0["family 0 → stock MAC-10"]
    M --> S1["family 1 → stock worn MAC-10"]
    M --> F2["family 2 → printstream-mac textures"]
    M --> F3["family 3 → dark-matter textures"]
    M --> FN["family N → …"]
```

Changing the skin of a weapon only changes its `m_nSkin`: the model stays the same.

Geometry files (`.vvd`, `.dx90.vtx`) are copied from the stock model unchanged. The build steps are:

1. **Extract & relocate** — read the workshop `.vpk`, take the materials that the addon overrides for the weapon, move them to `materials/models/l4d2br/weapons/<weapon>_<workshopId>/` and rewrite the paths inside each `.vmt`.
2. **Optimize textures** — re-encode large `.vtf` files to at most **1024 px**, convert uncompressed textures (`BGR888`/`BGRA8888`) to DXT1 (no alpha) or DXT5 (alpha), and generate mipmaps for textures that have none. This keeps skin downloads small: most skins are 0.5–2 MB, the largest about 14 MB.
3. **Store identical textures once** — when several textures inside the same skin folder are identical, keep one copy and point the `.vmt` files to it. Skins never share files with other skins, so removing one skin never breaks another.
4. **Build the combined model** — patch the stock `.mdl`: rename it, append the texture table, the material search path and the family table, and update the header fields (`numtextures`, `textureindex`, `numcdtextures`, `cdtextureindex`, `numskinfamilies`, `skinindex`, `length`).

The heart of step 4 (PowerShell, simplified):

```powershell
foreach ($skin in $skins)                      # skins of this weapon, in cfg order
{
    $offset = $names.Count
    foreach ($t in $built.Textures) { $names.Add("$($skin.Folder)/$t") }
    foreach ($r in $built.Skins[0]) { $table.Add($offset + $r) }   # one family per skin
}
...
& $wr 204 $names.Count      # numtextures
& $wr 208 $textureArray     # textureindex
& $wr 212 1                 # numcdtextures  ("models\l4d2br\weapons\")
& $wr 216 $cdArray          # cdtextureindex
& $wr 224 $skins.Count      # numskinfamilies
& $wr 228 $skinTable        # skinindex
& $wr 76 $b.Count           # file length
```

This step builds only the skin families. The original families are added afterwards, at the start of the table, by `scripts/add-stock-families.js` (see below).

> ⚠️ **The family index is the position of the skin inside its weapon in `weapon_skins.cfg`** (plus the original families of the weapon, see below). Adding, removing or reordering skins of a weapon means rebuilding that weapon's combined models and updating the `"skin"` values in the cfg.

### Original families of the weapons

The combined models (`v.mdl` and `w.mdl`) of every weapon with skins (the six firearms and the nine melee weapons) start with the **families of the stock model**, and only then the skins:

| Weapon | `stock_skins` | First skin family |
|---|---|---|
| SMG, MAC-10, pump shotgun, chrome shotgun | 2 (normal and worn) | 2 |
| MP5 | 1 | 1 |
| Magnum | 3 | 3 |
| Cricket bat, crowbar | 2 | 2 |
| Baseball bat, electric guitar, fireaxe, frying pan, golf club, katana, machete | 1 | 1 |

Those families point to the textures of the stock model (their names and material search paths are appended to the texture table), so family `0` of a combined model looks exactly like the stock weapon. This is what lets first person always use the combined model: a weapon without a skin keeps its original `m_nSkin`, and the anti-cheat client can point the game at the combined model to stop the flicker on animation changes (see [Game plugin](03-game-plugin.md)).

They are added by [`scripts/add-stock-families.js`](https://github.com/altair-sossai/l4d2-zone-server-assets/blob/main/scripts/add-stock-families.js) in the assets repository, which reads the stock models from the game VPKs (`update/` first) and rewrites the combined view and world models of every weapon. Run it after rebuilding the combined models of a weapon; a model that already has them is skipped, and with `check` at the end the script only prints what would change:

```bash
node scripts/add-stock-families.js "<Left 4 Dead 2 folder>" <zone-server>/addons/sourcemod/configs/weapon_skins.cfg [check]
```

The `"skin"` value of a skin is therefore `stock_skins` + its position inside the weapon (starting at 0). On the MAC-10 (`stock_skins` 2): printstream-mac, the first one, is `2`; dark-matter, the second one, is `3`.

## The cfg that ties it together

[`addons/sourcemod/configs/weapon_skins.cfg`](../../addons/sourcemod/configs/weapon_skins.cfg) (zone-server repository):

```text
"WeaponSkins"
{
	"Weapons"
	{
		"weapon_smg_silenced"
		{
			"view_model"			"models/l4d2br/weapons/smg_silenced/v.mdl"
			"world_model"			"models/l4d2br/weapons/smg_silenced/w.mdl"
			"default_view_model"	"models/v_models/v_silenced_smg.mdl"
			"default_world_model"	"models/w_models/weapons/w_smg_a.mdl"
			"models"				"models/l4d2br/weapons/smg_silenced"
			"stock_skins"			"2"
		}
		...
	}
	"Skins"
	{
		"dark-matter" // https://steamcommunity.com/sharedfiles/filedetails/?id=3377651383
		{
			"weapon"		"weapon_smg_silenced"
			"skin"		"3"
			"materials"	"materials/models/l4d2br/weapons/smg_silenced_3377651383"
		}
		...
	}
}
```

- `Weapons` — combined models, the stock models to restore, the model folder sent through FastDL and `stock_skins` (number of original families at the start of the combined models).
- `Skins` — the skin id (the same id used by the site and by `!skin <id>`), its weapon, family index and materials folder.

## Delivery: game server + FastDL

The assets repository pipeline (`azure-pipelines.yml`, runs on every push to `main`):

1. packs `models/` and `materials/` into `.tar.gz` files;
2. uploads them over SSH and extracts them into the game folder (`left4dead2/models`, `left4dead2/materials`) — the server needs the files because the plugin precaches models and lists files in the downloads table;
3. syncs to the `l4d2playstats` storage account with `scripts/sync-blob.sh`, which uploads only new or changed files: `models/` and `materials/` to the `fastdl` container (under `models/` and `materials/`), `fastdl/` to the root of the `fastdl` container, and `assets/skin-shots/` (the skin photos of the shop, with a one-year cache) and the rest of `assets/` to the `assets` container.

The copy to the server sends every file on every run. Neither step deletes anything: a file removed from the repository must also be removed by hand from the game folder and from the storage.

Clients download from `sv_downloadurl` (the `fastdl` container). Files are served **uncompressed** (no `.bz2`).

## Credits

Every skin was made by the Left 4 Dead 2 community and published on the Steam Workshop. The README of the assets repository has a [Weapon skin credits](https://github.com/altair-sossai/l4d2-zone-server-assets#weapon-skin-credits) section with one table per weapon (skin, author and Workshop link) and the list of authors: 196 skins from 83 authors. One Magnum skin, *Desert Eagle Retrowave / Synthwave*, is licensed by its author under CC BY-NC 3.0, and the credits say so. The shop page also tells players that the skins come from the Workshop and links each skin to its original page.

## Adding a new skin (checklist)

1. Pick a **texture-only** workshop addon and confirm it targets the stock model of one of the 15 weapons. Addons that replace the gun model, or that are made for another addon's custom model, do not fit the combined model.
2. Read the addon's Workshop description: if the author asks not to redistribute or re-upload the work, **do not add it** (commissioned items, marked "[COMMS]", usually ask this). Five skins were removed from the catalog for this reason.
3. Extract, relocate and optimize its materials into `materials/models/l4d2br/weapons/<weapon>_<workshopId>/`: at most 1024 px, DXT1/DXT5 instead of uncompressed formats, mipmaps, and one copy of each identical texture.
4. Add the skin to `weapon_skins.cfg` (id, weapon, materials) and **rebuild the combined models** of that weapon (then run `scripts/add-stock-families.js`); set the `"skin"` family indexes (`stock_skins` + position).
5. Add the skin to the site catalog `skins.json` (id, weapon, rarity, price, `workshopId`, `shots`, `author`, titles/descriptions in en/pt/es) and its thumbnail `wwwroot/imgs/skins/<id>.jpg`. See [Skin shop → Catalog](05-skin-shop.md#catalog-skinsjson).
6. In the assets repository, add the photos in `assets/skin-shots/<id>/` (30 files: six photos in AVIF and WebP, at full size, `-thumb` and, for photos 1, 5 and 6, `-card`; see the assets README) and the skin to the credits table of its weapon (skin, author, Workshop link), updating the count in the weapon heading and the list of authors.
7. Regenerate the anti-cheat server assets manifest (see below) and bump the client version.
8. Deploy in this order: anti-cheat client → assets → site → zone-server, then restart the game server while it is empty. See [Operations → When the combined models change](06-operations.md#when-the-combined-models-change).

> The scripts used for steps 3–4 were run locally during development and are **not versioned** in any repository yet.

## Anti-cheat manifest

The anti-cheat client verifies the files the server sends through FastDL (skins, decals, sprites: everything published from `fastdl/`, `models/` and `materials/` of the assets repository) against a manifest (`Manifest/server-assets-manifest.json` in the l4d2-anti-cheat-client repository). Whenever skin files are added or changed, regenerate it from a checkout of the assets repository and publish a new client version:

```bash
dotnet run --project tools/L4D2AntiCheat.ManifestGenerator -- server-assets <path-to-l4d2-zone-server-assets>
```

Generate it from files with **LF** line endings: the assets repository normalizes text files (`.vmt`) to LF, and that is what the server and FastDL receive.

The new client must be published **before** the assets: a player whose client still has the old manifest and downloads the new files is kicked by the anti-cheat.
