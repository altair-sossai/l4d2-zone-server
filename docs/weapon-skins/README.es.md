# Skins de armas y tienda de skins — Wiki

🌐 [English](README.md) | [Português](README.pt.md) | **Español**

Esta wiki explica, de principio a fin, cómo funcionan las skins de armas del servidor **l4d2.com.br**: cómo se construyen y se entregan los archivos de las skins, cómo el servidor de juego las aplica, cómo los jugadores ganan **estrellas** (MVPs) y las gastan en la **tienda de skins**, y cómo los admins lo gestionan todo. Está escrita para quien quiera estudiar, mantener o ampliar el sistema. Forma parte de la [documentación del servidor](../README.es.md).

## Páginas

| # | Página | Qué cubre |
|---|---|---|
| 1 | [Visión general y arquitectura](01-overview.es.md) | Los cinco repositorios, cómo se comunican entre sí y el recorrido de una compra |
| 2 | [Assets de las skins](02-assets.es.md) | Skins solo de textura, modelos combinados con una skin family por skin, el repositorio de assets, FastDL, créditos y cómo agregar una skin nueva |
| 3 | [Plugin del servidor de juego](03-game-plugin.es.md) | `l4d2_weapon_skins.sp`: tabla de descargas, aplicación de las skins en los modelos de vista y de mundo, jugadores sin descargas, comandos, caché y sincronización con el sitio |
| 4 | [Estrellas (PlayStats API)](04-stars-api.es.md) | Cómo los MVPs de todo el historial se convierten en estrellas, cómo se calculan y se guardan en caché |
| 5 | [Tienda de skins (PlayStats web)](05-skin-shop.es.md) | Catálogo, rarezas y precios, diseño en Table Storage, la transacción de compra, temporadas y reembolsos, seguridad, páginas de admin |
| 6 | [Operación y procedimientos](06-operations.es.md) | Configuración y secretos, despliegues y su orden, reinicio del servidor, tareas comunes, solución de problemas y pruebas |

## El sistema en un párrafo

Cada arma con skins (SMG, MAC-10, MP5, escopeta pump, escopeta cromada, Magnum y nueve armas cuerpo a cuerpo) tiene **un modelo combinado** que contiene todas las skins de esa arma, cada una como una *skin family* separada. Los jugadores ganan **1 estrella por MVP** (daño a SI o infectados comunes) en partidas competitivas, contando todo el historial del ranking. Compran skins en **l4d2.com.br/skins**; la compra se guarda en Azure Table Storage y la skin queda equipada al momento. Una skin comprada dura **una temporada del ranking**: en cada reinicio del ranking (cada dos meses) las compras de la temporada que terminó se reembolsan automáticamente y las estrellas vuelven; las skins regaladas por los admins se conservan para siempre. El plugin del servidor lee qué skins se compraron y quién tiene qué, agrega **solo las skins compradas** a la tabla de descargas de FastDL al inicio del mapa y cambia el modelo del arma y el `m_nSkin` para que el dueño (y todos alrededor) vean la skin. Una skin comprada durante un mapa aparece a partir del **próximo cambio de mapa**.

## Repositorios

| Repositorio | Función |
|---|---|
| [l4d2-zone-server](https://github.com/altair-sossai/l4d2-zone-server) | Plugins de SourceMod (incluidos `l4d2_weapon_skins` y `l4d2_gameinfo_sync`), configs, docs y esta wiki |
| [l4d2-zone-server-assets](https://github.com/altair-sossai/l4d2-zone-server-assets) | Modelos y materiales de las skins, desplegados en el servidor de juego y en el blob de FastDL; su README da el crédito al autor de cada skin |
| l4d2-playstats-api | API en Azure Functions que guarda las estadísticas de las partidas, arma el ranking y sirve las **estrellas** |
| l4d2-playstats-web | El sitio **l4d2.com.br**: tienda de skins, páginas de admin y la API que usa el plugin |
| l4d2-anti-cheat-client | El cliente del anti-cheat, que verifica los archivos de skin enviados por el servidor contra un manifiesto |

> Los secretos (tokens, claves, contraseñas) nunca aparecen en esta wiki. Cuando se necesita un secreto, la página indica **dónde** se configura, nunca su valor.
