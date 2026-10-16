# 4. Stars (PlayStats API)

🌐 **English** | [Português](04-stars-api.pt.md) | [Español](04-stars-api.es.md) · [Wiki home](README.md)

**Repository:** l4d2-playstats-api (Azure Functions, .NET) · **Module:** `L4D2PlayStats.Core/Modules/Stars`

## What a star is

**1 star = 1 MVP.** For every half of a map (each team's survivor turn), the statistics file names two MVPs:

- **SI damage MVP** — the survivor who dealt the most damage to special infected;
- **Common MVP** — the survivor who killed the most common infected.

A player's stars are the sum of all their MVPs, over the whole history, using **the same rules as the ranking**:

- only **competitive** matches count (at least 2 maps, 4v4, a ranking configuration);
- MVPs are credited to the players of the match's last map roster (a player who left before the last map does not get the MVPs of that match);
- ties go to the first player in the file.

These rules are not new: they come from how the API already builds matches (`Match.Team.UpdateStats`) for the ranking.

## Where the data comes from

1. `l4d2_playstats` writes one text file per map with the statistics of both halves.
2. `l4d2_playstats_sync` uploads each file to `POST /api/statistics` (authenticated per server).
3. The API stores every file in the `Statistics` table (PartitionKey = server id, RowKey = an inverted timestamp, so rows sort newest first). Nothing is ever deleted.
4. `MatchService` turns rows into matches; `Match.Team.UpdateStats` counts the MVPs of each player.

## How stars are computed

Recomputing every match since 2023 on each request would be slow, so the total is split in two:

```
stars = closed periods (all matches before the current ranking period) + current period
```

```csharp
public async Task<List<PlayerStars>> StarsAsync(string serverId)
{
    var closed = await ClosedStarsAsync(serverId);   // blob, rebuilt once per period
    var current = await CurrentStarsAsync(serverId); // memory cache, 1 h, cleared on upload
    ... // sum both per player, sorted by stars
}
```

- **Closed periods** — computed once per ranking period (the two-month ranking seasons: Jan–Feb, Mar–Apr, …) from every match *before* the current period starts, then saved as `closed_yyyyMM.json` in the private blob container `{serverId}-stars`. A timer (`0 30 0 * * *`) makes sure it exists every day. Once read, the blob is also kept in memory for 12 hours.
- **Current period** — the matches of the current period, cached in memory for 1 hour. The cache is cleared when a new statistics file is uploaded (on the instance that received it).

Counting the MVPs of a set of matches:

```csharp
public static Dictionary<long, PlayerStars> Stars(this IEnumerable<Match> matches)
{
    var players = new Dictionary<long, PlayerStars>();

    foreach (var match in matches)
    foreach (var team in match.Teams)
    foreach (var matchPlayer in team.Players)
    {
        if (!long.TryParse(matchPlayer.CommunityId, out var communityId))
            continue;
        ...
        player.MvpSiDamage += matchPlayer.MvpSiDamage;
        player.MvpCommon += matchPlayer.MvpCommon;
    }

    return players;
}
```

The closed query reads every statistics row older than the period start (RowKeys are inverted ticks, so "older than X" is `RowKey gt '{long.MaxValue - X.Ticks}'`):

```csharp
public IAsyncEnumerable<Statistics> GetStatisticsBeforeAsync(string serverId, DateTime end)
{
    var filter = $"PartitionKey eq '{serverId}' and RowKey gt '{long.MaxValue - end.Ticks}'";
    return TableClient.QueryAsync<Statistics>(filter);
}
```

## Endpoints

| Method | Route | Returns |
|---|---|---|
| GET | `/api/stars/{serverId}` | Every player with stars: `[{communityId, mvpSiDamage, mvpCommon, stars}]` |
| GET | `/api/stars/{serverId}/{communityId}` | One player (zeros if the player has none) |

Both are read-only and anonymous, like the ranking endpoints.

## Validation

When the feature was built, the totals were checked against the stored all-time ranking: for the 100 players of `ranking_all_time.json`, *all-time MVPs + current period MVPs* matched the stars endpoint exactly (0 differences), with 688 players and about 24,750 stars in total at the time.

## Things to keep in mind

- Stars only grow in normal use. If the statistics were ever fixed (for example, a score correction) a player's stars could drop; the shop then shows a balance of 0 and blocks purchases, but a drop in stars never removes owned skins.
- Stars are all-time and are **not** reset with the ranking. What the ranking reset does is refund the skins bought in the season that ended, so the stars spent on them can be spent again (see [Skin shop → Equip, gift, refund](05-skin-shop.md#equip-gift-refund)).
- A new MVP may take up to 1 hour to show if the Functions app runs more than one instance (each instance has its own cache).
