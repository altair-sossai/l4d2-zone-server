# 6. Operación y procedimientos

🌐 [English](06-operations.md) | [Português](06-operations.pt.md) | **Español** · [Inicio de la wiki](README.es.md)

## Configuración y secretos

> Los valores de los secretos nunca se escriben en repositorios, documentación ni chat. Esta página solo indica **dónde** está cada uno.

### Servidor de juego

| Ajuste | Archivo | ¿Versionado? |
|---|---|---|
| `l4d2_web_url` (URL del sitio, compartida por `l4d2_weapon_skins` y `l4d2_gameinfo_sync`) | `cfg/server.cfg` | sí |
| `l4d2_web_secret` (= el `SecretKey` del sitio) | `cfg/server_secrets.cfg` | **no** (git lo ignora, solo existe en el servidor) |
| `weapon_skins_enabled`, `weapon_skins_kick_no_downloads`, ajustes de pilas | `cfg/cfgogl/{zonemod,neomod}/shared_cvars.cfg` | sí |
| `sv_downloadurl` (FastDL) | `cfg/server.cfg` | sí |

`cfg/server.cfg` ejecuta `exec server_secrets.cfg` al principio, así que los secretos se cargan en cada inicio de mapa.

### Sitio (`appsettings.json`, solo en el servidor web)

| Clave | Para qué |
|---|---|
| `AzureWebJobsStorage` | Cuenta de storage (tablas `SkinShop`, `SkinPrices`, `ChatBans`, …) |
| `PlayStatsApiUrl`, `ServerId`, `PlayStatsSecret` | Llamadas a la PlayStats API (estrellas, ranking) |
| `SecretKey` | Secreto compartido que comprueba `[RequiredSecretKey]` (servidor de juego → sitio) |
| `ServerAdmins` | Lista de SteamID64 de los admins (separados por `;`) |
| `SteamApiKey` | Steam Web API (nombres y avatares) |
| `ServerDns` | Dirección del servidor de juego que muestra el sitio (página del servidor) |
| `SkinShotsUrl` (opcional) | Dónde están las fotos de las skins; por defecto, el contenedor `assets/skin-shots` de la cuenta `l4d2playstats` |

### API (app settings de Azure Functions)

`AzureWebJobsStorage` — la misma cuenta de storage. La tabla `Statistics` es la fuente del ranking y de las estrellas: **nunca la borres ni la edites**.

## Despliegues

| Repositorio | Disparador | Qué pasa |
|---|---|---|
| l4d2-zone-server | push a `master` (los cambios solo en `docs/` o en archivos `*.md` no lo disparan) | `addons/`, `cfg/`, `bash/`, `scripts/` se empaquetan y se extraen en la carpeta del juego. `server_secrets.cfg` no se toca |
| l4d2-zone-server-assets | push a `main` | `models/` y `materials/` van a la carpeta del juego y al blob de FastDL; `fastdl/` y `assets/` (incluidas las fotos de las skins en `assets/skin-shots/`) van a blobs. Solo los archivos nuevos o cambiados van a los blobs, y no se borra nada |
| l4d2-playstats-api | push a `main` | Build, pruebas y el artefacto de build `function`. El pipeline del repositorio no publica nada: la app de Azure Functions se publica fuera de él, a partir de ese artefacto |
| l4d2-playstats-web | push a `main` | Publicación self-contained, copiada al servidor web y reiniciada en la sesión `screen` `l4d2-playstats-web` |
| l4d2-anti-cheat-client | push a `main` | Build, pruebas y un paquete firmado del cliente subido al blob storage; los jugadores reciben la versión nueva (con el nuevo manifiesto de assets del servidor) cuando cambia el número de versión |

**Orden cuando un cambio abarca varios repositorios:** API → sitio → zone-server. El plugin depende de los endpoints del sitio, y el sitio depende de la API. Cuando cambian archivos de skin, el cliente del anti-cheat y los assets van primero: consulta la siguiente sección.

**Los plugins y las configs** solo tienen efecto después de que el servidor los recarga: reinicia el servidor de juego después de un despliegue de zone-server que cambie plugins.

### Cuando cambian los modelos combinados

Agregar, quitar o cambiar una skin cambia los modelos combinados y los archivos de las skins. Sigue este orden:

1. **Cliente del anti-cheat** — publica el cliente nuevo (nuevo manifiesto de assets del servidor + subida de versión) y asegúrate de que ya esté disponible para los jugadores.
2. **Assets** — haz push del repositorio de assets (carpeta del juego + FastDL + fotos de las skins).
3. **Sitio** — haz push del catálogo (`skins.json`) y de las miniaturas.
4. **Zone-server** — haz push de `weapon_skins.cfg` (índices de family).
5. **Reinicia el servidor de juego mientras está vacío** (ver abajo).

Por qué: el anti-cheat verifica los archivos de skin enviados por el servidor contra su manifiesto, así que un jugador cuyo cliente todavía tiene el manifiesto anterior y que descarga el modelo nuevo es expulsado. Además, un modelo cambiado debe descargarse al conectarse, no en un cambio de mapa, y por eso se reinicia el servidor.

## Reiniciar el servidor de juego

1. Comprueba que nadie esté jugando: envía `status` a la sesión `screen` `27015` y mira la cantidad de jugadores.
2. Reinicia solo con los scripts del servidor: `bash/stop.sh 27015`, espera unos segundos, `bash/start.sh 27015 c2m1_highway`.
3. Revisa `sm plugins info l4d2_weapon_skins` (estado `running`) y el log de errores de SourceMod del día.

> **No** ejecutes los scripts de bootstrap ni de firewall de forma remota: pueden dejar fuera la sesión SSH.

## Tareas comunes

| Tarea | Cómo |
|---|---|
| Cambiar el precio de una skin | Admin → Precios de skins → haz clic en la skin → cambia → Guardar (o Restaurar predeterminado). Solo se aplica a compras nuevas |
| Reembolsar una compra | Admin → Compras de skins → haz clic en la compra → *Reembolsar compra* → *Confirmar reembolso*. Las estrellas vuelven; la skin se desequipa |
| Reembolsar todo | Herramienta de admin para casos excepcionales (por ejemplo, después de recalcular los precios). Admin → Compras de skins → *Reembolsar todo* → marca la confirmación → *Reembolsar todo*. Se reembolsan todas las compras **y todos los regalos** de todos los jugadores (mismas reglas que un reembolso individual); las estrellas de los jugadores no cambian, solo vuelve lo que se gastó. No se puede deshacer. Si algunos elementos fallan, ejecútalo de nuevo |
| Reembolso de temporada | Automático en el reinicio del ranking (00:00 UTC del día 1 de ene, mar, may, jul, sep y nov = 21:00 del día anterior en Brasilia). Busca `Skin purchases made before the season of ... refunded` en el log del sitio. Los regalos se conservan. No hay que hacer nada; si el sitio estaba caído en el reinicio, se pone al día en los 10 minutos siguientes a su inicio |
| Regalar una skin | Admin → Compras de skins → *Regalar skin* (o desde el modal de precio, o desde los detalles de la skin en la tienda). Elige el jugador y la skin. El reembolso de temporada nunca reembolsa los regalos |
| Banear a un jugador del chat | Admin → Baneos del Chat → *Agregar baneo* → elige entre quienes escribieron recientemente o *Elegir de la lista* |
| Probar todas las skins en el juego | `!cvar weapon_skins_preview_all 1`, cambia el mapa, reconéctate; los admins root pueden usar cualquier skin. Después desactívalo y cambia el mapa (cada jugador que se conecte mientras tanto descarga todas las skins, ~300 MB) |
| Agregar una skin nueva | Consulta [Assets de las skins → Agregar una skin nueva](02-assets.es.md#agregar-una-skin-nueva-checklist) |
| Rotar el secreto compartido | Cambia el `SecretKey` del sitio **y** `l4d2_web_secret` en `server_secrets.cfg` al mismo valor nuevo, y luego reinicia el sitio y el servidor de juego |

## Solución de problemas

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| La skin comprada no aparece | Solo aparece a partir del próximo cambio de mapa | Cambia el mapa; comprueba que `/api/skins` la incluya |
| Las skins de un jugador desaparecieron al inicio de un mes | Reembolso de temporada en el reinicio del ranking | Es lo esperado: las estrellas volvieron y el jugador puede comprar de nuevo. Los regalos se conservan |
| El arma aparece como `ERROR` | Los modelos se descargaron durante un cambio de mapa | Reinicia el juego; los modelos deben descargarse al conectarse |
| La skin solo se ve para algunos jugadores | Un jugador tiene las descargas desactivadas y `weapon_skins_kick_no_downloads` está en `0` | Activa la expulsión, o pide al jugador que active las descargas |
| Jugador expulsado por descargas aunque eligió "Permitir todo" en el menú | `cl_allowdownload` está en `0` (no tiene opción en el menú) | El mensaje de expulsión da el comando: `cl_allowdownload 1` en la consola, y quitar `cl_allowdownload 0` de `autoexec.cfg`/`config.cfg`. Las expulsiones quedan en el log de SourceMod (`Kicked ... because ...`) |
| Jugadores expulsados por el anti-cheat justo después de un despliegue de skins | Los assets se desplegaron antes que el cliente del anti-cheat con el manifiesto nuevo | Publica el cliente nuevo; consulta [Cuando cambian los modelos combinados](#cuando-cambian-los-modelos-combinados) |
| "No pudimos cargar tus estrellas" en la tienda | El sitio no pudo llegar a la API | Revisa la API; las compras quedan bloqueadas hasta que responda |
| MVPs nuevos todavía sin contar | Caché de la API (hasta 1 h) | Espera; la próxima subida limpia la caché en esa instancia |
| El primer mapa después de un reinicio descarga skins que nadie compró | `weapon_skins_cache.json` antiguo de otra versión | Borra los archivos de caché en `addons/sourcemod/data/` y reinicia |
| El chat/la información del juego dejó de llegar al sitio | `l4d2_web_url`/`l4d2_web_secret` faltan o son distintos del `SecretKey` | Revisa `server.cfg`, `server_secrets.cfg` y el `SecretKey` del sitio |

## Pruebas

- **Servicio de la tienda** — durante el desarrollo, pruebas de integración ejecutaron el `SkinShopService` y los repositorios reales contra **Azurite** (el emulador local de Azure Storage), con un servicio de estrellas falso: compra, compra duplicada, estrellas insuficientes, API caída, compras simultáneas, equipar/desequipar, regalo, reembolso, precios modificados. El proyecto de pruebas no está versionado; prueba los cambios de la tienda contra Azurite, nunca contra las tablas de producción.
- **Sitio en local** — ejecuta el sitio con un content root separado cuyo `appsettings.json` apunte `AzureWebJobsStorage` a `UseDevelopmentStorage=true`, para no tocar las tablas de producción. Ten en cuenta que el reembolso de temporada se ejecuta al iniciar: las compras en Azurite con fecha anterior a la temporada actual se reembolsan.
- **Estrellas** — compara `/api/stars` con el ranking de todo el historial guardado más el período actual.
- **Plugin** — compila con el `spcomp` incluido ([`addons/sourcemod/scripting/sourcemod/spcomp.exe`](../../addons/sourcemod/scripting/sourcemod/spcomp.exe)) y prueba en el servidor, idealmente sin nadie jugando.
