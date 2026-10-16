# 4. Estrellas (PlayStats API)

🌐 [English](04-stars-api.md) | [Português](04-stars-api.pt.md) | **Español** · [Inicio de la wiki](README.es.md)

**Repositorio:** l4d2-playstats-api (Azure Functions, .NET) · **Módulo:** `L4D2PlayStats.Core/Modules/Stars`

## Qué es una estrella

**1 estrella = 1 MVP.** En cada mitad de un mapa (el turno de superviviente de cada equipo), el archivo de estadísticas indica dos MVPs:

- **MVP de daño a SI** — el superviviente que hizo más daño a los infectados especiales;
- **MVP de comunes** — el superviviente que mató más infectados comunes.

Las estrellas de un jugador son la suma de todos sus MVPs, en todo el historial, con **las mismas reglas que el ranking**:

- solo cuentan las partidas **competitivas** (al menos 2 mapas, 4v4, una configuración de ranking);
- los MVPs se acreditan a los jugadores de la formación del último mapa de la partida (un jugador que se fue antes del último mapa no recibe los MVPs de esa partida);
- los empates son para el primer jugador del archivo.

Estas reglas no son nuevas: vienen de cómo la API ya arma las partidas (`Match.Team.UpdateStats`) para el ranking.

## De dónde vienen los datos

1. `l4d2_playstats` escribe un archivo de texto por mapa con las estadísticas de las dos mitades.
2. `l4d2_playstats_sync` sube cada archivo a `POST /api/statistics` (autenticado por servidor).
3. La API guarda cada archivo en la tabla `Statistics` (PartitionKey = id del servidor, RowKey = un timestamp invertido, para que las filas queden ordenadas de la más nueva a la más antigua). Nunca se borra nada.
4. `MatchService` convierte las filas en partidas; `Match.Team.UpdateStats` cuenta los MVPs de cada jugador.

## Cómo se calculan las estrellas

Recalcular todas las partidas desde 2023 en cada solicitud sería lento, así que el total se divide en dos:

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

- **Períodos cerrados** — se calculan una vez por período del ranking (las temporadas de dos meses del ranking: ene–feb, mar–abr, …) a partir de todas las partidas *anteriores* al inicio del período actual, y se guardan como `closed_yyyyMM.json` en el contenedor de blobs privado `{serverId}-stars`. Un timer (`0 30 0 * * *`) se asegura cada día de que exista. Una vez leído, el blob también se mantiene en memoria durante 12 horas.
- **Período actual** — las partidas del período actual, en caché en memoria durante 1 hora. La caché se limpia cuando se sube un nuevo archivo de estadísticas (en la instancia que lo recibió).

Contar los MVPs de un conjunto de partidas:

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

La consulta de los períodos cerrados lee todas las filas de estadísticas más antiguas que el inicio del período (las RowKeys son ticks invertidos, así que "más antigua que X" es `RowKey gt '{long.MaxValue - X.Ticks}'`):

```csharp
public IAsyncEnumerable<Statistics> GetStatisticsBeforeAsync(string serverId, DateTime end)
{
    var filter = $"PartitionKey eq '{serverId}' and RowKey gt '{long.MaxValue - end.Ticks}'";
    return TableClient.QueryAsync<Statistics>(filter);
}
```

## Endpoints

| Método | Ruta | Devuelve |
|---|---|---|
| GET | `/api/stars/{serverId}` | Todos los jugadores con estrellas: `[{communityId, mvpSiDamage, mvpCommon, stars}]` |
| GET | `/api/stars/{serverId}/{communityId}` | Un jugador (ceros si el jugador no tiene ninguna) |

Los dos son de solo lectura y anónimos, como los endpoints del ranking.

## Validación

Cuando se construyó la funcionalidad, los totales se compararon con el ranking de todo el historial ya guardado: para los 100 jugadores de `ranking_all_time.json`, *MVPs de todo el historial + MVPs del período actual* coincidieron exactamente con el endpoint de estrellas (0 diferencias), con 688 jugadores y unas 24.750 estrellas en total en ese momento.

## Cosas a tener en cuenta

- Las estrellas solo aumentan en el uso normal. Si algún día se corrigieran las estadísticas (por ejemplo, una corrección de puntuación), las estrellas de un jugador podrían bajar; entonces la tienda muestra saldo 0 y bloquea las compras, pero una bajada de estrellas nunca quita las skins que ya tiene.
- Las estrellas son de todo el historial y **no** se reinician con el ranking. Lo que hace el reinicio del ranking es reembolsar las skins compradas en la temporada que terminó, para que las estrellas gastadas en ellas se puedan volver a gastar (consulta [Tienda de skins → Equipar, regalar, reembolsar](05-skin-shop.es.md#equipar-regalar-reembolsar)).
- Un MVP nuevo puede tardar hasta 1 hora en aparecer si la app de Functions se ejecuta en más de una instancia (cada instancia tiene su propia caché).
