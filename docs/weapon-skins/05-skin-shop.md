# 5. Skin shop (PlayStats web)

🌐 **English** | [Português](05-skin-shop.pt.md) | [Español](05-skin-shop.es.md) · [Wiki home](README.md)

**Repository:** l4d2-playstats-web (ASP.NET Core MVC, Bootstrap 3) · **Core module:** `L4D2PlayStats.Core/Skins`

## Catalog: `skins.json`

The catalog is an embedded resource (`L4D2PlayStats.Core/Skins/Data/skins.json`), versioned with the code. The file is an object with a `skins` array, sorted by rarity, then price (highest first), so it is easy to read; the shop sorts again on screen (price, weapon, title). One entry:

```json
{
  "id": "dark-matter",
  "weapon": "weapon_smg_silenced",
  "rarity": "legendary",
  "price": 625,
  "workshopId": "3377651383",
  "shots": 2,
  "author": { "name": "BATTLE NO.1", "communityId": "76561199147992281" },
  "title": { "en": "MAC-10 Dark Matter", "pt": "MAC-10 Dark Matter", "es": "MAC-10 Dark Matter" },
  "description": { "en": "...", "pt": "...", "es": "..." },
  "originalTitle": "MAC-10 DARK MATTER",
  "originalDescription": "..."
}
```

- `id` is the same id used in `weapon_skins.cfg` and by `!skin <id>`.
- The thumbnail is `wwwroot/imgs/skins/<id>.jpg`.
- `workshopId` links the skin to its original Workshop page (the *View on Workshop* button).
- `shots` turns on the in-game photos of the skin: with `0` the shop shows only the thumbnail; with `1` or more it loads the photos from `<SkinShotsUrl>/<id>/` (the photos live in `assets/skin-shots/<id>/` in the assets repository). The number is also the cache version of the photos: they are served with a one-year cache, so redoing the photos of a skin means raising its `shots`.
- `author` is the Workshop author of the skin (name and SteamID64), shown on the cards, in the details and in the **Authors** tab.

### Rarities and prices

Every skin was reviewed by looking at its images and given a rarity and an individual price inside the rarity's range:

| Rarity | Skins | Price range (stars) |
|---|---|---|
| Legendary | 9 | 470–630 |
| Epic | 28 | 270–400 |
| Rare | 58 | 135–210 |
| Uncommon | 56 | 65–110 |
| Common | 45 | 25–50 |

The 196 skins of the catalog cost **30,590 stars** together (default prices) — more than all the stars of every player together when the shop opened (about 24,750) — so owning every skin in one season is meant to be close to impossible. In the shop, the header of each rarity shows how many skins it has and the price range computed from the current prices.

### Price overrides

Admins can change a price without a deploy. The override lives in the `SkinPrices` table (PartitionKey `SkinPrice`, RowKey = skin id) and wins over the catalog price:

```csharp
public record Skin
{
    [JsonPropertyName("price")] public int DefaultPrice { get; init; }
    [JsonIgnore] public int? CustomPrice { get; init; }
    [JsonIgnore] public int Price => CustomPrice ?? DefaultPrice;
    ...
}
```

The row stores `Price`, `UpdatedByCommunityId` and `UpdatedAtUtc`. Saving the default price again (or "Reset to default") deletes the override. Purchases store the price actually paid, so changing a price never affects past purchases (and a refund always gives back what was paid).

## Storage: the `SkinShop` table

One partition per player (`PartitionKey` = SteamID64). Three kinds of rows:

| RowKey | Entity | Fields |
|---|---|---|
| `Wallet` | `SkinWalletEntity` | `Spent`, `UpdatedAtUtc` (+ ETag) |
| `Owned_<skinId>` | `SkinPurchaseEntity` | `SkinId`, `Weapon`, `Price`, `StarsBefore`, `Gift`, `PlayerName`, `GiftedByCommunityId`, `GiftedByName`, `PurchasedAtUtc` |
| `Equipped_<weapon>` | `SkinEquipmentEntity` | `Weapon`, `SkinId`, `Source` (`shop`, `site`, `game`, `gift`), `UpdatedAtUtc` |

Keeping all of a player's rows in one partition is what makes the purchase transaction possible: Azure Table Storage only supports transactions inside a single partition.

The **balance** is always computed, never stored:

```csharp
public int Balance => Math.Max(0, Stars - Spent);   // Stars come from the API
```

**Memory cache:** the list of every purchase and every equipped skin stays 5 minutes in memory and is cleared after every transaction. It backs `/api/skins`, `/api/players/skins`, the admin purchases page and the season refund. Price overrides (`SkinPrices`) stay 12 hours in memory, and that cache is cleared when a price is saved or reset.

## The purchase transaction

`SkinShopService.BuyAsync(communityId, playerName, skinId)` — the front end sends only the skin id; everything else is decided on the server.

```csharp
var skin = await skinService.FindAsync(skinId);           // catalog + price override
if (skin == null) return SkinNotFound;
if (await repository.FindPurchaseAsync(communityId, skin.Id) != null) return AlreadyOwned;

var stars = await GetStarsAsync(communityId);              // fresh, from the API
if (stars == null) return StarsUnavailable;                // fail closed

for (var attempt = 1; attempt <= 3; attempt++)
{
    var wallet = await repository.FindWalletAsync(communityId) ?? new SkinWalletEntity { PartitionKey = communityId };
    var balance = stars.Stars - wallet.Spent;
    if (balance < skin.Price) return InsufficientStars;

    var walletAction = wallet.ETag == default
        ? new TableTransactionAction(TableTransactionActionType.Add, wallet)
        : new TableTransactionAction(TableTransactionActionType.UpdateReplace, wallet, wallet.ETag);

    wallet.Spent += skin.Price;

    var actions = new List<TableTransactionAction>
    {
        new(TableTransactionActionType.Add, purchase),           // fails if already owned
        walletAction,                                             // fails if the wallet changed
        new(TableTransactionActionType.UpsertReplace, equipment)  // equipped right away
    };

    try { await repository.SubmitAsync(actions); }
    catch (TableTransactionFailedException e) when (e.FailedTransactionActionIndex == 0 && e.Status == 409)
    { return AlreadyOwned; }
    catch (TableTransactionFailedException e) when (e.FailedTransactionActionIndex == 1 && e.Status is 409 or 412)
    { continue; }   // someone else changed the wallet: read it again and retry

    return Success;
}
return Busy;
```

What this guarantees:

| Risk | Protection |
|---|---|
| Buying the same skin twice | The purchase row is an `Add`: a second one fails with 409 |
| Purchase without debit (or debit without purchase) | Purchase, wallet and equipment are written in **one** transaction: all or nothing |
| Two purchases at the same time spending the same stars | The wallet update is conditional on its ETag; the loser re-reads and re-checks the balance |
| Forged price or balance from the browser | The request carries only the skin id; price comes from the catalog, stars from the API |
| API down | Purchases are refused (`StarsUnavailable`), never assumed |

During development these cases were covered by integration tests run against Azurite, including 20 parallel purchases of the same skin (exactly one succeeds) and parallel purchases of different skins (never spending more than the balance). The test project is not versioned in the repository.

### Equip, gift, refund

- **Equip / unequip** — checks ownership (or that the weapon exists) and upserts/deletes the `Equipped_<weapon>` row.
- **Gift** (admin) — adds a purchase with `Price = 0`, `Gift = true`, the admin's id and name, and equips it. Stars are not touched. Gifts are never refunded by the season refund.
- **Refund** (admin) — in one transaction: deletes the purchase, subtracts its price from `Spent` and removes the equipment row if that skin was equipped. Retries on ETag conflicts.
- **Season refund** (automatic) — skins are bought per ranking season (two months, in UTC: Jan–Feb, Mar–Apr, …; the reset is at 00:00 UTC on the 1st of Jan, Mar, May, Jul, Sep and Nov, which is 21:00 of the previous day in Brasília). `SkinSeason.Current` gives the season's start, end, last day and days left. The `SkinSeasonRefundBackgroundService` runs when the site starts and every 10 minutes and calls `SkinShopService.RefundSeasonAsync(SkinSeason.Current.Start)`: every purchase that is **not a gift** and was made before the current season started is refunded with the same rules as an admin refund — the stars spent come back, the skin leaves the account and its equipment row is removed. The purchase is checked again right before it is deleted, so a skin bought again in the new season is never touched. Gifts stay forever. The run is idempotent, so a missed run (site down at the reset) is caught up on the next one; when something was refunded it logs `Skin purchases made before the season of … refunded` with the totals.
- **Refund everything** (admin tool) — `RefundAllAsync` refunds every purchase **and every gift** of every player with the same rules as a single refund. Like the season refund, it works player by player (up to 8 players in parallel, one purchase at a time per player) and returns the totals and the number of failures.

## Endpoints

### Used by the site (cookie authentication + antiforgery token)

| Method | Route | Who |
|---|---|---|
| GET | `/api/shop/wallet` | logged-in player (cookie only) — `{balance, stars, spent}`, or 503 when the stars cannot be loaded; used by the stars counter in the navbar |
| POST | `/api/shop/skins/{skinId}/buy` | logged-in player |
| POST | `/api/shop/skins/{skinId}/equip` | logged-in player |
| POST | `/api/shop/weapons/{weapon}/unequip` | logged-in player |
| POST | `/api/shop/skins/{skinId}/price` `{price}` | admin (1–100,000; `null` resets) — `{price, defaultPrice, custom}` |
| POST | `/api/shop/gift` `{communityId, skinId}` | admin (`STEAM_x:y:z`, `[U:1:x]`, SteamID64 or a `steamcommunity.com/profiles/<id>` link; `/id/<name>` links are not accepted) |
| POST | `/api/shop/refund` `{communityId, skinId}` | admin |
| POST | `/api/shop/refund-all` | admin — refunds every purchase and gift: `{purchases, gifts, stars, players, failed}` |
| GET | `/api/admin/players` | admin — players for the player picker |

### Used by the game plugin

| Method | Route | Auth |
|---|---|---|
| GET | `/api/skins` | none — skins bought by at least one player: `[{id, weapon}]` |
| GET | `/api/players/skins` | none — `[{communityId, skins:[…], equipped:[{weapon, skin}]}]` |
| GET | `/api/players/{communityId}/wallet` | none — `{mvpSiDamage, mvpCommon, stars, spent, balance}`, or 503 when the API is down |
| POST | `/api/players/{communityId}/skins/equip` `{weapon, skin}` | `Authorization: <SecretKey>` (`skin` empty = default) |

## Pages

### Shop — `/skins`

- Hero with the season (*"Season ends on {date} · N days left"*), the player's balance (*N stars available*, *"You earned X ⭐ as MVP and have spent Y ⭐ on skins."* and the SI damage and common MVPs) and two buttons:
  - **"How it works"** opens a panel with the three steps (earn stars, buy and equip, switch in game), the **"Skins per season"** notice (bought skins last until the ranking reset, every two months; at the reset every purchase is refunded automatically and the stars come back, while gifts are kept forever) and the credits: every skin was made by the community on the Steam Workshop, each skin shows its author with a link to their Steam profile, and the **Authors** tab credits all of them;
  - **"How do I use my skins in game?"** opens a table with every command.
- Tabs **Shop** (grouped by rarity, colored, each rarity with its skin count and price range), **My skins** (only when logged in) and **Authors** (every author, with a link to their Steam profile and how many skins each one has); filters by weapon, rarity and "Only the ones I can buy" (when the balance loaded).
- Cards show the photo (with `shots`, the photos cycle on hover), the author, the price and the state: *Buy for N ⭐*, *N ⭐ to go*, *Owned → Equip*, *Equipped → Back to default*; logged out, *Sign in with Steam*.
- The details of a skin have a gallery with the six photos (zoom, drag and arrows), the author with a link to their Steam profile, the original Workshop title and description, the *View on Workshop* button, the `!skin <id>` command with a copy button (for owners) and the *"Are you the author of this skin?"* notice, which explains that the skin is removed at the author's request and gives the contacts (Steam and GitHub). The `#skin-<id>` and `#mine` links open a skin or the My skins tab.
- The purchase confirmation shows the skin and the price, *"Your balance goes from X ⭐ to Y ⭐."*, says that it is equipped on the weapon right away and shows up from the next map change, says until when the skin lasts (the last day of the season, then it is refunded automatically) and ends with *"Purchases cannot be undone before the ranking reset."*
- Every action shows a clear message; purchases and equips always remind that the skin **shows up from the next map change**.

### Navbar

When logged in, the navbar shows the player's balance next to the menu (*N stars available*, tooltip *"Your stars to buy skins"*), read from `GET /api/shop/wallet` and kept in `sessionStorage`.

### Player profile — `/player/{id}`

The **Skins** panel shows the balance in its header (*N stars available · X earned, Y spent*) and lists the skins the player owns, marking the equipped ones. When two players are compared (`/player/{id}/{otherId}`), both are shown side by side following the page pattern: the first player in white, the second in yellow.

### Admin (navbar menu "Admin", only for `ServerAdmins`)

| Page | Features |
|---|---|
| Chat bans `/chat-bans` | Paginated list with avatar, Steam ID, reason, date and admin; details modal to edit the reason or remove; *Add ban* with recent chat senders and the player picker |
| Skin purchases `/admin/skins/purchases` | Notice with the last day of the season (when purchases are refunded automatically; gifts stay); totals; search; paginated list with skin image, player avatar and name, price or *Gift · by admin*, date; details modal with *Refund purchase* (with confirmation); *Give a skin*; *Refund everything* (admin tool that refunds every purchase and gift, with a confirmation checkbox) |
| Skin prices `/admin/skins/prices` | Search, rarity and weapon filters; paginated list marking changed prices; modal to change/reset the price or give that skin as a gift |

Reusable pieces (`Views/Shared`): `_Pagination` + `PagedListModel<T>`, `_PlayerPickerModal` (search by name — including previous names —, Steam ID; current ranking and all-time history), `_SkinPickerModal` (grid like the shop, with filters) and `_GiftModal` (uses both pickers; can open with a skin already selected — also from the shop's skin details for admins).

## Security notes

- Shop and admin POSTs require the login cookie **and** an antiforgery token (`RequestVerificationToken` header).
- Admin endpoints use `[AdminAuthorize]` (the user's SteamID64 must be in `ServerAdmins`).
- The plugin's write endpoint uses `[RequiredSecretKey]`, which compares the `Authorization` header with the site's `SecretKey`.
- Table queries use `TableClient.CreateQueryFilter` (parameterized); ids in routes are validated (`{communityId:long}`, catalog lookups) before being used in keys. Gift and refund take the `communityId` in the body and parse it with `SteamIdentifiers.TryParse`; refund uses the received `skinId` to read the purchase even when the skin is no longer in the catalog (admins only, and a point read).

## Localization

Every text exists in **English, Portuguese and Spanish**: per-view `.resx` files under `Resources/Views/...` (`Skins/Index`, `SkinsAdmin/Purchases`, `SkinsAdmin/Prices`, `ChatBans/Index`, `Shared/_GiftModal`, `Shared/_PlayerPickerModal`, `Shared/_SkinPickerModal`) and shared keys in `SharedResource.*.resx`. The game plugin has its own phrases files in the same three languages.
