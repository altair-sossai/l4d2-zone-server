# Plugins Personalizados — l4d2-zone-server

🌐 [English](README.md) | [Português](README.pt.md) | **Español**

Este documento describe los plugins mantenidos en este repositorio:

- **Plugins personalizados** — escritos específicamente para este servidor.
- **Plugins adaptados** — creados por otros autores y modificados aquí (correcciones y ajustes) para adaptarse a este servidor. **No son obra original**; el autor y el repositorio originales se acreditan en cada sección.

Para el resto de plugins de terceros que vienen sin modificaciones con la base [ZoneMod / L4D2 Competitive Rework](https://github.com/SirPlease/L4D2-Competitive-Rework), consulta a sus autores originales.

- **Fuentes:** [`addons/sourcemod/scripting/`](../../addons/sourcemod/scripting/) (`.sp`)
- **Compilados:** [`addons/sourcemod/plugins/optional/`](../../addons/sourcemod/plugins/optional/) (`.smx`) — excepto `l4d2_gameinfo_sync` y `l4d2_weapon_skins`, que están en `plugins/` (carga automática), y `annoyance_exploit_fixes`, que está en `plugins/fixes/`
- **Script de compilación:** [`ps/compile-custom-plugins.ps1`](../../ps/compile-custom-plugins.ps1) — consulta [Compilar los plugins personalizados](../maintenance/compile-custom-plugins.es.md)

---

## Cómo funciona la configuración en este repositorio

La mayoría de estos plugins están en `optional/`, así que no se cargan automáticamente — se cargan de forma explícita y se configuran a través de la capa de configuración de ZoneMod. Estos son los puntos de contacto:

| Archivo | Propósito |
|------|---------|
| `cfg/cfgogl/<mod>/shared_plugins.cfg`  | **Carga** cada plugin (`sm plugins load optional/<name>.smx`) |
| `cfg/cfgogl/<mod>/shared_cvars.cfg`    | **Define ConVars** mediante `confogl_addcvar <cvar> <value>` |
| `cfg/cfgogl/<mod>/shared_settings.cfg` | También define ConVars mediante `confogl_addcvar` (se usa para `l4d2_spec_lister_hint`) |
| `cfg/server.cfg`                       | Valores de todo el servidor que deben existir antes de cargar cualquier config de partida (`l4d2_web_url`) |
| `cfg/server_secrets.cfg`               | **Secretos** (tokens/claves de API) mediante `sm_cvar` — **ignorado por git**, nunca se sube; se ejecuta al inicio de `server.cfg` |

`<mod>` es la carpeta de config activa, principalmente [`zonemod`](../../cfg/cfgogl/zonemod/) y [`neomod`](../../cfg/cfgogl/neomod/).

> **Las ConVars marcadas como `PROTECTED`** se crean con `FCVAR_PROTECTED`, así que su valor nunca se muestra a los clientes. Solo los secretos reales (`playstats_access_token`, `l4d2_web_secret`) van en `cfg/server_secrets.cfg`, para que nunca se filtren en el repositorio público; las demás ConVars protegidas (URLs) se definen en los archivos cfg versionados.

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
| [l4d2_ranking](#l4d2_ranking) | Muestra el ranking de jugadores (en el juego + panel MOTD) |
| [l4d2_show_patent_icon](#l4d2_show_patent_icon) | Muestra el ícono de rango de cada jugador durante el ready-up |
| [l4d2_playstats_sync](#l4d2_playstats_sync) | Envía las estadísticas de las partidas a la API de PlayStats |
| [l4d2_gameinfo_sync](#l4d2_gameinfo_sync) | Sincroniza la información del juego en vivo, los eventos y el chat con el sitio |
| [l4d2_campaign_vote](#l4d2_campaign_vote) | Permite que cualquier jugador vote para cambiar a cualquier campaña instalada |
| [l4d2_lerp_advisor](#l4d2_lerp_advisor) | Indica a los jugadores con un lerp inválido qué comandos de red ejecutar |
| [l4d2_weapon_skins](#l4d2_weapon_skins) | Skins de armas por jugador, compradas en la tienda de skins con estrellas de MVP |

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

**Fuente:** [`scripting/l4d2_early_victory.sp`](../../addons/sourcemod/scripting/l4d2_early_victory.sp) · **Versión:** 1.6.0

**Qué hace** — Detecta cuando una campaña versus ya está decidida antes de su último mapa. Durante la segunda ronda del capítulo configurado (por defecto el 4.º mapa, nunca un final), revisa el marcador cada 5 segundos (no mientras haya un tank vivo o un superviviente incapacitado). La partida está decidida cuando el equipo que juega de superviviente va por delante por al menos `min_diff`, o ya no puede quedar a menos de `min_diff` del otro equipo ni con la puntuación máxima que queda en el mapa. Entonces todos reciben *"Game decided ({score} x {score}). Losing team will vote."* y el equipo perdedor recibe una votación corta con el título *"Game decided, keep playing?"*:

- Si al menos la mitad del equipo perdedor vota Sí (los votos no emitidos cuentan como No) → *"Losing team chose to continue."* y la partida sigue con normalidad. Si la votación se cancela → *"Vote cancelled. Match continues."*
- Si no → *"No majority to continue. Ending match."*, suena un sonido de victoria, se anuncia la siguiente campaña (*"Next campaign: {name}"*) con una cuenta regresiva en pantalla (*"Next campaign: {name} - changing map in {n}s"*), todos mueren tras `slay_delay`, y el servidor cambia al primer mapa de la siguiente campaña tras `change_delay` segundos más.
- Durante la segunda ronda de ese capítulo, las votaciones para cambiar de campaña están bloqueadas: *"Map change blocked until the match ends."*

La siguiente campaña es la primera entrada de una cola de rotación (ver abajo); cuando la cola está vacía, es una aleatoria entre las 10 campañas oficiales que conoce el plugin (Dead Center, Dark Carnival, Swamp Fever, Hard Rain, The Parish, No Mercy, Death Toll, Dead Air, Blood Harvest, Cold Stream). La campaña en juego se quita de la cola al iniciar el mapa. Un admin puede añadir campañas a la cola o vaciarla con un menú (*"Queue the next campaigns (in queue: {n})"* / *"Clear list"*); cada cambio se anuncia (*"The next campaigns are: …"*).

**Objetivo** — Evitar jugar un último mapa sin sentido cuando el resultado ya está definido, y rotar el servidor a una campaña nueva de forma limpia.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `l4d2_early_victory_enabled` | `1` | Activa / desactiva |
| `l4d2_early_victory_chapter` | `4` | Capítulo (índice del mapa) que dispara la revisión |
| `l4d2_early_victory_min_diff` | `15` | Diferencia mínima de marcador necesaria para iniciar la votación |
| `l4d2_early_victory_vote_duration` | `15` | Segundos que tiene el equipo perdedor para votar si continúa |
| `l4d2_early_victory_slay_delay` | `5.0` | Segundos después del anuncio antes de matar a todos |
| `l4d2_early_victory_change_delay` | `3.0` | Segundos después de matar a todos antes de cambiar de campaña |

**Comandos**

| Comando | Acceso | Descripción |
|---------|--------|-------------|
| `l4d2_early_victory_queue "<Campaign>"` | servidor (cfg) | Añade una campaña oficial a la cola de rotación (una por línea); los nombres desconocidos se registran como error |
| `l4d2_early_victory_queue_lock` | servidor (cfg) | Bloquea la cola; las llamadas posteriores a `l4d2_early_victory_queue` se ignoran |
| `sm_setnextcampaign` | `ADMFLAG_CHANGEMAP` | Menú para añadir campañas a la cola o vaciarla |
| `sm_early_victory_debug` | `ADMFLAG_ROOT` | Muestra los marcadores internos y el desglose de bonificaciones para depuración |

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

**Fuente:** [`scripting/l4d2_forced_names.sp`](../../addons/sourcemod/scripting/l4d2_forced_names.sp) · **Versión:** 1.0.0

**Qué hace** — Vincula SteamIDs específicos a un nombre fijo. Un jugador vinculado recibe el nombre al entrar y, si se cambia el nombre, se le vuelve a poner el nombre fijo de inmediato. Se aceptan los formatos de id `STEAM_0` y `STEAM_1`.

**Objetivo** — Mantener a los jugadores conocidos con un nombre consistente y reconocible — útil para la integridad de las estadísticas/ranking y para la moderación.

**ConVars** — Ninguna.

**Comandos** — Ninguno.

**Cómo configurar** — Edita [`configs/forced_names.cfg`](../../addons/sourcemod/configs/forced_names.cfg), un par `"<steamid>" "<name>"` por jugador, en formato KeyValues:

```
"ForcedNames"
{
	"STEAM_0:1:67149995" "Xei" // https://steamcommunity.com/profiles/76561198094565719
	"STEAM_0:1:28225724" "jon" // https://steamcommunity.com/profiles/76561198016717177
}
```

El plugin lee este archivo con la API `KeyValues` (no con `exec`), al iniciarse y en cada ejecución de config — no hace falta recargarlo a mano, y los nombres con unicode no se recortan como pasaría con un cfg ejecutado con `exec`.

---

## l4d2_ranking

**Fuente:** [`scripting/l4d2_ranking.sp`](../../addons/sourcemod/scripting/l4d2_ranking.sp) · **Versión:** 1.0.0

**Qué hace** — Muestra el ranking de jugadores alojado en `ranking_url`. `!ranking` abre un panel MOTD con el título *"L4D2 | Player Rankings"* con el sitio del ranking. Mientras un juego nuevo (marcador 0–0) todavía no ha empezado, el plugin también muestra el nombre del sitio y *"Type !ranking to check your position."* cada 200 segundos, y abre el panel una vez para cada jugador 60 segundos después de que entra. Todos los paneles dependen de `ranking_show_motd_panel`; con `0`, `!ranking` no hace nada.

**Objetivo** — Llevar el ranking competitivo a los jugadores directamente desde el servidor, en el chat y mediante un panel web.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `ranking_url` | `""` | URL del sitio del ranking (`PROTECTED`) |
| `ranking_show_motd_panel` | `1` | Muestra el panel MOTD con la URL del ranking (`1`/`0`) |

**Comandos**

| Comando | Acceso | Descripción |
|---------|--------|-------------|
| `sm_ranking` | todos | Abre el panel del ranking |

**Cómo configurar** — Define `ranking_url` y `ranking_show_motd_panel` en `shared_cvars.cfg`.

---

## l4d2_show_patent_icon

**Fuente:** [`scripting/l4d2_show_patent_icon.sp`](../../addons/sourcemod/scripting/l4d2_show_patent_icon.sp) · **Versión:** 1.0.0

**Qué hace** — Durante el ready-up de un juego nuevo (marcador 0–0), muestra el ícono de rango de cada jugador que está jugando como un sprite sobre su cabeza. Los niveles vienen de `GET {patent_icon_api_url}/api/players/patents`, que se actualiza al iniciar el mapa y cuando empieza un juego nuevo. Los sprites (`materials/sprites/patent_<level>_v<version>.vmt/.vtf`, niveles del 1 a `patent_icon_max_level`) se añaden a la tabla de descargas. Los supervivientes no ven los íconos de los jugadores infectados, y todos los íconos se quitan cuando la ronda empieza.

**Objetivo** — Mostrar la posición competitiva de forma visual en el juego, para que el rango de un jugador se reconozca de un vistazo.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `patent_icon_api_url` | `""` | URL del sitio que proporciona los niveles de rango (`PROTECTED`) |
| `patent_icon_version` | `1` | Versión de los archivos de íconos (`PROTECTED`) |
| `patent_icon_max_level` | `15` | Nivel máximo de rango (`PROTECTED`) |

**Comandos** — Ninguno.

**Cómo configurar** — Define las tres ConVars en `shared_cvars.cfg` (ninguna es un secreto; `zonemod` usa la versión de íconos `2`).

---

## l4d2_playstats_sync

**Fuente:** [`scripting/l4d2_playstats_sync.sp`](../../addons/sourcemod/scripting/l4d2_playstats_sync.sp) · **Versión:** 1.1.0

**Qué hace** — Hace de puente entre el plugin `l4d2_playstats.smx` y la API externa de PlayStats. 10 segundos después de que empieza cada ronda, envía todos los archivos de log de estadísticas que ese plugin escribió en `addons/sourcemod/logs/` a `POST {playstats_url}/api/statistics`, con el token de acceso en la cabecera `Authorization`. Los archivos que la API marca como procesados se borran y, después de cada envío correcto, el plugin pide al sitio (`{l4d2_web_url}/api/cache/clear`, con `l4d2_web_secret` en la cabecera `Authorization`) que limpie la caché del ranking. Las dos ConVars las crean `l4d2_gameinfo_sync` y `l4d2_weapon_skins`; si alguna está vacía, la caché no se limpia y el sitio la actualiza en una hora como máximo.

**Objetivo** — Guardar las estadísticas de cada partida en el servicio central de estadísticas para mantener actualizados los rankings/rangos.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `playstats_url` | `""` | URL de la API de PlayStats (`PROTECTED`) |
| `playstats_access_token` | `""` | Token de acceso de PlayStats (`PROTECTED`) |

**Comandos** — Ninguno.

**Cómo configurar** — Define `playstats_url` en `shared_cvars.cfg`; define el secreto **`playstats_access_token` en `cfg/server_secrets.cfg`** (ignorado por git):

```
sm_cvar playstats_access_token "your-token-here"
```

---

## l4d2_gameinfo_sync

**Fuente:** [`scripting/l4d2_gameinfo_sync.sp`](../../addons/sourcemod/scripting/l4d2_gameinfo_sync.sp) · **Versión:** 1.1.0

**Qué hace** — Mantiene el sitio (`l4d2_web_url`) al día con lo que pasa en el servidor, para que pueda mostrar el estado de la partida y el chat en vivo. Cada petición lleva `l4d2_web_secret` en la cabecera `Authorization`. Este plugin se carga desde `plugins/` (carga automática), no desde `optional/`.

- **Envía** la configuración de la partida, la información de la ronda, el marcador y los jugadores (cada 5 segundos), los eventos de la partida (ronda en juego/terminada, pausas, mix iniciado, tank apareció/murió, skeets, levels, crowns, vómitos de boomer que alcanzan al menos a `gameinfo_boomer_vomit_min_survivors` supervivientes, entre otros) y el chat, interceptando `say` y `say_team` (los mensajes que empiezan con `!` o `/` no se envían).
- **Recibe** mensajes escritos en el sitio, que se muestran en el juego como *"(External) {name}: {text}"*, y comandos de servidor encolados en el sitio, que ejecuta.
- **Al conectarse**, informa al sitio de la conexión del jugador. Si el sitio encuentra otras cuentas que se conectaron desde la misma dirección IP, sus nombres se muestran en la consola de todos y, cuando `gameinfo_related_accounts_chat` es `1`, se anuncian en el chat (*"{player} previously connected as {name}…"*).

**Objetivo** — Exponer al sitio el estado del servidor/partida y el chat en tiempo real, para funciones del sitio e integraciones.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `l4d2_web_url` | `""` | URL del sitio L4D2, compartida con `l4d2_weapon_skins` (`PROTECTED`) |
| `l4d2_web_secret` | `""` | Clave secreta del sitio L4D2 (el `SecretKey` del sitio), compartida con `l4d2_weapon_skins` (`PROTECTED`) |
| `gameinfo_related_accounts_chat` | `1` | Anuncia las cuentas relacionadas en el chat (`1`/`0`); el listado en la consola siempre se muestra |
| `gameinfo_boomer_vomit_min_survivors` | `3` | Número mínimo de supervivientes alcanzados para informar un evento de vómito de boomer |

**Comandos** — Intercepta `say` y `say_team` para reenviar el chat (no registra comandos nuevos).

**Cómo configurar** — `l4d2_web_url` se define en `cfg/server.cfg`; define el secreto **`l4d2_web_secret` en `cfg/server_secrets.cfg`** (ignorado por git). Las dos cvars las comparten todos los plugins que se comunican con el sitio. Define `gameinfo_related_accounts_chat` y `gameinfo_boomer_vomit_min_survivors` en `shared_cvars.cfg` (`zonemod` desactiva el anuncio en el chat).

```
sm_cvar l4d2_web_secret "your-secret-here"
```

---

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

## l4d2_weapon_skins

**Fuente:** [`scripting/l4d2_weapon_skins.sp`](../../addons/sourcemod/scripting/l4d2_weapon_skins.sp) · **Versión:** 3.1.0

> La documentación completa del sistema de skins (assets, funcionamiento interno del plugin, estrellas, tienda de skins y operación) está en la [wiki de Skins de Armas y Tienda de Skins](../weapon-skins/README.es.md). Esta sección es un resumen.

**Qué hace** — Permite que cada jugador use las skins de armas que compró en la tienda de skins del sitio (`{l4d2_web_url}/skins`) con **estrellas** — 1 estrella por cada MVP histórico (daño a SI o infectados comunes) en partidas competitivas. Hay skins para la SMG, la MAC-10 (SMG silenciada), la MP5, la pump shotgun, la chrome shotgun, la Magnum (Desert Eagle) y nueve armas cuerpo a cuerpo (fireaxe, katana, machete, bate de béisbol, bate de críquet, guitarra eléctrica, palanca, palo de golf y sartén). Son solo de textura y se entregan por FastDL, así que los jugadores no necesitan instalar ningún `.vpk`: el plugin cambia el arma a un modelo combinado y selecciona la familia de skin de la skin elegida. La skin acompaña al arma: si se suelta, quien la recoja la usa con la misma skin.

- **Solo se descargan las skins compradas.** Al iniciar el mapa, solo los materiales de las skins compradas por al menos un jugador (`GET {l4d2_web_url}/api/skins`) se añaden a la tabla de descargas. Las skins que tiene cada uno y las equipadas vienen de `GET {l4d2_web_url}/api/players/skins`. Ambas se actualizan cuando se ejecutan las configs, al empezar y al terminar la ronda, y cada 2 minutos mientras hay jugadores; las últimas respuestas válidas se guardan en caché en `addons/sourcemod/data/` para el primer mapa después de un reinicio, porque un servidor vacío hiberna.
- **Las compras nuevas** se equipan al momento y aparecen a partir del siguiente cambio de mapa (o al momento, cuando los archivos de la skin ya están en las descargas de este mapa porque otra persona ya la había comprado). Un jugador conectado recibe un aviso en el chat cuando llega una compra.
- **Cambiar de skin en el juego:** solo supervivientes, solo durante el ready-up (cuando `readyup` está cargado) y solo skins que el jugador tiene. Cada cambio se guarda en el sitio (`POST {l4d2_web_url}/api/players/{communityId}/skins/equip`, autenticado con `l4d2_web_secret`), así que las skins equipadas se mantienen sincronizadas entre el juego y el sitio.
- **Reembolso por temporada:** las skins compradas duran una temporada del ranking. En cada reinicio del ranking (cada 2 meses) las compras se reembolsan automáticamente y las estrellas gastadas vuelven; las skins recibidas como regalo se conservan.
- **Jugadores sin descargas:** cuando `weapon_skins_kick_no_downloads` es `1` (y las skins están activadas), un jugador cuyo juego tiene `cl_allowdownload` distinto de `1` o `cl_downloadfilter` distinto de `all`/`nosounds` es expulsado. El mensaje de expulsión indica qué ajuste está mal y su valor, da el comando de consola que lo corrige (`cl_allowdownload 1` o `cl_downloadfilter all`) y sugiere revisar `autoexec.cfg`/`config.cfg`; cada expulsión queda registrada en el log. Cuando es `0`, esos jugadores se quedan y las skins vistas en tercera persona vuelven a las predeterminadas para todos mientras ellos están en el servidor, así que nadie ve nunca un modelo de ERROR.
- **Limpieza de montones de armas:** cada vez que se suelta un arma principal, el plugin cuenta las armas principales soltadas por jugadores dentro de `weapon_skins_pile_radius` y quita las más antiguas por encima de `weapon_skins_pile_max` (por ejemplo, cuando los jugadores cambian de arma una y otra vez en los spawns infinitos de una saferoom). Los spawns de armas, las armas colocadas por el mapa, las armas secundarias, los objetos y las armas en la mano nunca se quitan.

Este plugin se carga desde `plugins/` (carga automática), no desde `optional/`, así que los archivos ya están en la tabla de descargas cuando los jugadores se conectan por primera vez.

**Objetivo** — Recompensar el rendimiento de MVP con skins de armas cosméticas compradas en la tienda de skins, sin obligar a los jugadores a instalar nada.

**ConVars**

| ConVar | Predeterminado | Descripción |
|--------|---------|-------------|
| `weapon_skins_enabled` | `0` | Activa las skins de armas |
| `l4d2_web_url` | `""` | URL del sitio L4D2, compartida con `l4d2_gameinfo_sync`. Se usa para leer las skins compradas y equipadas, guardar las skins equipadas en el juego y armar el enlace `/skins` (`PROTECTED`) |
| `l4d2_web_secret` | `""` | Clave secreta del sitio L4D2 (el `SecretKey` del sitio), compartida con `l4d2_gameinfo_sync`. Se envía en la cabecera `Authorization` para guardar las skins equipadas en el juego (`PROTECTED`) |
| `weapon_skins_kick_no_downloads` | `0` | Expulsa a los jugadores cuyo juego no descarga los archivos del servidor. El mensaje de expulsión indica qué ajuste está mal y el comando de consola que lo corrige |
| `weapon_skins_pile_radius` | `120.0` | Radio, en unidades del juego, usado para encontrar armas principales soltadas cerca unas de otras |
| `weapon_skins_pile_max` | `3` | Número máximo de armas principales soltadas que se conservan dentro de ese radio; las más antiguas se quitan (`0` = desactivado) |
| `weapon_skins_preview_all` | `0` | Modo de prueba. En el siguiente mapa todas las skins de `weapon_skins.cfg` se añaden a la tabla de descargas, compradas o no, y los admins root pueden usar cualquier skin (`!skin <id>`, `!skin next`, `!skin prev`), ignorando compras, equipo y ready-up. Todo jugador que se conecta mientras está activado descarga todas las skins; desactívalo y cambia el mapa para volver a descargar solo las skins compradas |

**Comandos**

| Comando | Acceso | Descripción |
|---------|--------|-------------|
| `sm_skin` / `sm_skins` | todos | Sin argumentos, muestra la ayuda y el enlace de la tienda de skins |
| `sm_skin <id>` | todos | Selecciona una de las skins del jugador por su id (p. ej. `hellsing-gold`) |
| `sm_skin next [weapon]` / `sm_skin prev [weapon]` | todos | Recorre las skins que el jugador tiene para esa arma, pasando por la skin predeterminada |
| `sm_skin default [weapon]` | todos | Vuelve a la skin predeterminada |
| `sm_skin status` | todos | Muestra si las skins están activadas y, en el juego, las estrellas y el número de skins del jugador |
| `sm_skin on` / `sm_skin off` | `ADMFLAG_ROOT` | Activa o desactiva las skins para todos. Tiene prioridad sobre `weapon_skins_enabled` y se mantiene en los cambios de mapa |
| `sm_skin test <id\|default> [weapon]` | `ADMFLAG_ROOT` | Prueba en ti mismo, hasta que cambie el mapa, cualquier skin que ya esté en las descargas de este mapa, sin comprarla y fuera del ready-up |

`sm_skins` acepta los mismos argumentos que `sm_skin`. El acceso root se comprueba mediante el override `sm_weaponskins_admin`, así que se puede cambiar en `admin_overrides.cfg`. `[weapon]` acepta `smg`/`uzi`, `mac`/`mac10`/`mac-10`/`silenced`, `mp5`, `pump`, `chrome`, `magnum`/`deagle`, `axe`/`fireaxe`, `bat`, `cricket`, `guitar`, `pan`, `golf`, los nombres de script de las armas cuerpo a cuerpo (`katana`, `machete`, `crowbar`…) y las claves completas (`weapon_smg_mp5`, `weapon_melee_katana`…). Sin él, se usa el arma que el jugador tiene en la mano, luego el arma principal y luego el arma secundaria (cuerpo a cuerpo o Magnum).

**Cómo configurar** — `l4d2_web_url` se define en `cfg/server.cfg`, para que el plugin sepa qué skins se pueden descargar antes de que se cargue cualquier config de partida, y el secreto **`l4d2_web_secret` en `cfg/server_secrets.cfg`** (ignorado por git); ambas se comparten con `l4d2_gameinfo_sync`. Define `weapon_skins_enabled`, `weapon_skins_kick_no_downloads`, `weapon_skins_pile_radius` y `weapon_skins_pile_max` en `shared_cvars.cfg`. Las armas y skins se definen en [`configs/weapon_skins.cfg`](../../addons/sourcemod/configs/weapon_skins.cfg): la sección `Weapons` tiene los modelos combinados y predeterminados de cada arma, y la sección `Skins` asocia cada id de skin con su arma, el índice de la familia de skin (`skin`) y la carpeta de materiales. El índice `skin` debe coincidir con la familia de skin dentro de los modelos combinados, así que los modelos deben rehacerse cuando se añaden o quitan skins. Los modelos y materiales están en el repositorio [`l4d2-zone-server-assets`](https://github.com/altair-sossai/l4d2-zone-server-assets), cuyo pipeline los publica en el servidor y en el blob de FastDL. Los títulos, rarezas, precios e imágenes de las skins, las compras, los regalos y los reembolsos se gestionan en el sitio (consulta la [wiki](../weapon-skins/README.es.md)). Los textos que ven los jugadores están en [`addons/sourcemod/translations/l4d2_weapon_skins.phrases.txt`](../../addons/sourcemod/translations/l4d2_weapon_skins.phrases.txt) (inglés, portugués y español).

---

# Plugins adaptados (de terceros)

## l4d2_mix (adaptado)

> **No es obra original.** Este plugin fue creado por **Luckylock (LuckyServ)** — repositorio original: <https://github.com/LuckyServ/>. La copia de este repositorio fue **modificada con correcciones y ajustes para este servidor** (integración con la cola, mensajes traducidos/localizados y ajustes de comportamiento). Todo el mérito del plugin original es de su autor.

**Fuente (versión de este servidor):** [`scripting/l4d2_mix.sp`](../../addons/sourcemod/scripting/l4d2_mix.sp) · **Versión:** 5.0.0

**Qué hace** — Organiza un "mix": los jugadores votan para empezar, todos pasan a espectador, los capitanes se eligen por votación y los capitanes eligen sus equipos mediante menús en el juego. Mensajes que ven los jugadores (con el prefijo *"Mix Manager:"*):

- Un mix solo se puede iniciar durante el ready-up de un juego nuevo (marcador 0–0), con los dos equipos llenos (*"Both teams must be full to start a mix."*).
- Cualquiera que esté en un equipo puede usar `!mix` para votar por el inicio. El progreso se muestra a medida que llegan los votos (*"{player} has voted to start a mix. (votes needed: {n})"*), y el mix empieza cuando se alcanzan los votos suficientes (*"Started by vote."*) o cuando un admin lo inicia (*"Started by admin {name}."*). Después de cada mix completado, el siguiente en el mismo ready-up necesita `l4d2_mix_additional_players_after_mix` votos más.
- `!mix <captain1> <captain2>` propone dos capitanes (jugadores de los equipos, por su nombre o el comienzo del nombre) e inicia una votación de sí/no entre los jugadores de los equipos (*"{player} proposed {a} and {b} as captains."*); se aprueba con más de la mitad de ellos votando Sí (*"Captains approved!"*). Un admin que lo usa inicia el mix con esos capitanes al momento.
- Protecciones contra estados inválidos: *"Mix has already started."*, *"A mix cannot be started during a live round."*, *"You cannot start a mix as a spectator."*, *"Mix is not available in 1v1 matches."*
- Durante la elección, los jugadores no pueden unirse solos a un equipo: *"You cannot join a team without being picked."*
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
