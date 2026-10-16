# Documentación — l4d2-zone-server

🌐 [English](README.md) | [Português](README.pt.md) | **Español**

Documentación escrita para este servidor. Nada de esta carpeta se envía al servidor de juego.

Cada documento existe en tres idiomas y sigue la misma regla de nombre: `nombre.md` es el inglés (la versión que GitHub abre por defecto), `nombre.pt.md` es el portugués y `nombre.es.md` es el español. Cada uno empieza con enlaces a los otros dos.

## Jugadores

| Documento | Idiomas |
|---|---|
| Guía de comandos para jugadores | [English](players/README.md) · [Português](players/README.pt.md) · [Español](players/README.es.md) |
| Cómo corregir el problema de "UDP connect retry" | [English](tutorials/connect-fix/README.md) · [Português](tutorials/connect-fix/README.pt.md) · [Español](tutorials/connect-fix/README.es.md) |
| Changelog del servidor — 04/08/2026 | [English](changelog/2026-08-04.md) · [Português](changelog/2026-08-04.pt.md) · [Español](changelog/2026-08-04.es.md) |

## Administradores

| Documento | Idiomas |
|---|---|
| Guía de comandos para administradores | [English](admins/README.md) · [Português](admins/README.pt.md) · [Español](admins/README.es.md) |

## Plugins y sistemas

| Documento | Idiomas |
|---|---|
| Plugins personalizados (objetivo, ConVars, comandos, configuración) | [English](plugins/README.md) · [Português](plugins/README.pt.md) · [Español](plugins/README.es.md) |
| Wiki de las skins de armas y de la tienda de skins | [English](weapon-skins/README.md) · [Português](weapon-skins/README.pt.md) · [Español](weapon-skins/README.es.md) |

## Mantenimiento

| Documento | Idiomas |
|---|---|
| Cómo compilar los plugins personalizados | [English](maintenance/compile-custom-plugins.md) · [Português](maintenance/compile-custom-plugins.pt.md) · [Español](maintenance/compile-custom-plugins.es.md) |
| Configuración del servidor con Ansible | [English](maintenance/ansible.md) · [Português](maintenance/ansible.pt.md) · [Español](maintenance/ansible.es.md) |

## Estructura

```
docs/
├── admins/           Guía de comandos para administradores
├── changelog/        Changelogs del servidor
├── maintenance/      Compilar los plugins y configurar el servidor
├── players/          Guía de comandos para jugadores
├── plugins/          Referencia de los plugins personalizados
├── tutorials/        Guías paso a paso para jugadores
└── weapon-skins/     Wiki de las skins de armas y de la tienda de skins
```
