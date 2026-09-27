# Guía de Comandos para Jugadores

🌐 [English](README.md) | [Português](README.pt.md) | **Español**

Todo lo que puedes escribir en el chat del servidor, separado por lo que quieres hacer.

---

## Cómo usar los comandos

| Forma | Ejemplo | Nota |
|---|---|---|
| Chat con `!` | `!ready` | Todos ven el comando en el chat |
| Chat con `/` | `/ready` | Es **silencioso**, solo tú ves la respuesta |
| Consola (`~`) | `sm_ready` | Cambia el `!` por `sm_` |

**Qué significan `< >` y `[ ]`**

En esta guía, `< >` y `[ ]` solo indican qué debes escribir ahí. **No escribas los símbolos**, reemplaza todo por el valor:

| En la guía | Significa | Tú escribes |
|---|---|---|
| `!mix <capitán1> <capitán2>` | `< >` = obligatorio | `!mix vorkyss Feeh` |
| `!roll [número]` | `[ ]` = opcional, puedes dejarlo sin nada | `!roll` o `!roll 20` |

❌ Incorrecto: `!mix <vorkyss> <Feeh>`

✅ Correcto: `!mix vorkyss Feeh`

---

## Ready-up (antes de que empiece la ronda)

| Comando | Qué hace |
|---|---|
| `!ready` / `!r` | Te marca como listo. La ronda empieza cuando todos están listos |
| `!unready` / `!nr` | Quita tu estado de listo |
| `!toggleready` | Alterna entre listo y no listo |
| `!hide` / `!show` | Oculta o muestra el panel del ready-up (útil para ver otros menús) |
| `!return` | Te devuelve al saferoom si te quedas atascado durante el ready-up |

## Pausa

| Comando | Qué hace |
|---|---|
| `!pause` | Pausa el juego |
| `!unpause` / `!ready` | Marca a tu equipo como listo para continuar. El juego sigue cuando los dos equipos están listos |
| `!unready` / `!nr` | Marca a tu equipo como no listo para continuar |

> Si un jugador se cae o se desconecta con la ronda en juego, el juego puede pausarse solo. Cuando vuelva, usa `!unpause` / `!ready` para continuar.

---

## Equipos y cola

| Comando | Qué hace |
|---|---|
| `!spec` / `!s` | Te pasa a espectadores |
| `!fila` / `!queue` | Muestra la cola de espera en orden |
| `!vaga` / `!slot` | Toma un lugar en el juego si es tu turno en la cola |
| `!mix` | Vota para empezar un mix. Cuando hay votos suficientes, todos votan por los capitanes, y los capitanes eligen los equipos con un menú |
| `!mix <capitán1> <capitán2>` | Inicia una votación proponiendo dos capitanes: `capitán1` en survivors y `capitán2` en infected. Si la mayoría vota **sí**, el mix empieza con ellos |
| `!teamflip` / `!tf` | Sortea un equipo (Survivor o Infected) para ti y lo muestra a todos |
| `!kickspecs` | Inicia una votación para expulsar a los espectadores |

Ejemplos:

```
!mix                           -> vota para empezar un mix
!mix vorkyss Feeh              -> propone a vorkyss y Feeh como capitanes
!mix "(LoD) Adeilson" Feeh     -> usa comillas cuando el nombre tiene espacios o símbolos
```

> **Sobre el mix:** los dos equipos deben estar completos y el mix solo empieza al inicio de una partida nueva (0 x 0). Los capitanes deben estar jugando (no en espectadores). No hay mix en 1v1. Si alguien sale durante el mix, el mix se cancela; quien lo haga por segunda vez es **baneado por 30 minutos**.

> **Sobre la cola:** solo puedes tomar un lugar al inicio de una partida nueva y cuando no hay un mix en curso. Cuando se libera un lugar, el servidor avisa al siguiente de la cola para que escriba `!slot`.

> **Tank vivo:** los survivors no pueden pasar a espectadores mientras el Tank está vivo. Si de verdad necesitas cambiar, usa `!pause`.

---

## Votaciones

| Comando | Qué hace |
|---|---|
| `!match` / `!match <config>` | Inicia una votación para cargar una config. Sin la config, abre un menú para elegirla. Ej.: `!match zonemod` |
| `!chmatch <config>` | Inicia una votación para cambiar a otra config |
| `!rmatch` | Inicia una votación para desactivar la config actual |
| `!votecamp` / `!votecampaign` | Abre un menú para votar el cambio de campaña (oficiales y personalizadas) |
| `!voteboss <tank> <witch>` | Vota para cambiar el porcentaje de aparición del Tank y la Witch (solo en ready-up). `0` = no aparece, `-1` = mantiene el actual |
| `!setscores <survivors> <infected>` | Inicia una votación para cambiar el marcador (solo jugadores en un equipo) |
| `!slots <número>` | Inicia una votación para cambiar la cantidad de lugares del servidor. Ej.: `!slots 10` |

Configs disponibles: `zonemod` (4v4), `zm3v3`, `zm2v2`, `zm1v1`, `zonehunters`, `zoneretro`.

---

## Información de la partida

| Comando | Qué hace |
|---|---|
| `!boss` / `!tank` / `!witch` | Muestra dónde aparecerán el Tank y la Witch (%) y quién será el Tank |
| `!cur` / `!current` | Muestra cuánto han avanzado los survivors en el mapa (%) |
| `!health` / `!bonus` / `!damage` | Muestra el bonus actual de los survivors |
| `!mapinfo` | Muestra los valores de distancia y bonus del mapa |
| `!cfg` / `!changelog` | Muestra qué cambia la config actual |
| `!lerps` | Lista el lerp de todos los jugadores |
| `!rates` | Lista la configuración de red de todos los jugadores |

## Estadísticas y ranking

| Comando | Qué hace |
|---|---|
| `!stats` | Estadísticas de los survivors en la ronda. Escribe `!stats help` para ver todas las opciones |
| `!mvp` | MVP de los survivors en la ronda |
| `!mvpme` | Tus propias estadísticas de MVP |
| `!skill` | Estadísticas de habilidad (skeets, levels, crowns...) |
| `!ff` | Estadísticas de fuego amigo |
| `!acc` | Estadísticas de precisión |
| `!stats_auto <flags>` | Elige qué estadísticas se muestran automáticamente al final de la ronda. `-1` = ninguna, `0` = predeterminado del servidor. Escribe `!stats_auto help` para más detalles |
| `!ranking` | Muestra tu posición en el ranking del servidor |

---

## Espectadores

| Comando | Qué hace |
|---|---|
| `!hear` | Elige a quién escuchas: survivors, infected, solo espectadores o todos. Ej.: `!hear survivors` |
| `!spechud` | Muestra u oculta el HUD de espectador |
| `!tankhud` | Muestra u oculta el HUD del Tank |
| `!cast` | Te registra como caster (solo casters autorizados) |
| `!notcasting` / `!uncast` | Te quita de los casters |

---

## Dentro del juego

### Infected

| Comando | Qué hace |
|---|---|
| `!warp <1-4>` / `!warp <nombre>` | En modo fantasma (ghost), te teletransporta a un survivor |

### Lanzamiento de roca del Tank

| Comando | Tecla | Lanzamiento |
|---|---|---|
| `!overhand` | Reload | Por arriba, con las dos manos |
| `!underhand` | Use | Por abajo |
| `!overonehand` | M2 | Por arriba, con una mano |

### Survivors

| Comando | Qué hace |
|---|---|
| `!secondary` | Activa/desactiva el cambio automático al arma cuerpo a cuerpo cuando recoges una |

---

## Diversión

| Comando | Qué hace |
|---|---|
| `!coinflip` / `!cf` / `!flip` | Lanza una moneda (cara o cruz) |
| `!roll [número]` / `!picknumber [número]` | Tira un dado. Ej.: `!roll 20` |

---

## Reglas del servidor

- **Fuego amigo:** quien siga haciendo daño a su propio equipo es expulsado automáticamente, y el juego se pausa.
- **AFK:** durante el ready-up, quien esté AFK demasiado tiempo pasa a espectadores cuando hay alguien esperando para jugar.
- **Lerp:** si tu lerp está fuera del rango permitido, el servidor te muestra los comandos para corregirlo. Pégalos en tu consola:

```
cl_interp 0; cl_interp_ratio 0; rate 100000; cl_cmdrate 100; cl_updaterate 100
```

¿Necesitas ayuda? Habla con un admin en el servidor.
