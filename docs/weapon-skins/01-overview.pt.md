# 1. Visão geral e arquitetura

🌐 [English](01-overview.md) | **Português** | [Español](01-overview.es.md) · [Início da wiki](README.pt.md)

## Componentes

```mermaid
flowchart LR
    subgraph Game["Servidor de jogo (srcds + SourceMod)"]
        P["l4d2_weapon_skins.smx"]
        G["l4d2_gameinfo_sync.smx"]
        S["l4d2_playstats + l4d2_playstats_sync"]
    end
    subgraph Azure
        API["PlayStats API<br/>(Azure Functions)"]
        TS[("Azure Storage<br/>Tabelas + Blobs")]
        FDL[("Blob do FastDL<br/>fastdl/")]
    end
    WEB["l4d2.com.br<br/>(ASP.NET Core MVC)"]
    C["Jogo do jogador"]

    S -- "arquivos de estatísticas" --> API
    API -- "tabela Statistics" --> TS
    WEB -- "GET /api/stars" --> API
    WEB -- "tabelas SkinShop / SkinPrices" --> TS
    P -- "GET /api/skins, /api/players/skins" --> WEB
    P -- "POST equipar (segredo)" --> WEB
    G -- "game info (segredo)" --> WEB
    C -- "baixa os arquivos das skins" --> FDL
    C -- "joga em" --> Game
```

| Peça | Onde roda | Responsabilidade |
|---|---|---|
| `l4d2_playstats` / `l4d2_playstats_sync` | Servidor de jogo | Gravar um arquivo de estatísticas por mapa e enviar para a API |
| PlayStats API | Azure Functions | Guardar as estatísticas, montar partidas e o ranking, calcular as **estrelas** |
| l4d2.com.br | Servidor Linux (Kestrel numa sessão `screen`) | Catálogo de skins, loja, estornos da temporada, telas de admin, API usada pelo plugin |
| `l4d2_weapon_skins` | Servidor de jogo | Baixar só as skins compradas, aplicar no jogo, sincronizar as skins equipadas |
| `l4d2_gameinfo_sync` | Servidor de jogo | Enviar as informações do jogo e o chat ao vivo para o site |
| Repositório de assets | Pipeline → servidor de jogo + blob do FastDL | Modelos e materiais das skins |

## Estrelas, compras e skins equipadas

- **Estrelas** = MVPs de todo o histórico de um jogador (MVPs de dano em SI + MVPs de comuns) em partidas **competitivas**. São **dados derivados**: calculados pela API a partir das estatísticas guardadas, nunca editados à mão. Veja [Estrelas](04-stars-api.pt.md).
- **Estrelas gastas, compras e skins equipadas** ficam na tabela `SkinShop` do site. O saldo mostrado ao jogador é sempre `estrelas − gastas`. Veja [Loja de skins](05-skin-shop.pt.md).
- **Preços** vêm do catálogo (`skins.json`) e podem ser alterados pelos admins na tabela `SkinPrices`.
- **Temporadas** — uma skin comprada vale até o próximo reset do ranking (00:00 UTC do dia 1º de jan, mar, mai, jul, set e nov). No reset, toda compra que não é presente é estornada automaticamente: as estrelas gastas voltam e a skin sai da conta. Os presentes ficam para sempre. Veja [Loja de skins → Equipar, presentear, estornar](05-skin-shop.pt.md#equipar-presentear-estornar).

## O caminho de uma compra

```mermaid
sequenceDiagram
    actor Player as Jogador
    participant Web as l4d2.com.br
    participant API as PlayStats API
    participant TS as Table Storage
    participant Plugin as Plugin do jogo
    participant Game as Jogo do jogador

    Player->>Web: POST /api/shop/skins/{id}/buy (cookie + antiforgery)
    Web->>API: GET /api/stars/{server}/{player}
    API-->>Web: estrelas
    Web->>TS: transação: adiciona a compra + atualiza a carteira (ETag) + equipa
    Web-->>Player: "Compra concluída! Aparece a partir da próxima troca de mapa"
    Plugin->>Web: GET /api/players/skins (início/fim de round, a cada 2 min)
    Plugin-->>Game: chat "Compra recebida …"
    Note over Plugin: início do próximo mapa
    Plugin->>Plugin: coloca as skins compradas na tabela de downloads
    Game->>Game: baixa as texturas da skin do FastDL
    Plugin->>Game: troca o modelo + m_nSkin → skin visível
```

1. O jogador compra a skin no site. O backend lê as estrelas na API, confere o saldo e grava a compra, o novo total gasto e a skin equipada **numa única transação atômica**.
2. O plugin atualiza as compras no início do round, no fim do round e a cada 2 minutos. Quando vê uma compra nova de um jogador conectado, avisa o jogador no chat.
3. No início do próximo mapa o plugin coloca os materiais de todas as skins compradas na tabela de downloads. Todos os jogadores conectados baixam esses arquivos durante o carregamento do mapa.
4. Quando o dono segura a arma, o plugin troca a arma para o modelo combinado e define a skin family.
5. No próximo reset do ranking o site estorna a compra automaticamente (a não ser que seja um presente) e o plugin deixa de ver a skin como comprada na próxima atualização.

## Por que "próxima troca de mapa"?

O Source monta a lista de arquivos que os clientes precisam baixar (a *tabela de downloads*) uma vez por mapa, antes de os jogadores carregarem o mapa. Um arquivo adicionado no meio do mapa não é enviado para ninguém até o próximo mapa. Por isso:

- os **modelos** das 15 armas estão sempre na tabela de downloads (baixar modelos durante uma troca de mapa mostra `ERROR` até o jogo ser reiniciado);
- só os **materiais** (texturas) de uma skin são adicionados quando alguém compra — texturas baixam sem problema numa troca de mapa.

## Decisões principais (e por quê)

| Decisão | Motivo |
|---|---|
| Skins da workshop só de textura | Sem geometria própria: toda skin reaproveita o layout do modelo original, então um único modelo combinado comporta todas |
| Um modelo combinado por arma, uma skin family por skin | Os jogadores baixam o modelo uma vez; uma skin nova só adiciona texturas |
| Só as skins compradas são baixadas | Downloads menores; o conjunto cresce junto com a loja |
| Estrelas são derivadas, nunca guardadas como contador | Não ficam dessincronizadas; admins não conseguem alterá-las |
| Compras valem uma temporada do ranking, presentes para sempre | A loja acompanha o reset do ranking: as estrelas voltam a cada temporada para os jogadores escolherem de novo |
| Compra = uma transação no Table Storage com ETag | Sem compra duplicada, sem compra sem débito, sem gastar além do saldo com acessos simultâneos |
| O front end envia só o id da skin | O backend nunca confia em preço ou saldo vindos do cliente |
| Catálogo no `skins.json`, preços alteráveis numa tabela | Skins precisam de arquivos e de deploy de qualquer forma; preços podem ser ajustados sem deploy |
