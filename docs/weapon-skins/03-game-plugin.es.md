# 3. Plugin del servidor de juego — `l4d2_weapon_skins`

🌐 [English](03-game-plugin.md) | [Português](03-game-plugin.pt.md) | **Español** · [Inicio de la wiki](README.es.md)

**Código:** [`addons/sourcemod/scripting/l4d2_weapon_skins.sp`](../../addons/sourcemod/scripting/l4d2_weapon_skins.sp) (v3.3.0) · **Config:** [`addons/sourcemod/configs/weapon_skins.cfg`](../../addons/sourcemod/configs/weapon_skins.cfg) · **Traducciones:** `addons/sourcemod/translations/{,pt/,es/}l4d2_weapon_skins.phrases.txt`

El plugin se carga desde `plugins/` (carga automática), no desde `optional/`, así que ya está funcionando en el lobby y los archivos de las skins ya están en la tabla de descargas cuando los jugadores se conectan por primera vez.

## Datos que guarda en memoria

| Variable | Contenido |
|---|---|
| `g_hSkins` / `g_hSkinsByName` | Skins de `weapon_skins.cfg` (structs `WeaponSkin`) y un mapa id → índice |
| `g_hWeaponModels` | Modelos combinados/originales por arma y sus índices de precache |
| `g_hPurchasedSkins` | Ids de las skins compradas por al menos un jugador (de `/api/skins`) |
| `g_hOwnedSkins` | Claves `"<steamid64>:<skin>"` de cada skin comprada (de `/api/players/skins`) |
| `g_hPlayerChoices` | Skin equipada por `"<steamid64>:<weapon>"` |
| `g_hLocalChanges` | Cuándo un jugador cambió una skin en el juego por última vez (protege los cambios recientes, ver abajo) |
| `g_hTestChoices` | Elecciones de `!skin test` de los admins, se borran al inicio del mapa |

## Inicio del mapa: armando la tabla de descargas

En `OnMapStart` el plugin lee `weapon_skins.cfg`:

1. **La carpeta del modelo combinado de cada arma** se agrega a la tabla de descargas y se hace su precache, tenga alguien una skin o no.
2. **Cada skin** solo se prepara si alguien la compró (o si el modo de prueba está activado):

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

`skin.ready` le indica al resto del código si los archivos de esa skin están en la tabla de descargas de **este** mapa. Una skin comprada durante el mapa ya es del jugador, pero no está lista hasta el próximo mapa.

### Hibernación y los archivos de caché

Un servidor de L4D2 vacío hiberna: los callbacks de HTTP asíncrono solo se procesan después de que se conecta el primer jugador — demasiado tarde para las descargas de ese jugador. Por eso el plugin guarda en disco las últimas respuestas válidas de la API y las lee cuando no tiene nada en memoria:

- `addons/sourcemod/data/weapon_skins_cache.json` — skins compradas (`/api/skins`);
- `addons/sourcemod/data/weapon_skins_players_cache.json` — skins de cada jugador y equipadas (`/api/players/skins`).

## Comunicación con el sitio

Dos cvars, compartidas con `l4d2_gameinfo_sync`, configuran el sitio: `l4d2_web_url` (definida en `cfg/server.cfg`) y `l4d2_web_secret` (definida en `cfg/server_secrets.cfg`, que git ignora).

| Llamada | Cuándo | Para qué |
|---|---|---|
| `GET {url}/api/skins` | configs ejecutadas, inicio de ronda, fin de ronda, cada 2 min con jugadores | Qué skins hay que descargar |
| `GET {url}/api/players/skins` | igual | Quién tiene qué y qué está equipado |
| `GET {url}/api/players/{id}/wallet` | `!skin status` | Estrellas y saldo |
| `POST {url}/api/players/{id}/skins/equip` con `Authorization: <l4d2_web_secret>` | un jugador cambia de skin en el juego | Guardar la skin equipada en el sitio |

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

Las respuestas con campos faltantes se rechazan y se conservan los últimos datos válidos.

### No perder un cambio hecho en el juego

Un jugador puede cambiar la skin en el juego mientras hay una actualización en curso; el sitio podría responder con el valor anterior. Cada cambio en el juego registra `GetEngineTime()`; cada actualización registra cuándo se pidió. Hasta 15 s después del cambio (`LOCAL_CHANGE_GRACE`), gana la elección local:

```sourcepawn
if (requestedAt > changedAt + LOCAL_CHANGE_GRACE)
{
	g_hLocalChanges.Remove(key);   // the site already has it
	continue;
}
// keep the local value over the site's answer
```

### Aviso de compra nueva

Cuando una actualización muestra una skin que los datos anteriores no tenían, el dueño (si está conectado) recibe un mensaje en el chat: *"Compra recibida: X (arma). Ya está equipada y aparece a partir del próximo cambio de mapa."* Si otro jugador ya había comprado esa skin (sus archivos están en este mapa), el plugin la aplica al momento y lo avisa.

### Reembolsos

Cuando se reembolsa una compra (por un admin o al final de la temporada del ranking), la siguiente actualización ya no incluye esa skin para el jugador: las armas registradas desde entonces usan la skin predeterminada, y a partir del próximo mapa los archivos de la skin solo se descargan si otra persona todavía la tiene. Un arma que ya tiene la skin la conserva hasta que sale del juego.

## Aplicar una skin

Una skin se aplica cambiando el modelo por el **modelo combinado** del arma y poniendo en `m_nSkin` la family de la skin (simplificado):

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

- **Modelo de mundo** (lo que ven los demás y el arma en el suelo): se aplica al equipar, al recoger el arma y 0,1 s después de soltarla (el motor reinicia el modelo cuando se suelta el arma). Cuando un jugador toma un arma de un spawn (`weapon_*_spawn`), el arma en el slot del arma del spawn (pistolas y cuerpo a cuerpo: secundario; el resto: principal) vuelve al modelo de mundo original antes del uso y recibe la skin de nuevo justo después.
- **Modelo de vista** (primera persona): la entidad `m_hViewModel` del jugador recibe el modelo de vista combinado y la family en `OnPostThinkPost`, en cada frame. En las seis armas de fuego (`stock_skins` en el cfg) esto ocurre **incluso sin skin**, con la family original del arma (`m_nSkin`), que se ve idéntica al arma original; las armas cuerpo a cuerpo solo lo reciben mientras tienen skin.
- **Sin parpadeo en primera persona**: el cliente predice las animaciones del arma y, cada vez que una empieza, vuelve a poner el modelo de vista escrito en el script del arma, con el `m_nSkin` del arma como family. Sin ayuda, el arma original parpadea sobre la skin durante aproximadamente un ping en cada disparo, recarga y cambio de arma. El cliente del anti-cheat apunta el script de las seis armas de fuego al modelo combinado mientras el jugador está en el servidor, así la predicción usa el mismo modelo, y las families originales al inicio del modelo combinado mantienen el arma sin skin con su aspecto original. Las armas cuerpo a cuerpo todavía parpadean: los datos de su script no guardan la ruta que usa la predicción.
- **Restauración**: cuando un arma pierde su skin, se restauran el modelo original y el `m_nSkin` original del arma.

### ¿Qué skin recibe un arma?

Cada entidad de arma recuerda la skin que recibió cuando se registró por primera vez (`g_iWeaponSkin[weapon]`). **La skin sigue al arma**: si el dueño la suelta, quien la recoja la usa con la skin del dueño. La skin del arma de un jugador se elige así:

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

Las armas cuerpo a cuerpo comparten la clase `weapon_melee`, así que la clave del arma se arma con el nombre del script: `weapon_melee_<m_strMapSetScriptName>` (por ejemplo `weapon_melee_fireaxe`).

## Jugadores sin descargas

Un jugador con `cl_allowdownload 0` (o con `cl_downloadfilter` distinto de `all`/`nosounds`) vería un modelo `ERROR`. El plugin consulta las dos cvars en cuanto el jugador empieza a conectarse (`OnClientConnected`):

- `weapon_skins_kick_no_downloads 1` (el valor definido en `shared_cvars.cfg`) → con las skins activadas, el jugador es expulsado. El mensaje de expulsión indica qué cvar tiene el valor incorrecto y el comando de consola que lo arregla (`cl_allowdownload 1` o `cl_downloadfilter all`), y le pide al jugador revisar esa cvar en `autoexec.cfg` o `config.cfg` si le sigue pasando. Cada expulsión se registra en el log de SourceMod con `LogMessage` (nombre y SteamID del jugador, nunca la IP):

  ```text
  [l4d2_weapon_skins.smx] Kicked Player<12><STEAM_1:0:12345><> because cl_allowdownload is "0"
  ```

- `0` → el jugador se queda y **los modelos de mundo vuelven al original para todos** mientras ese jugador esté en el servidor (los modelos de vista siguen apareciendo para quienes pueden verlos, salvo para quien lo esté observando en primera persona).

> La opción del menú del juego *Opciones > Multijugador > Contenido de servidor personalizado > Permitir todo* solo cambia `cl_downloadfilter`. `cl_allowdownload` no tiene opción en el menú: solo se puede cambiar en la consola o en un archivo de configuración. Por eso un jugador que eligió "Permitir todo" en el menú todavía puede ser expulsado, y por eso el mensaje incluye el comando de consola exacto.

## Limpieza de pilas de armas

Cambiar de arma una y otra vez en los spawns infinitos del refugio puede acumular armas soltadas y causar lag en el servidor. Cuando se suelta un arma principal, el plugin cuenta las armas principales soltadas dentro de `weapon_skins_pile_radius` y elimina las más antiguas por encima de `weapon_skins_pile_max`. Nunca se eliminan los spawns, las armas colocadas por el mapa, las armas secundarias ni las armas en la mano.

## Comandos

| Comando | Quién | Qué hace |
|---|---|---|
| `!skin` / `!skins` | todos | Ayuda y el enlace de la tienda |
| `!skin <id>` | todos | Usa una de tus skins (solo durante el ready-up, como superviviente) |
| `!skin next` / `!skin prev` `[arma]` | todos | Recorre tus skins del arma; después de la última, vuelve a la predeterminada |
| `!skin default [arma]` | todos | Vuelve a la skin predeterminada |
| `!skin status` | todos | Skins activadas/desactivadas, tus estrellas y cuántas skins tienes |
| `!skin on` / `!skin off` | root | Activa/desactiva las skins para todos (se mantiene tras los cambios de mapa) |
| `!skin test <id\|default> [arma]` | root | Prueba una skin en ti hasta que cambie el mapa |

`[arma]` acepta `smg` (o `uzi`), `mac` (o `mac10`, `mac-10`, `silenced`), `mp5`, `pump`, `chrome`, `magnum` (o `deagle`), `axe` (o `fireaxe`), `bat`, `cricket`, `guitar`, `golf`, `pan`, cualquier otro nombre de script de arma cuerpo a cuerpo (`katana`, `machete`, `crowbar`) y las claves completas (`weapon_smg`, `weapon_melee_katana`, …).

## Cvars

| Cvar | Predeterminado | Para qué |
|---|---|---|
| `weapon_skins_enabled` | `0` | Interruptor general (en `1` en `shared_cvars.cfg`) |
| `l4d2_web_url` | `""` | URL del sitio, compartida con `l4d2_gameinfo_sync` |
| `l4d2_web_secret` | `""` | Secreto del sitio, compartido con `l4d2_gameinfo_sync` |
| `weapon_skins_kick_no_downloads` | `0` | Expulsa a los jugadores sin descargas (en `1` en `shared_cvars.cfg`) |
| `weapon_skins_pile_radius` / `weapon_skins_pile_max` | `120` / `3` | Limpieza de pilas de armas (`weapon_skins_pile_max 0` la desactiva) |
| `weapon_skins_preview_all` | `0` | Modo de prueba: todas las skins se descargan y los admins root pueden usarlas |
