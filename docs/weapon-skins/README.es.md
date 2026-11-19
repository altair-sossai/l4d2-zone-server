# Skins de armas

🌐 [English](README.md) | [Português](README.pt.md) | **Español**

Esta carpeta cubre la parte de las skins de armas que pertenece al servidor de juego y a sus assets: cómo se construyen los archivos de las skins, los modelos combinados, FastDL, los créditos y cómo agregar una skin. Forma parte de la [documentación del servidor](../README.es.md).

## Páginas

| Página | Qué cubre |
|---|---|
| [Assets de las skins](02-assets.es.md) | Skins solo de textura, modelos combinados con una skin family por skin, el repositorio de assets, FastDL, créditos, cómo agregar una skin, el manifiesto del anti-cheat, el orden de deploy y el reinicio del servidor de juego |

## Tienda, estrellas y plugin

La tienda de skins, las estrellas, las compras, los regalos y los reembolsos, y el plugin `l4d2_weapon_skins` con su `weapon_skins.cfg` son parte de [l4d2-playstats-hub](https://github.com/altair-sossai/l4d2-playstats-hub), el proyecto que hace funcionar l4d2.com.br:

- [Tienda de skins](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/skin-shop.es.md) — estrellas, la página de la tienda, compras, equipar, reembolsos al final de la temporada, regalos y las páginas de administración.
- [Conectar un servidor de juego](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/game-server.es.md) — los plugins, sus ConVars y comandos.
- [Carpeta de plugins](https://github.com/altair-sossai/l4d2-playstats-hub/tree/main/plugins) — fuentes, plugins compilados y `weapon_skins.cfg`.

El pipeline de este repositorio copia los plugins y `weapon_skins.cfg` de la última release del hub al servidor de juego. Consulta [Plugins personalizados → Plugins de estadísticas](../plugins/README.es.md#plugins-de-estadísticas-l4d2-playstats-hub).

## Repositorios

| Repositorio | Función |
|---|---|
| [l4d2-zone-server](https://github.com/altair-sossai/l4d2-zone-server) | Configs del servidor de juego, incluidas las ConVars `weapon_skins_*` de cada modo y los filtros de stripper |
| [l4d2-zone-server-assets](https://github.com/altair-sossai/l4d2-zone-server-assets) | Modelos y materiales de las skins, enviados al servidor de juego y al blob de FastDL; su README da el crédito al autor de cada skin |
| [l4d2-playstats-hub](https://github.com/altair-sossai/l4d2-playstats-hub) | El sitio l4d2.com.br con la tienda de skins, el catálogo y las miniaturas de las skins, y el plugin `l4d2_weapon_skins` |
| l4d2-anti-cheat-client | El cliente del anti-cheat, que verifica los archivos de skin enviados por el servidor contra un manifiesto |
