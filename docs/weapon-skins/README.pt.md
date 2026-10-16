# Skins de armas e loja de skins — Wiki

🌐 [English](README.md) | **Português**

Esta wiki explica, de ponta a ponta, como funcionam as skins de armas do servidor **l4d2.com.br**: como os arquivos das skins são montados e entregues, como o servidor de jogo aplica as skins, como os jogadores ganham **estrelas** (MVPs) e gastam na **loja de skins**, e como os admins gerenciam tudo. Ela foi escrita para quem quer estudar, manter ou estender o sistema.

## Páginas

| # | Página | O que cobre |
|---|---|---|
| 1 | [Visão geral e arquitetura](01-overview.pt.md) | Os cinco repositórios, como eles se comunicam e o caminho de uma compra |
| 2 | [Assets das skins](02-assets.pt.md) | Skins só de textura, modelos combinados com uma skin family por skin, o repositório de assets, FastDL e como adicionar uma skin nova |
| 3 | [Plugin do servidor de jogo](03-game-plugin.pt.md) | `l4d2_weapon_skins.sp`: tabela de downloads, aplicação das skins nos modelos de visão e de mundo, comandos, cache e sincronização com o site |
| 4 | [Estrelas (PlayStats API)](04-stars-api.pt.md) | Como os MVPs de todo o histórico viram estrelas, como são calculadas e guardadas em cache |
| 5 | [Loja de skins (PlayStats web)](05-skin-shop.pt.md) | Catálogo, raridades e preços, modelo de dados no Table Storage, a transação de compra, segurança e telas de admin |
| 6 | [Operação e procedimentos](06-operations.pt.md) | Configuração e segredos, deploys, reinício do servidor, tarefas comuns, solução de problemas e testes |

## O sistema em um parágrafo

Cada arma com skin (SMG, MAC-10, MP5, escopeta pump, escopeta cromada e nove armas brancas) tem **um modelo combinado** que contém todas as skins daquela arma, cada uma como uma *skin family* separada. Os jogadores ganham **1 estrela por MVP** (dano em SI ou comuns) em partidas competitivas, contando todo o histórico do ranking. Eles compram skins em **l4d2.com.br/skins**; a compra é gravada no Azure Table Storage e a skin já fica equipada. O plugin do servidor lê quais skins foram compradas e quem tem o quê, coloca **só as skins compradas** na tabela de downloads do FastDL no início do mapa e troca o modelo da arma e o `m_nSkin`, para que o dono (e todo mundo em volta) veja a skin. Uma skin comprada no meio de um mapa aparece a partir da **próxima troca de mapa**.

## Repositórios

| Repositório | Papel |
|---|---|
| [l4d2-zone-server](https://github.com/altair-sossai/l4d2-zone-server) | Plugins do SourceMod (incluindo `l4d2_weapon_skins` e `l4d2_gameinfo_sync`), configs, docs e esta wiki |
| [l4d2-zone-server-assets](https://github.com/altair-sossai/l4d2-zone-server-assets) | Modelos e materiais das skins, publicados no servidor de jogo e no blob do FastDL |
| l4d2-playstats-api | API em Azure Functions que guarda as estatísticas das partidas, monta o ranking e fornece as **estrelas** |
| l4d2-playstats-web | O site **l4d2.com.br**: loja de skins, telas de admin e a API usada pelo plugin |
| l4d2-anti-cheat-client | O cliente do anti-cheat, que mantém um manifesto dos assets do servidor |

> Segredos (tokens, chaves, senhas) nunca aparecem nesta wiki. Quando um segredo é necessário, a página diz **onde** ele é configurado, nunca o valor.
