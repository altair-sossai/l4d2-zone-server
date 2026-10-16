# 5. Tienda de skins (PlayStats web)

🌐 [English](05-skin-shop.md) | [Português](05-skin-shop.pt.md) | **Español** · [Inicio de la wiki](README.es.md)

**Repositorio:** l4d2-playstats-web (ASP.NET Core MVC, Bootstrap 3) · **Módulo principal:** `L4D2PlayStats.Core/Skins`

## Catálogo: `skins.json`

El catálogo es un recurso embebido (`L4D2PlayStats.Core/Skins/Data/skins.json`), versionado junto con el código. El archivo es un objeto con un array `skins`, ordenado por rareza y luego por precio, para que sea fácil de leer. Una entrada:

```json
{
  "id": "dark-matter",
  "weapon": "weapon_smg_silenced",
  "rarity": "legendary",
  "price": 700,
  "workshopId": "3377651383",
  "title": { "en": "MAC-10 Dark Matter", "pt": "MAC-10 Dark Matter", "es": "MAC-10 Dark Matter" },
  "description": { "en": "...", "pt": "...", "es": "..." },
  "originalTitle": "MAC-10 DARK MATTER",
  "originalDescription": "..."
}
```

- `id` es el mismo id que se usa en `weapon_skins.cfg` y en `!skin <id>`.
- La miniatura es `wwwroot/imgs/skins/<id>.jpg`.
- `workshopId` enlaza la skin con su página original en la Workshop (el botón *Ver en el Workshop*).

### Rarezas y precios

Cada skin se revisó mirando sus imágenes y recibió una rareza y un precio individual dentro del rango de la rareza:

| Rareza | Skins | Rango de precio (estrellas) |
|---|---|---|
| Legendaria | 9 | 520–700 |
| Épica | 30 | 300–450 |
| Rara | 58 | 150–240 |
| Poco común | 54 | 70–130 |
| Común | 45 | 30–60 |

Las 196 skins del catálogo cuestan en total **34.500 estrellas** (precios predeterminados) — más que todas las estrellas de todos los jugadores juntos cuando abrió la tienda — así que tener todas las skins en una temporada está pensado para ser casi imposible.

### Precios modificados

Los admins pueden cambiar un precio sin despliegue. El cambio se guarda en la tabla `SkinPrices` (PartitionKey `SkinPrice`, RowKey = id de la skin) y tiene prioridad sobre el precio del catálogo:

```csharp
public record Skin
{
    [JsonPropertyName("price")] public int DefaultPrice { get; init; }
    [JsonIgnore] public int? CustomPrice { get; init; }
    [JsonIgnore] public int Price => CustomPrice ?? DefaultPrice;
    ...
}
```

Guardar de nuevo el precio predeterminado (o "Restaurar predeterminado") borra el cambio. Las compras guardan el precio realmente pagado, así que cambiar un precio nunca afecta a las compras anteriores (y un reembolso siempre devuelve lo que se pagó).

## Almacenamiento: la tabla `SkinShop`

Una partición por jugador (`PartitionKey` = SteamID64). Tres tipos de filas:

| RowKey | Entidad | Campos |
|---|---|---|
| `Wallet` | `SkinWalletEntity` | `Spent`, `UpdatedAtUtc` (+ ETag) |
| `Owned_<skinId>` | `SkinPurchaseEntity` | `SkinId`, `Weapon`, `Price`, `StarsBefore`, `Gift`, `PlayerName`, `GiftedByCommunityId`, `GiftedByName`, `PurchasedAtUtc` |
| `Equipped_<weapon>` | `SkinEquipmentEntity` | `Weapon`, `SkinId`, `Source` (`shop`, `site`, `game`, `gift`), `UpdatedAtUtc` |

Mantener todas las filas de un jugador en una sola partición es lo que hace posible la transacción de compra: Azure Table Storage solo admite transacciones dentro de una misma partición.

El **saldo** siempre se calcula, nunca se guarda:

```csharp
public int Balance => Math.Max(0, Stars - Spent);   // Stars come from the API
```

## La transacción de compra

`SkinShopService.BuyAsync(communityId, playerName, skinId)` — el front end envía solo el id de la skin; todo lo demás se decide en el servidor.

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

Lo que esto garantiza:

| Riesgo | Protección |
|---|---|
| Comprar la misma skin dos veces | La fila de la compra es un `Add`: una segunda falla con 409 |
| Compra sin débito (o débito sin compra) | Compra, billetera y equipamiento se escriben en **una** transacción: todo o nada |
| Dos compras al mismo tiempo gastando las mismas estrellas | La actualización de la billetera depende de su ETag; la que pierde vuelve a leer y a comprobar el saldo |
| Precio o saldo falsificado desde el navegador | La solicitud lleva solo el id de la skin; el precio viene del catálogo y las estrellas, de la API |
| API caída | Las compras se rechazan (`StarsUnavailable`), nunca se suponen |

Durante el desarrollo estos casos se cubrieron con pruebas de integración ejecutadas contra Azurite, incluidas 20 compras en paralelo de la misma skin (exactamente una tiene éxito) y compras en paralelo de skins distintas (sin gastar nunca más que el saldo). El proyecto de pruebas no está versionado en el repositorio.

### Equipar, regalar, reembolsar

- **Equipar / desequipar** — comprueba que el jugador tenga la skin (o que el arma exista) y hace upsert/delete de la fila `Equipped_<weapon>`.
- **Regalo** (admin) — agrega una compra con `Price = 0`, `Gift = true`, el id y el nombre del admin, y la equipa. Las estrellas no se tocan. El reembolso de temporada nunca reembolsa los regalos.
- **Reembolso** (admin) — en una transacción: borra la compra, resta su precio de `Spent` y elimina la fila de equipamiento si esa skin estaba equipada. Reintenta ante conflictos de ETag.
- **Reembolso de temporada** (automático) — las skins se compran por temporada del ranking (dos meses, en UTC: ene–feb, mar–abr, …; el reinicio es a las 00:00 UTC del día 1 de ene, mar, may, jul, sep y nov, que son las 21:00 del día anterior en Brasilia). `SkinSeason.Current` da el inicio, el fin, el último día y los días restantes de la temporada. `SkinSeasonRefundBackgroundService` se ejecuta al iniciar el sitio y cada 10 minutos y llama a `SkinShopService.RefundSeasonAsync(SkinSeason.Current.Start)`: toda compra que **no sea un regalo** y se haya hecho antes del inicio de la temporada actual se reembolsa con las mismas reglas que un reembolso de admin — las estrellas gastadas vuelven, la skin sale de la cuenta y se elimina su fila de equipamiento. La compra se comprueba otra vez justo antes de borrarla, así que una skin comprada de nuevo en la temporada nueva nunca se toca. Los regalos se conservan para siempre. La ejecución es idempotente, así que una ejecución perdida (sitio caído en el reinicio) se recupera en la siguiente; cuando reembolsa algo, registra en el log `Skin purchases made before the season of … refunded` con los totales.
- **Reembolsar todo** (herramienta de admin) — `RefundAllAsync` reembolsa todas las compras **y todos los regalos** de todos los jugadores con las mismas reglas que un reembolso individual. Igual que el reembolso de temporada, trabaja jugador por jugador (hasta 8 jugadores en paralelo, una compra a la vez por jugador) y devuelve los totales y la cantidad de fallos.

## Endpoints

### Usados por el sitio (autenticación por cookie + token antiforgery)

| Método | Ruta | Quién |
|---|---|---|
| POST | `/api/shop/skins/{skinId}/buy` | jugador con sesión iniciada |
| POST | `/api/shop/skins/{skinId}/equip` | jugador con sesión iniciada |
| POST | `/api/shop/weapons/{weapon}/unequip` | jugador con sesión iniciada |
| POST | `/api/shop/skins/{skinId}/price` `{price}` | admin (1–100.000; `null` restaura) |
| POST | `/api/shop/gift` `{communityId, skinId}` | admin (cualquier formato de Steam ID o enlace de perfil) |
| POST | `/api/shop/refund` `{communityId, skinId}` | admin |
| POST | `/api/shop/refund-all` | admin — reembolsa todas las compras y regalos: `{purchases, gifts, stars, players, failed}` |
| GET | `/api/admin/players` | admin — jugadores para el selector de jugadores |

### Usados por el plugin del juego

| Método | Ruta | Autenticación |
|---|---|---|
| GET | `/api/skins` | ninguna — skins compradas por al menos un jugador: `[{id, weapon}]` |
| GET | `/api/players/skins` | ninguna — `[{communityId, skins:[…], equipped:[{weapon, skin}]}]` |
| GET | `/api/players/{communityId}/wallet` | ninguna — `{mvpSiDamage, mvpCommon, stars, spent, balance}` |
| POST | `/api/players/{communityId}/skins/equip` `{weapon, skin}` | `Authorization: <SecretKey>` (`skin` vacío = predeterminada) |

## Páginas

### Tienda — `/skins`

- Portada con los tres pasos (gana estrellas, compra y equipa, cambia en el juego), el saldo del jugador (`X estrellas para gastar`, con los MVPs ganados y las estrellas gastadas) y el botón **"¿Cómo uso mis skins en el juego?"**, que abre una tabla con todos los comandos.
- Un aviso **"Skins por temporada"**: las skins compradas duran hasta el reinicio del ranking, cada dos meses; muestra el último día de la temporada actual y los días restantes, y explica que en el reinicio toda compra se reembolsa automáticamente y las estrellas vuelven, mientras que los regalos se conservan para siempre.
- Una línea de créditos: todas las skins fueron hechas por la comunidad en la Steam Workshop; el botón *Ver en el Workshop* de cada skin abre el trabajo original.
- Pestañas **Tienda** (agrupada por rareza, con colores) y **Mis skins**; filtros por arma, rareza y "solo las que puedo comprar".
- Las tarjetas muestran el precio y el estado: *Comprar por N*, *Faltan N*, *Comprada → Equipar*, *Equipada → Volver a la predeterminada*.
- La confirmación de compra muestra la skin y el precio, dice que se equipa en el arma al momento y aparece a partir del próximo cambio de mapa, dice hasta cuándo dura la skin (el último día de la temporada; después se reembolsa automáticamente) y termina con *"La compra no se puede deshacer antes del reinicio del ranking."*
- Cada acción muestra un mensaje claro; las compras y los cambios siempre recuerdan que la skin **aparece a partir del próximo cambio de mapa**.

### Perfil del jugador — `/player/{id}`

Una fila **Estrellas** muestra el saldo, las estrellas ganadas y las estrellas gastadas, y un panel **Skins** lista las skins del jugador, marcando las equipadas. Cuando se comparan dos jugadores (`/player/{id}/{otherId}`), ambos se muestran lado a lado siguiendo el patrón de la página: el primer jugador en blanco, el segundo en amarillo.

### Admin (menú "Admin" de la barra de navegación, solo para `ServerAdmins`)

| Página | Funciones |
|---|---|
| Baneos del Chat `/chat-bans` | Lista paginada con avatar, Steam ID, motivo, fecha y admin; modal de detalles para editar el motivo o eliminar; *Agregar baneo* con quienes escribieron recientemente en el chat y el selector de jugadores |
| Compras de skins `/admin/skins/purchases` | Aviso con el último día de la temporada (cuando las compras se reembolsan automáticamente; los regalos se conservan); totales; búsqueda; lista paginada con imagen de la skin, avatar y nombre del jugador, precio o *Regalo · por admin*, fecha; modal de detalles con *Reembolsar compra* (con confirmación); *Regalar skin*; *Reembolsar todo* (herramienta de admin que reembolsa todas las compras y regalos, con una casilla de confirmación) |
| Precios de skins `/admin/skins/prices` | Búsqueda, filtros de rareza y arma; lista paginada que marca los precios cambiados; modal para cambiar/restaurar el precio o regalar esa skin |

Piezas reutilizables (`Views/Shared`): `_Pagination` + `PagedListModel<T>`, `_PlayerPickerModal` (búsqueda por nombre — incluidos nombres anteriores —, Steam ID; ranking actual e historial de todos los tiempos), `_SkinPickerModal` (cuadrícula como la de la tienda, con filtros) y `_GiftModal` (usa los dos selectores; puede abrirse con una skin ya elegida — también desde los detalles de la skin en la tienda, para admins).

## Notas de seguridad

- Los POST de la tienda y de admin exigen la cookie de inicio de sesión **y** un token antiforgery (encabezado `RequestVerificationToken`).
- Los endpoints de admin usan `[AdminAuthorize]` (el SteamID64 del usuario debe estar en `ServerAdmins`).
- El endpoint de escritura del plugin usa `[RequiredSecretKey]`, que compara el encabezado `Authorization` con el `SecretKey` del sitio.
- Las consultas a las tablas usan `TableClient.CreateQueryFilter` (parametrizado); los ids de las rutas se validan (`{communityId:long}`, búsqueda en el catálogo) antes de usarse en claves.

## Localización

Todos los textos existen en **inglés, portugués y español**: archivos `.resx` por vista en `Resources/Views/...` (`Skins/Index`, `SkinsAdmin/Purchases`, `SkinsAdmin/Prices`, `ChatBans/Index`, `Shared/_GiftModal`, `Shared/_PlayerPickerModal`, `Shared/_SkinPickerModal`) y claves compartidas en `SharedResource.*.resx`. El plugin del juego tiene sus propios archivos de frases en los mismos tres idiomas.
