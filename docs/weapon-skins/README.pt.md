# Skins de armas

🌐 [English](README.md) | **Português** | [Español](README.es.md)

Esta pasta cobre a parte das skins de armas que pertence ao servidor de jogo e aos assets dele: como os arquivos das skins são montados, os modelos combinados, o FastDL, os créditos e como adicionar uma skin. Ela faz parte da [documentação do servidor](../README.pt.md).

## Páginas

| Página | O que cobre |
|---|---|
| [Assets das skins](02-assets.pt.md) | Skins só de textura, modelos combinados com uma skin family por skin, o repositório de assets, FastDL, créditos, como adicionar uma skin, o manifesto do anti-cheat, a ordem de deploy e o reinício do servidor de jogo |

## Loja, estrelas e plugin

A loja de skins, as estrelas, as compras, os presentes e os estornos, e o plugin `l4d2_weapon_skins` com o `weapon_skins.cfg` fazem parte do [l4d2-playstats-hub](https://github.com/altair-sossai/l4d2-playstats-hub), o projeto que roda o l4d2.com.br:

- [Loja de skins](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/skin-shop.pt.md) — estrelas, a página da loja, compras, equipar, estornos no fim da temporada, presentes e as páginas de administração.
- [Conectando um servidor de jogo](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/game-server.pt.md) — os plugins, as ConVars e os comandos deles.
- [Pasta de plugins](https://github.com/altair-sossai/l4d2-playstats-hub/tree/main/plugins) — fontes, plugins compilados e o `weapon_skins.cfg`.

O pipeline deste repositório copia os plugins e o `weapon_skins.cfg` da última release do hub para o servidor de jogo. Veja [Plugins customizados → Plugins de estatísticas](../plugins/README.pt.md#plugins-de-estatísticas-l4d2-playstats-hub).

## Repositórios

| Repositório | Papel |
|---|---|
| [l4d2-zone-server](https://github.com/altair-sossai/l4d2-zone-server) | Configs do servidor de jogo, incluindo as ConVars `weapon_skins_*` de cada modo e os filtros do stripper |
| [l4d2-zone-server-assets](https://github.com/altair-sossai/l4d2-zone-server-assets) | Modelos e materiais das skins, enviados ao servidor de jogo e ao blob do FastDL; o README dele dá o crédito ao autor de cada skin |
| [l4d2-playstats-hub](https://github.com/altair-sossai/l4d2-playstats-hub) | O site l4d2.com.br com a loja de skins, o catálogo e as miniaturas das skins, e o plugin `l4d2_weapon_skins` |
| l4d2-anti-cheat-client | O cliente do anti-cheat, que confere os arquivos de skin enviados pelo servidor com um manifesto |
