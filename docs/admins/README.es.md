# Guía de Comandos para Admins

🌐 [English](README.md) | [Português](README.pt.md) | **Español**

Guía rápida de los comandos de admin del servidor. Los primeros comandos son los más usados en el día a día; cuanto más abajo, menos los vas a necesitar.

> Los comandos que cualquier jugador puede usar están en la [Guía de Comandos para Jugadores](../players/README.es.md).

---

## Cómo usar los comandos

| Forma | Ejemplo | Nota |
|---|---|---|
| Chat con `!` | `!swap Miosha` | Todos ven el comando en el chat |
| Chat con `/` | `/swap Miosha` | El comando es **silencioso**, solo tú ves la respuesta |
| Consola (`~`) | `sm_swap Miosha` | Cambia el `!` por `sm_` |

**Qué significan `< >` y `[ ]`**

En esta guía, `< >` y `[ ]` solo indican qué debes escribir ahí. **No escribas los símbolos**, reemplaza todo por el valor:

| En la guía | Significa | Tú escribes |
|---|---|---|
| `!swapto <equipo> <jugador>` | `< >` = obligatorio | `!swapto 2 vorkyss` |
| `!hp [cantidad]` | `[ ]` = opcional, puedes dejarlo sin nada | `!hp` o `!hp 50` |
| `!ban <objetivo> <minutos> [motivo]` | los dos juntos | `!ban #12 60` o `!ban #12 60 flood en el chat` |

❌ Incorrecto: `!swapto <2> <vorkyss>`

✅ Correcto: `!swapto 2 vorkyss`

**Nombres con espacios:** pon el nombre entre comillas `" "`. Sin comillas, el juego entiende cada palabra como una parte separada del comando.

❌ Incorrecto: `!swapto 2 (LoD) Adeilson`

✅ Correcto: `!swapto 2 "(LoD) Adeilson"`

**Cómo elegir el objetivo (`<objetivo>`)**

- **Parte del nombre:** `!swap mio` funciona si solo un jugador tiene "mio" en el nombre.
- **`#userid`:** es la forma más segura cuando el nombre tiene caracteres raros o se parece al de otro (abajo ves cómo encontrar el número).
- **Grupos:** `@all` (todos), `@humans` (solo humanos), `@bots` (solo bots), `@me` (tú mismo), `@aim` (a quien estás apuntando).

**Cómo encontrar el `#userid`**

Abre la consola (`~`) y escribe `status`. Vas a ver algo así (se omiten las últimas columnas):

```
] status
hostname: L4D2 Zone
map     : c2m1_highway at: 0 x, 0 y, 0 z
players : 4 humans, 0 bots (8 max)

# userid name uniqueid connected ping loss state
#  12 "vorkyss" STEAM_1:0:11111111 25:14 45 0 active
#  15 "Feeh" STEAM_1:1:22222222 18:02 38 0 active
#  21 "♏" STEAM_1:0:33333333 07:45 60 0 active
#  23 "Finn ™" STEAM_1:1:44444444 02:10 52 0 active
```

El **primer número** de cada línea es el `userid`. En el ejemplo, el nombre `♏` es difícil de escribir, así que basta con usar su número:

```
!swap #21
!swapto 1 #21
```

Funciona en cualquier comando que pida `<objetivo>` (kick, ban, mute, swap, etc.).

> El `userid` cambia cada vez que el jugador se reconecta. Si sale y vuelve, ejecuta `status` de nuevo.

> 💡 Si tienes dudas, abre el menú con **`!admin`**. Casi todo lo que está aquí (kick, ban, mute, cambiar de mapa, cambiar de equipo) también se puede hacer desde él, sin escribir nada.

---

## Menú de admin

| Comando | Qué hace |
|---|---|
| `!admin` | Abre el menú de admin (jugadores, votaciones, mapas, comandos del servidor) |

## Config de la partida (ZoneMod)

| Comando | Qué hace |
|---|---|
| `!forcematch <config> [mapa]` / `!fm <config> [mapa]` | Carga la config competitiva. Si pasas un mapa, la config se carga directamente en él. **Usa `!fm zonemod` siempre que el servidor esté sin config** |
| `!resetmatch` | Desactiva la config actual y devuelve el servidor al modo por defecto |
| `!forcechangematch <config> [mapa]` / `!fchmatch <config> [mapa]` | Cambia a otra config sin tener que desactivar la actual |

Ejemplos:

```
!fm zonemod               -> carga ZoneMod en el mapa actual
!fm zonemod c2m1_highway  -> carga ZoneMod directamente en Dark Carnival
!fchmatch zm3v3           -> cambia a ZoneMod 3v3
```

Configs más usadas: `zonemod` (4v4), `zm3v3`, `zm2v2`, `zm1v1`, `zonehunters`, `zoneretro`.

## Ready-up y pausa

| Comando | Qué hace |
|---|---|
| `!forcestart` / `!fs` | Empieza la ronda sin esperar a que todos den `!ready`. Con el juego en pausa, también lo despausa |
| `!forcepause` | Pausa el juego. **Solo un admin puede despausar** una pausa hecha así |
| `!forceunpause` | Despausa sin esperar a que los equipos den ready (empieza la cuenta regresiva para que el juego vuelva) |

> Usa `!forcepause` cuando necesites resolver algo (cambio de jugador, alguien trabado, una discusión). Los jugadores no pueden despausar hasta que uses `!forceunpause`.

## Equipos

| Comando | Qué hace |
|---|---|
| `!swap <jugador1> [jugador2] ...` | Manda a los jugadores de la lista al equipo contrario |
| `!swapto <equipo> <jugador1> [jugador2] ...` | Manda a los jugadores a un equipo específico: `1` = spectator, `2` = survivors, `3` = infected |
| `!swapto force <equipo> <jugador1> [jugador2] ...` | Igual que el anterior, pero fuerza el cambio aunque el equipo esté lleno |
| `!swapteams` | Invierte los dos equipos completos (survivors ↔ infected) |
| `!fixbots` | Ajusta la cantidad de bots survivor al tamaño del equipo de la config (p. ej., 4 en 4v4), creando los que falten |

Ejemplos:

```
!swapto 1 Zenk            -> manda a Zenk a spectator
!swapto 2 Guigo Vegueta   -> manda a los dos a survivors
!swap #12                 -> manda al jugador #12 al equipo contrario
```

## Mix

| Comando | Qué hace |
|---|---|
| `!mix` | Empieza el mix **al instante**, sin votación. Los dos capitanes se eligen por votación de los jugadores |
| `!mix <capitán1>` | Empieza el mix al instante con `capitán1` como capitán de los survivors. El segundo capitán se elige por votación |
| `!mix <capitán1> <capitán2>` | Empieza el mix al instante con los dos capitanes definidos: `capitán1` en survivors y `capitán2` en infected |
| `!stopmix` | Cancela el mix en curso (por ejemplo, si un capitán salió o trabó la elección) |

Ejemplos:

```
!mix                            -> empieza el mix y los jugadores votan a los capitanes
!mix vorkyss                    -> vorkyss es capitán, el otro sale por votación
!mix vorkyss Feeh               -> vorkyss y Feeh son los capitanes
!mix "(LoD) Adeilson" Feeh      -> usa comillas cuando el nombre tenga espacios o símbolos
```

> - Los capitanes tienen que estar **jugando** (en survivors o infected), no en spectator.
> - Puedes usar el nombre completo o solo el comienzo del nombre.
> - Los dos equipos tienen que estar **llenos**, y el mix solo puede empezar al **inicio de un juego nuevo** (marcador 0 x 0), antes de que empiece la primera ronda.
> - No hay mix en 1v1.
> - Si alguien sale del servidor durante el mix, el mix se cancela. La primera vez la persona solo recibe un aviso; si vuelve a salir, queda **baneada por 60 minutos**.

## Moderación: kick, ban y mute

| Comando | Qué hace |
|---|---|
| `!kick <objetivo> [motivo]` | Expulsa al jugador del servidor |
| `!ban <objetivo> <minutos> [motivo]` | Banea a un jugador que **está en el servidor**. `0` = permanente |
| `!addban <minutos> <SteamID> [motivo]` | Banea a un jugador que **ya salió** del servidor, usando su SteamID |
| `!unban <SteamID>` | Quita el ban |
| `!mute <objetivo>` / `!unmute <objetivo>` | Bloquea o libera la **voz** del jugador |
| `!gag <objetivo>` / `!ungag <objetivo>` | Bloquea o libera el **chat de texto** del jugador |
| `!silence <objetivo>` / `!unsilence <objetivo>` | Bloquea o libera **voz y chat** al mismo tiempo |

Ejemplos:

```
!ban #12 60 insultando en el chat
!ban #7 0 trampa
!addban 1440 STEAM_1:0:12345678 salió antes del ban
!unban STEAM_1:0:12345678
```

> ⚠️ Mute, gag y silence duran **hasta que el jugador sale del servidor**. Si el problema sigue, usa kick o ban.
>
> ⚠️ En los motivos de ban, escribe **solo el motivo**. Nunca pongas la IP ni datos personales del jugador.

## Mapa

| Comando | Qué hace |
|---|---|
| `!map <mapa>` | Cambia el mapa al instante. Ej.: `!map c2m1_highway` |

---

## Tank y Witch

| Comando | Qué hace |
|---|---|
| `!givetank <jugador>` | Define quién va a ser el próximo Tank. El jugador tiene que estar en el equipo **infected** |
| `!tankshuffle` | Vuelve a sortear quién va a ser el Tank |
| `!ftank <porcentaje>` | Fuerza el porcentaje de spawn del Tank. **Solo funciona durante el ready-up** y no funciona en mapas donde el Tank tiene spawn fijo |
| `!fwitch <porcentaje>` | Fuerza el porcentaje de spawn de la Witch. **Solo funciona durante el ready-up** y no funciona en mapas donde la Witch tiene spawn fijo |

> Los jugadores también pueden pedirlo por votación con `!voteboss <tank> <witch>`. `!ftank`/`!fwitch` se salta la votación.

## Marcador y campaña

| Comando | Qué hace |
|---|---|
| `!setscores <survivors> <infected>` | Cambia el marcador **al instante**, sin votación (cuando lo usa un jugador, se abre una votación). **Solo funciona durante el ready-up**, antes de que empiece la ronda. `<survivors>` es el marcador del equipo que está de survivor ahora |
| `!setnextcampaign` | Abre un menú para elegir la(s) próxima(s) campaña(s) de la rotación, o limpiar la lista |

> Útil cuando el servidor se cayó en medio de la partida y necesitan volver con el marcador correcto.

## Ayudas durante la partida

| Comando | Qué hace |
|---|---|
| `!hp [cantidad]` | Suma la cantidad (de 1 a 100, por defecto: 100) a la vida de todos los survivors vivos, sin pasar de 100, y levanta a quien esté incapacitado |

## Espectadores y casters

| Comando | Qué hace |
|---|---|
| `!caster <jugador>` | Registra al jugador como caster (narrador) |
| `!notcasting <jugador>` | Saca al jugador de la lista de casters |
| `!resetcasters` | Limpia todos los casters registrados |
| `!kickspecs` | Expulsa a los espectadores **al instante**, sin votación (los casters y los admins no son expulsados) |
| `!broadcast` | Activa/desactiva el modo "hablar con todos": mientras está activo, **todos escuchan tu voz**, incluidos los dos equipos |

> Usa `!broadcast` para dar un aviso rápido por voz a los dos equipos. Acuérdate de desactivarlo después.

## Moderación general

| Comando | Qué hace |
|---|---|
| `!slay <objetivo>` | Mata al jugador |
| `!rename <objetivo> <nuevo nombre>` | Cambia el nombre del jugador |
| `!who` | Muestra los jugadores conectados y quién es admin |
| `!votekick <objetivo>` | Abre una votación para expulsar al jugador |
| `!voteban <objetivo>` | Abre una votación para banear al jugador |
| `!votemap <mapa>` | Abre una votación para cambiar de mapa |

## Mensajes de admin

| Comando | Qué hace |
|---|---|
| `!say <mensaje>` | Mensaje para todos en el chat, destacado como mensaje de admin |
| `!csay <mensaje>` | Mensaje en el **centro de la pantalla** de todos |
| `!hsay <mensaje>` | Mensaje en la caja de pistas (hint) de todos |
| `!psay <objetivo> <mensaje>` | Mensaje privado para un jugador |
| `!chat <mensaje>` | Mensaje que **solo los admins** ven |

> Atajo: en el chat del equipo (`say_team`), empieza el mensaje con `@` para hablar solo con los admins. Ej.: `@¿alguien puede ayudar aquí?`

## Servidor

| Comando | Qué hace |
|---|---|
| `!slots <número>` | Cambia la cantidad de plazas del servidor **al instante**, sin votación (máximo 30). Ej.: `!slots 10` |
| `!killlobbyres` | Quita la reserva de lobby del servidor (deja entrar a quien no vino por el lobby) |

## Skins de armas

| Comando | Qué hace |
|---|---|
| `!skin on` / `!skin off` | Activa o desactiva las skins para todos. **Sigue valiendo después del cambio de mapa**, hasta que otro admin lo cambie o el servidor se reinicie |
| `!skin test <id>` | Prueba la skin en ti hasta que cambie el mapa, sin comprarla, sin ser survivor y sin estar en el ready-up. Solo funciona con skins que ya están en la lista de descargas del mapa |
| `!skin test default [arma]` | Quita la skin de prueba |

`[arma]`: `smg`, `mac`, `mp5`, `pump`, `chrome`, `magnum` (o `deagle`), `axe`, `katana`, `machete`, `bat`, `cricket`, `guitar`, `crowbar`, `golf` o `pan`. Sin ella, se usa el arma que tienes en la mano. `!skin test <id>` no la necesita: la skin ya define el arma.

Ejemplos:

```
!skin off                     -> desactiva las skins para todos
!skin test hellsing-gold      -> prueba la skin hellsing-gold
!skin test default smg        -> quita la skin de prueba de la SMG
```

> Los comandos de skins de los jugadores (`!skin`, `!skin <id>`, `!skin next`, `!skin prev`, `!skin default`, `!skin status`) están en la [Guía de Comandos para Jugadores](../players/README.es.md#skins-de-armas). `!skin on/off` y `!skin test` solo funcionan para admins con acceso **root**.

### Tienda de skins (sitio)

Los jugadores compran las skins en [l4d2.com.br/skins](https://l4d2.com.br/skins) con estrellas (1 estrella por MVP de daño a SI o de comunes en partidas competitivas, desde el inicio del ranking). Solo los archivos de las skins que al menos un jugador compró entran en la lista de descargas, a partir del cambio de mapa siguiente a la compra.

Las compras valen hasta el final de la temporada del ranking: en cada reinicio del ranking (cada 2 meses) se **reembolsan automáticamente** y las estrellas vuelven a los jugadores. Las skins dadas como regalo se quedan.

Los admins del sitio tienen el menú **Admin** arriba en [l4d2.com.br](https://l4d2.com.br):

| Qué hacer | Cómo |
|---|---|
| Cambiar el precio de una skin | **Admin → Precios de skins**: haz clic en la skin, cambia el valor y haz clic en **Guardar**. Solo vale para las próximas compras; a quien ya la compró no le afecta. **Restaurar predeterminado** vuelve al precio del catálogo |
| Regalar una skin | **Admin → Compras de skins → Regalar skin** (o **Regalar** en la skin, en Precios de skins): elige el jugador y la skin. La skin queda equipada para el jugador y no gasta estrellas |
| Reembolsar una compra | **Admin → Compras de skins**: haz clic en la compra, luego en **Reembolsar compra** y **Confirmar reembolso**. Las estrellas pagadas vuelven al jugador, la skin sale de su cuenta y, si estaba equipada, el arma vuelve a la predeterminada |
| Reembolsar todo | **Admin → Compras de skins → Reembolsar todo**: marca la confirmación y haz clic en **Reembolsar todo**. Reembolsa todas las compras y todos los regalos de todos los jugadores, y no se puede deshacer. Si algún elemento falla, ejecútalo de nuevo |
| Banear a un jugador del chat del sitio | **Admin → Baneos del Chat → Agregar baneo**: el jugador ya no puede enviar mensajes al servidor por el chat del sitio |

> Las estrellas siempre vienen del ranking: el admin no cambia el saldo de nadie, solo regala skins o reembolsa compras. Más detalles en [Operación de las skins → Tareas comunes](../weapon-skins/06-operations.es.md#tareas-comunes).

### Modo de prueba: todas las skins

Para revisar en el juego skins que nadie compró todavía:

1. `!cvar weapon_skins_preview_all 1`
2. Cambia de mapa, con `!fm zonemod` o `!map <mapa>`. Los archivos de todas las skins entran en la lista de descargas cuando carga el mapa.
3. Sal y vuelve a entrar al servidor para descargar los archivos. Si aparece ERROR, cierra y abre el juego.
4. Toma el arma y usa `!skin next` / `!skin prev` para pasar por todas sus skins, o `!skin <id>`. Para los admins root, la compra, el equipo y el ready-up se ignoran.
5. Al terminar: `!cvar weapon_skins_preview_all 0` y cambia de mapa. Vuelve a descargarse solo lo que se compró.

> ⚠️ Mientras el modo de prueba está activo, **todo jugador que entre descarga todas las skins** (unos 300 MB). Úsalo con el servidor vacío y desactívalo justo después.

---

## Comandos avanzados

| Comando | Qué hace |
|---|---|
| `!cvar <cvar> [valor]` | Muestra o cambia una cvar del servidor |
| `!rcon <comando>` | Ejecuta un comando directamente en la consola del servidor |
| `!execcfg <archivo>` | Ejecuta un archivo `.cfg` de la carpeta `cfg/` del servidor |
| `!reloadadmins` | Recarga la lista de admins (después de agregar a alguien) |
| `!listcampaigns` | Lista en la consola todas las campañas instaladas |
| `!refreshcampaigns` | Actualiza la lista de campañas de `!votecamp` |
| `!add_caster_id <SteamID>` | Agrega la SteamID a la lista de quienes pueden registrarse solos como caster (`!cast`) |
| `!remove_caster_id <SteamID>` | Quita la SteamID de esa lista |
| `!printcasters` | Muestra la lista de SteamIDs de casters |
| `statsreset` | **Solo por consola.** Reinicia las estadísticas de la partida actual (`!stats`, `!mvp`) |

> ⚠️ Cuidado con `!cvar`, `!rcon` y `!execcfg`: pueden romper la config de la partida. Si algo queda raro, `!resetmatch` y después `!forcematch zonemod` lo resuelve.

---

## Pruebas y debug (no usar en partida)

Estos comandos existen, pero sirven para **pruebas, debug o diversión**. Usarlos en una partida en serio arruina el juego.

### Comandos de diversión y pruebas

| Comando | Qué hace |
|---|---|
| `!cchelp` | Lista todos los comandos de prueba disponibles |
| `!godmode <objetivo>` | Hace al jugador inmortal |
| `!teleport <objetivo>` | Teletransporta al jugador a donde estás apuntando |
| `!revive <objetivo>` | Levanta a un survivor incapacitado |
| `!sethpplayer <objetivo> <vida>` | Define la vida del jugador |
| `!speedplayer <objetivo> <velocidad>` | Cambia la velocidad del jugador |
| `!panic` | Fuerza un evento de horda |
| `!slap`, `!burn`, `!freeze`, `!beacon`, `!noclip`, `!timebomb` | Comandos de diversión: bofetada, fuego, congelar, señalizar, atravesar paredes, bomba |

### Mantenimiento y debug

| Comando | Qué hace |
|---|---|
| `!crash` | **Tumba el servidor** para que se reinicie. Todos se desconectan. Úsalo solo si el servidor está roto y nadie está jugando |
| `!early_victory_debug` | Muestra los valores internos de la victoria anticipada |
| `!tank_witch_debug_info` | Muestra información interna del spawn del Tank y de la Witch |

---

## Situaciones comunes

**Servidor sin config / juego en modo por defecto**
1. `!forcematch zonemod`

**Un jugador se cayó en medio de la ronda**
1. `!forcepause`
2. Espera a que vuelva, o trae a alguien de la cola con `!swapto <equipo> <jugador>`
3. `!forceunpause`

**Equipos desbalanceados o jugador en el equipo equivocado**
1. `!swapto 1 <jugador>` para mandarlo a spectator
2. `!swapto 2 <jugador>` o `!swapto 3 <jugador>` para ponerlo en el equipo correcto
3. Si falta un survivor, `!fixbots`

**Mix trabado (un capitán salió o no elige)**
1. `!stopmix`
2. Empieza otro con `!mix`, o define ya los capitanes con `!mix <capitán1> <capitán2>`

**El servidor se cayó y la partida volvió sin marcador**
1. `!forcematch zonemod <mapa>` para volver al mapa en el que estaban
2. Todavía en el ready-up, `!setscores <survivors> <infected>` con el marcador de antes. Como admin, el marcador cambia al instante

**Jugador tóxico**
1. `!gag` / `!mute` / `!silence` para pararlo al instante
2. Si sigue: `!kick <objetivo> <motivo>`
3. Si es grave o reincidente: `!ban <objetivo> <minutos> <motivo>`
