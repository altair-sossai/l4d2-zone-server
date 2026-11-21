# Plugins Personalizados — l4d2-zone-server

🌐 [English](README.md) | [Português](README.pt.md) | **Español**

Este documento describe los plugins mantenidos en este repositorio:

- **Plugins personalizados** — escritos específicamente para este servidor.
- **Plugins adaptados** — creados por otros autores y modificados aquí (correcciones y ajustes) para adaptarse a este servidor. **No son obra original**; el autor y el repositorio originales se acreditan en cada sección.

Para el resto de plugins de terceros que vienen sin modificaciones con la base [ZoneMod / L4D2 Competitive Rework](https://github.com/SirPlease/L4D2-Competitive-Rework), consulta a sus autores originales.

- **Fuentes:** [`addons/sourcemod/scripting/`](../../addons/sourcemod/scripting/) (`.sp`)
- **Compilados:** [`addons/sourcemod/plugins/optional/`](../../addons/sourcemod/plugins/optional/) (`.smx`) — excepto `annoyance_exploit_fixes`, que está en `plugins/fixes/`
- **Script de compilación:** [`ps/compile-custom-plugins.ps1`](../../ps/compile-custom-plugins.ps1) — consulta [Compilar los plugins personalizados](../maintenance/compile-custom-plugins.es.md)

---

## Cómo funciona la configuración en este repositorio

La mayoría de estos plugins están en `optional/`, así que no se cargan automáticamente — se cargan de forma explícita y se configuran a través de la capa de configuración de ZoneMod. Estos son los puntos de contacto:

| Archivo | Propósito |
|------|---------|
| `cfg/cfgogl/<mod>/shared_plugins.cfg`  | **Carga** cada plugin (`sm plugins load optional/<name>.smx`) |
| `cfg/cfgogl/<mod>/shared_cvars.cfg`    | **Define ConVars** mediante `confogl_addcvar <cvar> <value>` |
| `cfg/cfgogl/<mod>/shared_settings.cfg` | También define ConVars mediante `confogl_addcvar` (se usa para `l4d2_spec_lister_hint`) |
| `cfg/server.cfg`                       | Valores de todo el servidor que deben existir antes de cargar cualquier config de partida (`l4d2_web_url`, `playstats_url`, `playstats_public_url`, y los del anti-cheat `anti_cheat_endpoint`, `anti_cheat_server_id` y `anti_cheat_download_url`) |
| `cfg/server_secrets.cfg`               | **Fuera del repositorio.** Lo escribe el pipeline en cada deploy a partir de las variables secretas `RCON_PASSWORD`, `PLAYSTATS_TOKEN` y `ANTI_CHEAT_ACCESS_TOKEN` (`rcon_password`, `playstats_token`, `l4d2_web_secret` y `anti_cheat_access_token`), con permiso `600`; se ejecuta al inicio de `server.cfg` |

`<mod>` es la carpeta de config activa, principalmente [`zonemod`](../../cfg/cfgogl/zonemod/) y [`neomod`](../../cfg/cfgogl/neomod/).

> **Las ConVars marcadas como `PROTECTED`** se crean con `FCVAR_PROTECTED`, así que su valor nunca se muestra a los clientes. Los secretos reales nunca van en los archivos de cfg versionados: el token de PlayStats lo escribe el pipeline de deploy en `cfg/playstats_token.cfg`, y los demás secretos van en `cfg/server_secrets.cfg`, para que nunca se filtren en el repositorio público; las demás ConVars protegidas (URLs) se definen en los archivos cfg versionados.

Los mensajes de chat que ven los jugadores están en [`addons/sourcemod/translations/`](../../addons/sourcemod/translations/) (`<name>.phrases.txt`) y se pueden traducir/editar ahí.

---

## Índice

**Plugins personalizados**

| Plugin | Resumen |
|--------|-----------|
| [l4d2_queue](#l4d2_queue) | Cola de jugadores — muestra quién juega después y permite que los jugadores pidan un lugar |
| [l4d2_friendly_fire_control](#l4d2_friendly_fire_control) | Expulsa a los jugadores que superan un límite de fuego amigo |
| [l4d2_early_victory](#l4d2_early_victory) | Salta el último mapa cuando la partida ya está decidida |
| [l4d2_afk_to_spec](#l4d2_afk_to_spec) | Mueve a los jugadores AFK a espectador durante el ready-up |
| [l4d2_block_spec_during_tank](#l4d2_block_spec_during_tank) | Impide que los supervivientes cambien de equipo mientras el tank está vivo |
| [l4d2_no_skip_getup_animation](#l4d2_no_skip_getup_animation) | Impide saltarse la animación de levantarse cambiando de equipo |
| [l4d2_alltalk_before_round_start](#l4d2_alltalk_before_round_start) | Activa el all-talk antes de que empiece la primera ronda |
| [l4d2_tank_is_comming](#l4d2_tank_is_comming) | Avisa a todos cuando se acerca el punto de aparición del tank |
| [l4d2_spec_lister](#l4d2_spec_lister) | Permite que los espectadores elijan qué equipo escuchan |
| [l4d2_forced_names](#l4d2_forced_names) | Fija un nombre para SteamIDs específicos |
| [l4d2_campaign_vote](#l4d2_campaign_vote) | Permite que cualquier jugador vote para cambiar a cualquier campaña instalada |
| [l4d2_lerp_advisor](#l4d2_lerp_advisor) | Indica a los jugadores con un lerp inválido qué comandos de red ejecutar |

**Plugins de estadísticas (mantenidos en l4d2-playstats-hub)**

| Plugin | Resumen |
|--------|---------|
| [l4d2_playstats_sync, l4d2_gameinfo_sync, l4d2_ranking, l4d2_show_patent_icon, l4d2_weapon_skins](#plugins-de-estadísticas-l4d2-playstats-hub) | Estadísticas, partida en vivo, ranking, rangos y skins de armas de l4d2.com.br |

**Plugins adaptados (de terceros)**

| Plugin | Autor original | Resumen |
|--------|-----------------|-----------|
| [l4d2_mix](#l4d2_mix-adaptado) | Luckylock (LuckyServ) | Elección de capitanes/equipos (mix) mediante menús en el juego |
| [annoyance_exploit_fixes](#annoyance_exploit_fixes-adaptado) | Sir (SirPlease) | Bloquea el abuso de callvote y el flood de chat mediante `bugpause` |

---

# Plugins personalizados

## l4d2_queue

**Fuente:** [`scripting/l4d2_queue.sp`](../../addons/sourcemod/scripting/l4d2_queue.sp) · **Versión:** 2.0.0

**Qué hace** — Mantiene una cola ordenada de todos los jugadores humanos del servidor, en el orden en que se conectaron, y la usa para decidir quién juega después. La cola se guarda en `addons/sourcemod/data/l4d2_queue.txt`, así que sobrevive a los cambios de mapa y a las recargas del plugin. Comportamiento que ven los jugadores:

- Cuando empieza un juego nuevo después de uno terminado, la cola se reordena: el equipo ganador pasa al frente y el equipo perdedor pasa al final, detrás de todos los que estaban esperando. Durante unos 60 segundos después de que empieza la ronda, los equipos se organizan automáticamente para que los primeros jugadores de la cola (saltando a quien tenga un lerp inválido) sean los que juegan. Usar `!slot` mientras tanto muestra *"The teams are being arranged automatically, please wait a moment."*
- `!fila` / `!queue` muestra la lista de espera en orden (`Queue:` seguido de `1º`, `2º`…). Los jugadores de los equipos iniciales quedan fuera, los jugadores que están en un equipo aparecen resaltados, y no se muestra nada mientras no haya más jugadores que lugares.
- `!vaga` / `!slot` durante el ready-up de un juego nuevo (marcador 0–0):
  - Si un equipo tiene un lugar libre, el jugador entra en él: *"You have taken a slot in the game."*
  - Si no, toma el lugar del jugador más atrasado en la cola entre los que están jugando detrás de él. Quien lo pidió ve *"You have claimed a slot, {player} was moved to spectators."* y el jugador desplazado recibe *"{player} has claimed your slot because they were ahead of you in the queue."*
  - Si todos los que están jugando están por delante de él: *"Everyone on the teams is ahead of you in the queue."*
  - Un jugador solo puede tomar el lugar del mismo jugador `l4d2_queue_max_claims` veces antes de que el juego empiece: *"You have already claimed a slot from {player} too many times."*
- Durante un juego en curso, solo los jugadores de los equipos iniciales pueden usar `!slot`, para volver a su equipo original en lugar de un sustituto: *"During the game only players from the starting teams can request a slot."* Si el sustituto está controlando el tank, la petición espera: *"{player} is controlling the tank, request your slot again when the tank dies."* `!slot` no hace nada después de que termina la ronda.
- No se puede pedir un lugar mientras hay un mix en curso: *"You can only request a slot at the start of a new game and while no mix is in progress."*
- Un jugador con un lerp inválido (fuera de `sm_min_lerp` / `sm_max_lerp` de `lerpmonitor`) no puede pedir un lugar: *"Your lerp ({n}ms) is invalid. Adjust it between {min}ms and {max}ms before requesting a slot."*
- 30 segundos después de que empieza una ronda, durante el ready-up de un juego nuevo con más jugadores que lugares, cada espectador recibe el recordatorio: *"Check the !queue. If you are ahead of someone playing, use !slot."*
- Un jugador desconectado conserva su lugar durante `l4d2_queue_disconnect_timeout` segundos antes de ser eliminado. Al final de la segunda ronda de un mapa, la cola se muestra a todos después de `l4d2_queue_endmap_delay` segundos (para que primero aparezca el panel de MVP/estadísticas).

**Objetivo** — Hacer que la rotación en un servidor lleno sea justa y transparente, para que nadie pierda su turno y todos puedan ver quién sigue.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `l4d2_queue_disconnect_timeout` | `300` | Segundos que un jugador desconectado permanece en la cola antes de ser eliminado |
| `l4d2_queue_endmap_delay` | `8.0` | Segundos después del final de la 2.ª ronda del mapa antes de mostrar la cola (espera primero el MVP/estadísticas) |
| `l4d2_queue_max_claims` | `2` | Cuántas veces un jugador puede tomar el lugar del mismo jugador antes de que el juego empiece |

**Comandos**

| Comando | Acceso | Descripción |
|---------|--------|-------------|
| `sm_fila` / `sm_queue` | todos | Muestra la cola actual |
| `sm_vaga` / `sm_slot` | todos | Pide un lugar disponible |

**Cómo configurar** — Define las ConVars en `shared_cvars.cfg`, por ejemplo `confogl_addcvar l4d2_queue_disconnect_timeout 300`.

---

## l4d2_friendly_fire_control

**Fuente:** [`scripting/l4d2_friendly_fire_control.sp`](../../addons/sourcemod/scripting/l4d2_friendly_fire_control.sp) · **Versión:** 1.0.0

**Qué hace** — Mientras una ronda está en juego, registra el daño de fuego amigo entre supervivientes humanos. Cada jugador tiene un acumulador que sube con el daño que hace a un compañero y baja `decrement` cada `interval` segundos. Cuando el acumulador llega a `limit`, el jugador es expulsado y el juego se pausa (los jugadores reanudan normalmente con `!unpause`, igual que en una pausa por crash); todos ven *"{player} was kicked for friendly fire."* y el jugador expulsado recibe el motivo *"You were kicked for friendly fire."* El daño accidental ocasional se disipa y nunca provoca una expulsión; solo el daño al equipo continuo/repetido lo hace.

El daño se ignora cuando la víctima está incapacitada, colgando o cayendo de un borde, atrapada por un infectado especial, o tiene una vida total (permanente + temporal) igual o inferior a `min_health` (por ejemplo, rematar por piedad a un compañero con poca vida). Los contadores se reinician cuando termina la ronda.

**Objetivo** — Desalentar automáticamente el daño intencional o repetido al propio equipo sin necesitar un admin conectado, perdonando algún disparo perdido.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `l4d2_friendly_fire_control_enabled` | `1` | Activa (`1`) / desactiva (`0`) el plugin |
| `l4d2_friendly_fire_control_interval` | `1.0` | Intervalo (s) en el que disminuye el daño de FF acumulado |
| `l4d2_friendly_fire_control_decrement` | `1.0` | Cantidad que se resta del acumulador en cada intervalo |
| `l4d2_friendly_fire_control_limit` | `20.0` | Daño de FF acumulado que provoca la expulsión |
| `l4d2_friendly_fire_control_min_health` | `10.0` | El FF se ignora cuando la vida total de la víctima es igual o inferior a este valor |

**Comandos** — Ninguno.

**Cómo configurar** — Las cinco ConVars en `shared_cvars.cfg`. Baja `limit` para un servidor más estricto; sube `decrement` o baja `interval` para perdonar más rápido.

---

## l4d2_early_victory

**Fuente:** [`scripting/l4d2_early_victory.sp`](../../addons/sourcemod/scripting/l4d2_early_victory.sp) · **Versión:** 1.7.0

**Rendición por equipo** — `!surrender` o `!render` abre una votación para los humanos del propio equipo, incluidos los muertos. Los espectadores no pueden iniciar ni votar. Por defecto se permite desde el segundo mapa, en cualquier round, tras 10 segundos live. Los votos Sí deben superar estrictamente el 50% del electorado inicial: hacen falta tres de cuatro. Las abstenciones no aprueban la rendición. Si un elector sale o cambia de equipo se cancela; los intentos rechazados o cancelados tienen una espera de 60 segundos por equipo.

Al aprobar, el resultado queda fijado: el rival recibe `max(marcador A, marcador B) + l4d2_surrender_points` (250 por defecto), conservando los puntos y la identidad del equipo rendido al cambiar de lados. Se bloquean nuevas votaciones, se anuncia cada paso y todos mueren tras `l4d2_early_victory_slay_delay`. Si era el primer round, se espera al segundo, se protege `l4d2_surrender_forcestart_delay` contra ready o forcestart anticipados, se ejecuta `sm_forcestart`, se espera el evento live y se mata a todos tras `l4d2_surrender_second_slay_delay`. Este flujo requiere ReadyUp manual o por equipo (modos 1 o 3), sin auto-ready; la rendición en el segundo round no tiene esta restricción. Si el forcestart no produce live a tiempo, se reintenta con aviso a los jugadores y diagnóstico en el log; no se cambia de campaña con rounds incompletos. Los infectados humanos se preparan al aprobar, después del live del segundo round y antes de cierres naturales o slays, asegurando los spawns requeridos por la API. La campaña cambia solo después del segundo round y de `l4d2_early_victory_change_delay`, con un mínimo efectivo de dos segundos para escribir las estadísticas. El sincronizador existente envía los archivos en el próximo round; este plugin no espera confirmación HTTP. La rendición se habilita independientemente de la victoria anticipada. Las reglas son fijas: desde el segundo mapa, cualquier round, 10 segundos live y mayoría estricta del electorado inicial. La duración reutiliza `l4d2_early_victory_vote_duration`.

**Qué hace** — Detecta cuando una campaña versus ya está decidida antes de su último mapa. Durante la segunda ronda del capítulo configurado (por defecto el 4.º mapa, nunca un final), revisa el marcador cada 5 segundos (no mientras haya un tank vivo o un superviviente incapacitado). La partida está decidida cuando el equipo que juega de superviviente va por delante por al menos `min_diff`, o ya no puede quedar a menos de `min_diff` del otro equipo ni con la puntuación máxima que queda en el mapa. Entonces todos reciben *"Game decided ({score} x {score}). Losing team will vote."* y el equipo perdedor recibe una votación corta con el título *"Game decided, keep playing?"*:

- Si al menos la mitad del equipo perdedor vota Sí (los votos no emitidos cuentan como No) → *"Losing team chose to continue."* y la partida sigue con normalidad. Si la votación se cancela → *"Vote cancelled. Match continues."*
- Si no → *"No majority to continue. Ending match."*, suena un sonido de victoria, se anuncia la siguiente campaña (*"Next campaign: {name}"*) con una cuenta regresiva en pantalla (*"Next campaign: {name} - changing map in {n}s"*), todos mueren tras `slay_delay`, y el servidor cambia al primer mapa de la siguiente campaña tras `change_delay` segundos más.
- Durante la segunda ronda de ese capítulo, las votaciones para cambiar de campaña están bloqueadas: *"Map change blocked until the match ends."* Cuando se bloquea la votación de cambio de campaña y la rendición está habilitada para ese mapa y round, el mensaje indica usar `!surrender`. Durante un cierre ya aprobado, pide esperar la próxima campaña.

La siguiente campaña es la primera entrada de una cola de rotación (ver abajo); cuando la cola está vacía, es una aleatoria entre las 10 campañas oficiales que conoce el plugin (Dead Center, Dark Carnival, Swamp Fever, Hard Rain, The Parish, No Mercy, Death Toll, Dead Air, Blood Harvest, Cold Stream). La campaña en juego se quita de la cola al iniciar el mapa. Un admin puede añadir campañas a la cola o vaciarla con un menú (*"Queue the next campaigns (in queue: {n})"* / *"Clear list"*); cada cambio se anuncia (*"The next campaigns are: …"*).

**Objetivo** — Evitar jugar un último mapa sin sentido cuando el resultado ya está definido, y rotar el servidor a una campaña nueva de forma limpia.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `l4d2_early_victory_enabled` | `1` | Activa / desactiva |
| `l4d2_early_victory_chapter` | `4` | Capítulo (índice del mapa) que dispara la revisión |
| `l4d2_early_victory_min_diff` | `15` | Diferencia mínima de marcador necesaria para iniciar la votación |
| `l4d2_early_victory_vote_duration` | `15` | Duración de las votaciones de victoria anticipada y rendición, en segundos |
| `l4d2_early_victory_slay_delay` | `5.0` | Segundos después del anuncio antes de matar a todos |
| `l4d2_early_victory_change_delay` | `3.0` | Segundos después de matar a todos antes de cambiar de campaña |
| `l4d2_surrender_enabled` | `1` | Activa las votaciones de rendición |
| `l4d2_surrender_cooldown` | `60.0` | Espera por equipo tras intento rechazado o cancelado |
| `l4d2_surrender_points` | `250` | Puntos por encima del mayor marcador otorgados al rival |
| `l4d2_surrender_forcestart_delay` | `8.0` | Espera tras iniciar el segundo round antes del forcestart; mínimo 6 segundos para inicializar PlayStats |
| `l4d2_surrender_second_slay_delay` | `3.0` | Segundos live antes del slay del segundo round automático; mínimo 1 |

**Comandos**

| Comando | Acceso | Descripción |
|---------|--------|-------------|
| `l4d2_early_victory_queue "<Campaign>"` | servidor (cfg) | Añade una campaña oficial a la cola de rotación (una por línea); los nombres desconocidos se registran como error |
| `l4d2_early_victory_queue_lock` | servidor (cfg) | Bloquea la cola; las llamadas posteriores a `l4d2_early_victory_queue` se ignoran |
| `sm_setnextcampaign` | `ADMFLAG_CHANGEMAP` | Menú para añadir campañas a la cola o vaciarla |
| `sm_early_victory_debug` | `ADMFLAG_ROOT` | Muestra los marcadores internos y el desglose de bonificaciones para depuración |
| `sm_surrender`, `sm_render` | jugadores de los equipos | Vota para que el propio equipo se rinda y pierda la partida |

**Cómo configurar** — Define las ConVars mediante `confogl_addcvar` en `shared_cvars.cfg` y, justo después, arma la rotación de campañas con líneas `l4d2_early_victory_queue` directas, terminando con `l4d2_early_victory_queue_lock`. Ejemplo (resumido de [`zonemod/shared_cvars.cfg`](../../cfg/cfgogl/zonemod/shared_cvars.cfg)):

```
confogl_addcvar l4d2_early_victory_chapter 4
confogl_addcvar l4d2_early_victory_min_diff 15
l4d2_early_victory_queue "The Parish"
l4d2_early_victory_queue "Hard Rain"
l4d2_early_victory_queue "Death Toll"
l4d2_early_victory_queue_lock
```

---

## l4d2_afk_to_spec

**Fuente:** [`scripting/l4d2_afk_to_spec.sp`](../../addons/sourcemod/scripting/l4d2_afk_to_spec.sp) · **Versión:** 1.0.0

**Qué hace** — Durante el ready-up, vigila a los jugadores AFK (sin mover el ratón, pulsar teclas ni escribir en el chat). Cuando los dos equipos están llenos y al menos un espectador está esperando para jugar, un jugador que lleva AFK más tiempo que el límite pasa a espectador para liberar su lugar, y todos ven *"{player} was moved to spectators after being AFK for {n} seconds."* El límite depende del juego: `new_game_timeout` mientras el marcador es 0–0, `ongoing_game_timeout` una vez que el juego ha empezado. Solo actúa durante el ready-up, así que una ronda en juego nunca se interrumpe.

**Objetivo** — Evitar que los jugadores AFK ocupen un lugar mientras los jugadores activos esperan, sin interferir en una ronda en curso.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `l4d2_afk_to_spec_new_game_timeout` | `180` | Segundos que un jugador puede estar AFK durante el ready-up mientras el marcador es 0–0 |
| `l4d2_afk_to_spec_ongoing_game_timeout` | `360` | Segundos que un jugador puede estar AFK durante el ready-up después de que el juego ha empezado |

**Comandos** — Ninguno.

**Cómo configurar** — Define los dos límites en `shared_cvars.cfg`.

---

## l4d2_block_spec_during_tank

**Fuente:** [`scripting/l4d2_block_spec_during_tank.sp`](../../addons/sourcemod/scripting/l4d2_block_spec_during_tank.sp) · **Versión:** 1.0.0

**Qué hace** — Mientras el tank está vivo, impide que los supervivientes cambien de equipo (`jointeam`, `sm_spectate`/`sm_spec`/`sm_s`). El jugador bloqueado recibe *"Tank is alive, use !pause to change team."* La restricción se levanta mientras el juego está en pausa, así que los cambios legítimos siguen siendo posibles.

**Objetivo** — Evitar que los jugadores esquiven el tank o abusen de pasar a espectador en mitad del tank para reiniciar el control/aggro.

**ConVars** — Ninguna.

**Comandos** — Intercepta `sm_spectate`, `sm_spec`, `sm_s` y `jointeam` (no registra comandos nuevos).

**Cómo configurar** — No necesita configuración; basta con cargarlo.

---

## l4d2_no_skip_getup_animation

**Fuente:** [`scripting/l4d2_no_skip_getup_animation.sp`](../../addons/sourcemod/scripting/l4d2_no_skip_getup_animation.sp) · **Versión:** 1.0.0

**Qué hace** — Bloquea el exploit en el que un jugador se salta la animación de levantarse (después de un pounce, un charge, etc.) pasando rápidamente a espectador y volviendo. Un superviviente que recibió cualquier daño en los últimos 5 segundos no puede pasar a espectador: `sm_spectate`/`sm_spec`/`sm_s` y `jointeam` a cualquier equipo que no sea el de los supervivientes se ignoran en silencio, así que la animación siempre se completa.

**Objetivo** — Eliminar un exploit de movimiento/tiempo y mantener las animaciones de levantarse iguales para todos.

**ConVars** — Ninguna.

**Comandos** — Intercepta `sm_spectate`, `sm_spec`, `sm_s` y `jointeam` (no registra comandos nuevos).

**Cómo configurar** — No necesita configuración; basta con cargarlo.

---

## l4d2_alltalk_before_round_start

**Fuente:** [`scripting/l4d2_alltalk_before_round_start.sp`](../../addons/sourcemod/scripting/l4d2_alltalk_before_round_start.sp) · **Versión:** 1.1.0

**Qué hace** — 10 segundos después de que empieza un mapa, activa `sv_alltalk` si el marcador sigue en 0–0 (el primer mapa de un juego), para que los dos equipos puedan hablar entre sí durante el calentamiento/ready-up, y lo desactiva en cualquier otro mapa. Cuando empieza la cuenta regresiva para jugar (de `readyup`), vuelve a desactivar el all-talk, restaurando las reglas de voz competitivas. Cada cambio se anuncia con *"All talk: ON"* / *"All talk: OFF"*.

**Objetivo** — Permitir una charla amistosa entre equipos antes de que empiece la partida y, después, aplicar automáticamente la voz solo entre el equipo cuando importa.

**ConVars** — Ninguna (controla el `sv_alltalk` del juego).

**Comandos** — Ninguno.

**Cómo configurar** — No necesita configuración; basta con cargarlo.

---

## l4d2_tank_is_comming

**Fuente:** [`scripting/l4d2_tank_is_comming.sp`](../../addons/sourcemod/scripting/l4d2_tank_is_comming.sp) · **Versión:** 1.0.0

**Qué hace** — Sigue el progreso de los supervivientes en el mapa respecto al porcentaje de aparición del tank y, a medida que el equipo se acerca, muestra una cuenta regresiva en el chat: *"Tank in {n}%"* (**Tank** en verde, porcentaje en verde claro). Los avisos aparecen al 15%, al 10% y luego cada 1% del 5% al 1%, cada uno una sola vez. Se detienen en cuanto el tank aparece de verdad y se reinician cuando la ronda empieza. No se muestra nada durante el ready-up ni las pausas.

**Objetivo** — Dar a los dos equipos un aviso justo y consistente de que el tank está por llegar, en lugar de depender de que la gente memorice los puntos de aparición.

**ConVars** — Ninguna (lee `versus_boss_buffer` y los datos de porcentaje de los jefes).

**Comandos** — Ninguno.

**Cómo configurar** — No necesita configuración; basta con cargarlo. Requiere los includes `l4d2_boss_percents` / `readyup` / `pause` al compilar (ya presentes en este repositorio).

---

## l4d2_spec_lister

**Fuente:** [`scripting/l4d2_spec_lister.sp`](../../addons/sourcemod/scripting/l4d2_spec_lister.sp) · **Versión:** 2.0.0

**Qué hace** — Permite que un espectador elija la voz de qué equipo quiere escuchar (por defecto: todos). `!hear` sin argumento abre un menú (*"Who do you want to hear?"*) con las opciones *Survivors + spectators*, *Infected + spectators*, *Spectators only* y *Everyone*; o pasa un argumento directamente (`!hear survivors|infected|spectators|all`), que lo confirma con *"You are now hearing: {choice}."* Los demás espectadores siempre se escuchan. La elección no tiene efecto mientras `sv_alltalk` está activado. 15 segundos después de que empieza un mapa (solo en la primera ronda), los espectadores reciben una pista sobre `!hear` cuando `l4d2_spec_lister_hint` es `1`. Los admins tienen un modo de transmisión (`sm_broadcast`): mientras está activado, todos los escuchan (*"{admin} is now talking to everyone."* / *"{admin} stopped talking to everyone."*).

**Objetivo** — Mejorar la experiencia de ver y narrar partidas, permitiendo aislar la comunicación de un equipo sin dejar de escuchar a los demás espectadores.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `l4d2_spec_lister_hint` | `1` | Muestra a los espectadores una pista sobre el comando `!hear`. `0`:ocultar, `1`:mostrar |

**Comandos**

| Comando | Acceso | Descripción |
|---------|--------|-------------|
| `sm_hear` | todos (espectadores) | Elige a quién escuchas como espectador. Sin argumento abre el menú; argumento opcional: `survivors` / `infected` / `spectators` / `all` |
| `sm_broadcast` | `ADMFLAG_CHAT` | Activa/desactiva el modo de transmisión — mientras está activado, todos te escuchan |

**Cómo configurar** — Define `l4d2_spec_lister_hint` en `shared_settings.cfg` (`zonemod` lo pone en `0`).

---

## l4d2_forced_names

**Fuente:** [`scripting/l4d2_forced_names.sp`](../../addons/sourcemod/scripting/l4d2_forced_names.sp) · **Versión:** 1.1.0

**Qué hace** — Vincula SteamIDs específicos a un nombre fijo. Un jugador vinculado recibe el nombre al entrar y, si se cambia el nombre, se le vuelve a poner el nombre fijo de inmediato. Se aceptan los formatos de id `STEAM_0` y `STEAM_1`. Con `l4d2_forced_names_hub 1`, también lee la lista guardada en el PlayStats Hub (**Administración > Nombres forzados**, `GET <playstats_url>/api/forced-names` con el `playstats_token`) cuando se ejecutan las configs y al comienzo de cada ronda, y la junta con el archivo: cuando los dos tienen el mismo jugador, vale el nombre del hub. Si el hub no responde, mantiene la última lista leída.

**Objetivo** — Mantener a los jugadores conocidos con un nombre consistente y reconocible — útil para la integridad de las estadísticas/ranking y para la moderación.

**ConVars**

| ConVar | Predeterminado | Descripción |
|---|---|---|
| `l4d2_forced_names_hub` | `0` | `1` también lee los nombres forzados del PlayStats Hub; este servidor la deja en `1` en `shared_cvars.cfg`. |

**Comandos** — Ninguno.

**Cómo configurar** — Edita [`configs/forced_names.cfg`](../../addons/sourcemod/configs/forced_names.cfg), un par `"<steamid>" "<name>"` por jugador, en formato KeyValues:

```
"ForcedNames"
{
	"STEAM_0:0:90628109" "Altair" // https://steamcommunity.com/profiles/76561198141521946
}
```

El plugin lee este archivo con la API `KeyValues` (no con `exec`), al iniciarse y en cada ejecución de config — no hace falta recargarlo a mano, y los nombres con unicode no se recortan como pasaría con un cfg ejecutado con `exec`.

---

Los jugadores de este servidor están en el hub; el archivo solo tiene un ejemplo.

## l4d2_campaign_vote

**Fuente:** [`scripting/l4d2_campaign_vote.sp`](../../addons/sourcemod/scripting/l4d2_campaign_vote.sp) · **Versión:** 1.0.0

**Qué hace** — Permite que cualquier jugador explore todas las campañas instaladas — oficiales y personalizadas — e inicie una votación de cambio de mapa desde un menú, sin necesitar permisos de admin. Escribir `!votecampaign` (o `!votecamp`) abre un menú con el título *"Choose a campaign to start a map change vote:"* que lista todas las campañas en orden alfabético. La lista se arma leyendo los archivos `missions/*.txt` desde dentro de los addons VPK montados (mediante el sistema de archivos de Valve), así que siempre refleja lo que está realmente instalado. Las 14 campañas oficiales aparecen con su nombre en inglés (Dead Center, Dark Carnival, …); las campañas personalizadas aparecen con el título de su propio VPK. Seleccionar una entrada ejecuta `callvote changemission <Name>` como si el jugador lo hubiera escrito, iniciando la votación estándar de cambio de campaña. Si no se puede leer la lista de campañas, el jugador recibe *"Could not read the campaign list."*

**Objetivo** — Dar a los jugadores una forma simple y autónoma de proponer un cambio de campaña mediante la votación nativa del juego, incluidas las campañas personalizadas.

**ConVars** — Ninguna.

**Comandos**

| Comando | Acceso | Descripción |
|---------|--------|-------------|
| `sm_votecampaign` / `sm_votecamp` | todos | Abre el menú de campañas e inicia una votación de cambio de mapa para la campaña elegida |
| `sm_listcampaigns` | `ADMFLAG_GENERIC` | Muestra en la consola el nombre en bruto y el DisplayTitle de cada campaña encontrada en la carpeta missions |
| `sm_refreshcampaigns` | `ADMFLAG_GENERIC` | Recarga `campaign_vote.cfg` y limpia la lista de campañas en caché para que se vuelva a leer la próxima vez que se abra el menú |

**Cómo configurar** — Opcionalmente, edita [`configs/campaign_vote.cfg`](../../addons/sourcemod/configs/campaign_vote.cfg) (formato KeyValues) para ocultar campañas del menú (`IgnoredCampaigns`) o cambiar el título que se muestra de una campaña (`CustomTitles`); `<name>` debe coincidir exactamente con el `Name` en bruto de la misión (consulta `sm_listcampaigns`). El archivo se vuelve a leer en cada ejecución de config. Los textos que ven los jugadores (título del menú y mensajes) están en [`addons/sourcemod/translations/l4d2_campaign_vote.phrases.txt`](../../addons/sourcemod/translations/l4d2_campaign_vote.phrases.txt) (inglés, portugués y español). La votación `changemission` debe estar habilitada en la configuración de votaciones del servidor para que la votación realmente empiece.

---

## l4d2_lerp_advisor

**Fuente:** [`scripting/l4d2_lerp_advisor.sp`](../../addons/sourcemod/scripting/l4d2_lerp_advisor.sp) · **Versión:** 2.0.0

**Qué hace** — Funciona junto con `lerpmonitor`: **no** cambia la configuración de nadie (el servidor no puede forzar las CVars del cliente), solo *aconseja*. Cuando un jugador se conecta (unos 5 segundos después de estar autorizado y dentro del servidor) o entra en el equipo de los supervivientes/infectados, el plugin revisa su lerp y, si está fuera del rango permitido, muestra un mensaje corto de dos líneas — un encabezado de color (*"Invalid lerp! Paste this in the game console:"*) seguido de los comandos exactos que el jugador debe pegar en la consola del juego (la línea de comandos se deja sin color para copiar/pegar sin problemas, y también se repite en su consola). Las revisiones al conectarse se hacen aunque el jugador esté como espectador, así que recibe el aviso antes de intentar jugar. El consejo solo se muestra durante el ready-up (cuando `readyup` está cargado), y una espera de 3 segundos evita mensajes duplicados.

El valor del lerp y el rango válido se toman **por completo de `lerpmonitor`** — el lerp actual viene de su native `LM_GetCurrentLerpTime` y los límites de sus CVars `sm_min_lerp` / `sm_max_lerp` — así que cambiar los límites ahí cambia automáticamente cuándo aparece este aviso, sin nada que actualizar aquí. Si `lerpmonitor` no está cargado, el plugin no dice nada.

**Objetivo** — Dar a los jugadores con un lerp malo/por defecto una solución clara y autónoma, en lugar de que `lerpmonitor` solo los mueva a espectador, sin duplicar nada de su lógica de detección.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `l4d2_lerp_advisor_enabled` | `1` | Activa / desactiva el mensaje de aviso |

Los comandos sugeridos (`cl_interp 0; cl_interp_ratio 0; rate 100000; cl_cmdrate 100; cl_updaterate 100`) están fijos en el código del plugin, así que se muestran al jugador completos (un valor de CVar definido mediante `confogl_addcvar` se cortaría en el primer `;`).

**Comandos** — Ninguno.

**Cómo configurar** — Define `l4d2_lerp_advisor_enabled` en `shared_cvars.cfg`. Requiere que `lerpmonitor` esté cargado (proporciona el valor del lerp y el rango `sm_min_lerp` / `sm_max_lerp`). Los textos que ven los jugadores están en [`addons/sourcemod/translations/l4d2_lerp_advisor.phrases.txt`](../../addons/sourcemod/translations/l4d2_lerp_advisor.phrases.txt) (inglés, portugués y español).

---

# Plugins de estadísticas (l4d2-playstats-hub)

`l4d2_playstats_sync`, `l4d2_gameinfo_sync`, `l4d2_ranking`, `l4d2_show_patent_icon` y `l4d2_weapon_skins`, con sus traducciones y `configs/weapon_skins.cfg`, no están en este repositorio. Se mantienen en [l4d2-playstats-hub](https://github.com/altair-sossai/l4d2-playstats-hub), junto con el sitio con el que hablan, l4d2.com.br. `l4d2_playstats`, el plugin de Competitive Rework que escribe los archivos de estadísticas, sigue aquí.

- **Deploy** — en cada deploy, el pipeline de este repositorio ([`azure-pipelines.yml`](../../azure-pipelines.yml)) descarga `l4d2-playstats-hub-plugins.zip` de la [última release del hub](https://github.com/altair-sossai/l4d2-playstats-hub/releases/latest) y copia su carpeta `addons` sobre el servidor. `l4d2_gameinfo_sync` y `l4d2_weapon_skins` van a `plugins/` (carga automática); los otros tres van a `plugins/optional/`.
- **Carga** — `cfg/cfgogl/<mod>/shared_plugins.cfg` los carga, como antes.
- **Ajustes que quedan aquí** — las ConVars de cada modo en `shared_cvars.cfg` (`ranking_show_motd_panel`, `patent_icon_*`, `gameinfo_*`, `weapon_skins_*`).
- **Dirección del sitio** — `cfg/server.cfg` define `playstats_url "http://124.198.128.43:5000"` (HTTP simple, para que el navegador del juego también la abra), `playstats_public_url "https://l4d2.com.br"` (la dirección que los jugadores leen en el chat) y `l4d2_web_url` (la lee el plugin del anti-cheat).
- **Secretos** — fuera del repositorio. El pipeline escribe `cfg/server_secrets.cfg` a partir de variables secretas, y `server.cfg` lo ejecuta. Para rotar uno, cambia la variable del pipeline y haz el deploy de nuevo; para el token del anti-cheat, cambia también la clave de `l4d2-zone-server` en la API del anti-cheat.
- **Eliminados** — las ConVars antiguas `playstats_access_token` y `ranking_url`, y `playstats_url` apuntando a la API antigua de PlayStats.

Qué hace cada plugin, sus ConVars y comandos: [Conectar un servidor de juego](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/game-server.es.md) y la [carpeta de plugins](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/plugins/README.es.md) del hub. Para jugadores y admins: [tienda de skins](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/skin-shop.es.md), [servidor en vivo](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/live-server.es.md), [rangos](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/patents.es.md) y [páginas dentro del juego](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/in-game-pages.es.md).

---

# Plugins adaptados (de terceros)

## l4d2_mix (adaptado)

> **No es obra original.** Este plugin fue creado por **Luckylock (LuckyServ)** — repositorio original: <https://github.com/LuckyServ/>. La copia de este repositorio fue **modificada con correcciones y ajustes para este servidor** (integración con la cola, mensajes traducidos/localizados y ajustes de comportamiento). Todo el mérito del plugin original es de su autor.

**Fuente (versión de este servidor):** [`scripting/l4d2_mix.sp`](../../addons/sourcemod/scripting/l4d2_mix.sp) · **Versión:** 5.1.0

**Qué hace** — Organiza un "mix": los jugadores votan para empezar, todos pasan a espectador, los capitanes se eligen por votación y los capitanes eligen sus equipos mediante menús en el juego. Mensajes que ven los jugadores (con el prefijo *"Mix Manager:"*):

- Un mix solo se puede iniciar durante el ready-up de un juego nuevo (marcador 0–0), con los dos equipos llenos (*"Both teams must be full to start a mix."*).
- Cualquiera que esté en un equipo puede usar `!mix` para votar por el inicio. El progreso se muestra a medida que llegan los votos (*"{player} has voted to start a mix. (votes needed: {n})"*), y el mix empieza cuando se alcanzan los votos suficientes (*"Started by vote."*) o cuando un admin lo inicia (*"Started by admin {name}."*). Después de cada mix completado, el siguiente en el mismo ready-up necesita `l4d2_mix_additional_players_after_mix` votos más.
- `!mix <captain1> <captain2>` propone dos capitanes (jugadores de los equipos, por su nombre o el comienzo del nombre) e inicia una votación de sí/no entre los jugadores de los equipos (*"{player} proposed {a} and {b} as captains."*); se aprueba con más de la mitad de ellos votando Sí (*"Captains approved!"*). Un admin que lo usa inicia el mix con esos capitanes al momento.
- Protecciones contra estados inválidos: *"Mix has already started."*, *"A mix cannot be started during a live round."*, *"You cannot start a mix as a spectator."*, *"Mix is not available in 1v1 matches."*
- Durante la elección, los jugadores no pueden unirse solos a un equipo: *"You cannot join a team without being picked."*
- `!rmix` empieza un mix por el ranking de la comunidad en lugar de capitanes, con las mismas comprobaciones y los mismos votos necesarios que `!mix` (*"{jugador} wants to start a mix from the community ranking. Type !rmix to vote (votes needed: {n})."*, en portugués para los clientes en portugués). Con votos suficientes, el chat dice *"Starting the mix from the community ranking..."* y el plugin le pide al sitio (`POST <playstats_url>/api/community/mix`, con el `playstats_token`) dos equipos equilibrados. Todos pasan a espectador, cada jugador se mueve a su equipo y el chat muestra una línea por equipo (*"Survivors: a, b, c, d"* e *"Infected: e, f, g, h"*), con los nombres largos acortados. Si algún jugador todavía no está en el ranking de la comunidad, el chat dice quién es y el mix no empieza; si el sitio no responde, sugiere `!mix`. Empezar uno aumenta los votos necesarios para el siguiente mix, como `!mix`. Necesita [REST in Pawn](https://github.com/ErikMinekus/sm-ripext) y el módulo del ranking de la comunidad activado en el sitio.
- Si un jugador de los equipos se va durante el mix, el mix se cancela. La primera vez, se le avisa de que abandonar otra vez conlleva un ban; la segunda vez (antes de que el juego empiece) se le banea durante `l4d2_mix_abandon_ban_time` minutos.
- `sm_kickspecs` queda bloqueado durante un mix y durante `l4d2_mix_kickspecs_block_time` segundos después de que termina.
- Un admin puede detenerlo con `!stopmix` (*"Stopped by admin {name}."*); usarlo cuando no hay nada en curso devuelve *"No mix is currently in progress."*

**Objetivo** — Ofrecer una selección de equipos justa, basada en capitanes, para partidas pug/mix, dirigida por los propios jugadores y con la posibilidad de que un admin intervenga.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `l4d2_mix_start_votes` | `2` | Número de votos necesarios para iniciar un mix (1–8) |
| `l4d2_mix_additional_players_after_mix` | `2` | Jugadores extra que deben votar después de cada mix iniciado, antes de que el juego empiece (`0` lo desactiva) |
| `l4d2_mix_kickspecs_block_time` | `40` | Segundos después del final de un mix durante los cuales `sm_kickspecs` sigue bloqueado (`0` lo desactiva) |
| `l4d2_mix_abandon_ban_time` | `30` | Minutos de ban para un jugador que abandona un mix por segunda vez (`0` desactiva el ban) |
| `l4d2_mix_captain_vote_duration` | `20` | Segundos que la votación de propuesta de capitanes (`!mix <captain1> <captain2>`) permanece abierta |

**Comandos**

| Comando | Acceso | Descripción |
|---------|--------|-------------|
| `sm_mix` | todos | Vota para iniciar un mix; un admin con `ADMFLAG_CHANGEMAP` lo inicia al momento |
| `sm_mix <captain1> <captain2>` | todos | Propone dos capitanes e inicia una votación entre los jugadores de los equipos; un admin inicia el mix con ellos al momento |
| `sm_mix <captain>` | `ADMFLAG_CHANGEMAP` | Inicia el mix con ese jugador como primer capitán; el segundo capitán se vota como siempre |
| `sm_rmix` | todos | Vota para empezar un mix con los equipos divididos por el ranking de la comunidad; un admin con `ADMFLAG_CHANGEMAP` lo empieza al instante |
| `sm_stopmix` | `ADMFLAG_CHANGEMAP` | Detiene el mix actual |

**Cómo configurar** — Define las ConVars en `shared_cvars.cfg`, por ejemplo `confogl_addcvar l4d2_mix_start_votes 2`.

---

## annoyance_exploit_fixes (adaptado)

> **No es obra original.** Este plugin fue creado por **Sir** como parte de [SirPlease/L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework). La copia de este repositorio fue **modificada con una corrección para este servidor** (bloqueo de `bugpause`, ver abajo). Todo el mérito del plugin original es de su autor.

**Fuente (versión de este servidor):** [`scripting/annoyance_exploit_fixes.sp`](../../addons/sourcemod/scripting/annoyance_exploit_fixes.sp) · **Versión:** 0.2.1

**Qué hace** — Una recopilación de pequeñas correcciones para comportamientos molestos/explotables de los clientes. Originalmente: bloquea una votación mientras todavía no se permite una nueva (*"A vote can't be called right now, try again in {n}s!"*), bloquea las votaciones de expulsión que no apuntan a un compañero de equipo, bloquea la autoexpulsión y (en partidas CEDAPug) bloquea las votaciones de volver al lobby/cambiar de campaña en mitad de la partida. La copia de este servidor además bloquea por completo el comando nativo `bugpause` del cliente, siempre, para todos los clientes. `bugpause` se dispara cuando un jugador abre la ventana integrada "Report a Bug" de L4D2 — una función antigua cuyos reportes Valve ya no lee — y el motor difunde una notificación en el chat sin ningún límite de frecuencia, así que un jugador puede asignarlo a una tecla e inundar el chat de todos ([Valve issue #2765](https://github.com/ValveSoftware/Source-1-Games/issues/2765)). Como la función ya no sirve para nada, el bloqueo es incondicional.

**Objetivo** — Cerrar pequeñas formas en que los clientes pueden molestar o fastidiar a otros jugadores, incluido el flood de chat con `bugpause`.

**ConVars** — Ninguna.

**Comandos** — Intercepta `callvote` y `bugpause` (no registra comandos nuevos).

**Cómo configurar** — No necesita configuración; se carga para todo el servidor desde [`cfg/generalfixes.cfg`](../../cfg/generalfixes.cfg) (`sm plugins load fixes/annoyance_exploit_fixes.smx`), sin importar qué modo esté activo.
