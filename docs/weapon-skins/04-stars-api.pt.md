# 4. Estrelas (PlayStats API)

🌐 [English](04-stars-api.md) | **Português** | [Español](04-stars-api.es.md) · [Início da wiki](README.pt.md)

**Repositório:** l4d2-playstats-api (Azure Functions, .NET) · **Módulo:** `L4D2PlayStats.Core/Modules/Stars`

## O que é uma estrela

**1 estrela = 1 MVP.** Para cada metade de um mapa (o turno de sobrevivente de cada time), a biblioteca L4D2PlayStats calcula dois MVPs a partir dos sobreviventes do arquivo de estatísticas:

- **MVP de dano em SI** — o sobrevivente que causou mais dano nos infectados especiais;
- **MVP de comuns** — o sobrevivente que matou mais infectados comuns.

Se ninguém causou dano em SI (ou ninguém matou comuns), o primeiro jogador do arquivo fica com o MVP mesmo assim.

As estrelas de um jogador são a soma de todos os seus MVPs, em todo o histórico, usando **as mesmas regras do ranking**:

- só contam partidas **competitivas** (pelo menos 2 mapas, 4x4, uma configuração de ranking);
- os MVPs são creditados aos jogadores da formação do último mapa da partida (um jogador que saiu antes do último mapa não recebe os MVPs daquela partida);
- empates ficam com o primeiro jogador do arquivo.

Essas regras não são novas: elas vêm de como a API já monta as partidas (`Match.Team.UpdateStats`) para o ranking.

## De onde vêm os dados

1. O `l4d2_playstats` grava um arquivo de texto por mapa com as estatísticas das duas metades.
2. O `l4d2_playstats_sync` envia cada arquivo para `POST /api/statistics` (autenticado por servidor).
3. A API guarda cada arquivo na tabela `Statistics` (PartitionKey = id do servidor, RowKey = um timestamp invertido, para as linhas ficarem ordenadas da mais nova para a mais antiga). Nada é apagado.
4. O `MatchService` transforma as linhas em partidas; o `Match.Team.UpdateStats` conta os MVPs de cada jogador.

## Como as estrelas são calculadas

Recalcular todas as partidas desde 2023 a cada requisição seria lento, então o total é dividido em duas partes:

```
estrelas = períodos fechados (todas as partidas antes do período atual do ranking) + período atual
```

```csharp
public async Task<List<PlayerStars>> StarsAsync(string serverId)
{
    var closed = await ClosedStarsAsync(serverId);   // blob, refeito uma vez por período
    var current = await CurrentStarsAsync(serverId); // cache em memória, 1 h, limpo no upload
    ... // soma os dois por jogador, ordenado por estrelas e depois por communityId
}
```

- **Períodos fechados** — calculados uma vez por período do ranking (as temporadas bimestrais do ranking: jan–fev, mar–abr, …) a partir de todas as partidas *antes* do início do período atual, e salvos como `closed_yyyyMM.json` no container de blob privado `{serverId}-stars`. Um timer (`0 30 0 * * *`) garante todo dia que ele exista. Depois de lido, o blob também fica em memória por 12 horas.
- **Período atual** — as partidas do período atual, em cache na memória por 1 hora. O cache é limpo quando um novo arquivo de estatísticas é enviado (na instância que o recebeu).

Contando os MVPs de um conjunto de partidas:

```csharp
public static Dictionary<long, PlayerStars> Stars(this IEnumerable<Match> matches)
{
    var players = new Dictionary<long, PlayerStars>();

    foreach (var match in matches)
    foreach (var team in match.Teams)
    foreach (var matchPlayer in team.Players)
    {
        if (!long.TryParse(matchPlayer.CommunityId, out var communityId))
            continue;
        ...
        player.MvpSiDamage += matchPlayer.MvpSiDamage;
        player.MvpCommon += matchPlayer.MvpCommon;
    }

    return players;
}
```

A consulta dos períodos fechados lê todas as linhas de estatística mais antigas que o início do período (as RowKeys são ticks invertidos, então "mais antigo que X" é `RowKey gt '{long.MaxValue - X.Ticks}'`):

```csharp
public IAsyncEnumerable<Statistics> GetStatisticsBeforeAsync(string serverId, DateTime end)
{
    var filter = $"PartitionKey eq '{serverId}' and RowKey gt '{long.MaxValue - end.Ticks}'";
    return TableClient.QueryAsync<Statistics>(filter);
}
```

## Endpoints

| Método | Rota | Retorna |
|---|---|---|
| GET | `/api/stars/{serverId}` | Todos os jogadores com estrelas: `[{communityId, mvpSiDamage, mvpCommon, stars}]` |
| GET | `/api/stars/{serverId}/{communityId:long}` | Um jogador (zeros se o jogador não tiver nenhuma) |

Os dois são só de leitura e anônimos, como os endpoints do ranking.

## Validação

Quando a funcionalidade foi feita, os totais foram conferidos com o ranking de todo o histórico já guardado: para os 100 jogadores do `ranking_all_time.json`, *MVPs de todo o histórico + MVPs do período atual* bateram exatamente com o endpoint de estrelas (0 diferenças), com 688 jogadores e cerca de 24.750 estrelas no total naquele momento.

## Pontos de atenção

- No uso normal as estrelas só aumentam. Se as estatísticas forem corrigidas algum dia (por exemplo, uma correção de pontuação), as estrelas de um jogador podem cair; a loja então mostra saldo 0 e bloqueia compras, mas uma queda nas estrelas nunca remove as skins que ele já tem. Uma correção só muda as estrelas na hora se for do período atual: o `closed_yyyyMM.json` de um período já fechado é reaproveitado como está, então a correção de um arquivo mais antigo só aparece quando o blob do próximo período for gerado.
- As estrelas são de todo o histórico e **não** zeram com o ranking. O que o reset do ranking faz é estornar as skins compradas na temporada que terminou, para que as estrelas gastas nelas possam ser gastas de novo (veja [Loja de skins → Equipar, presentear, estornar](05-skin-shop.pt.md#equipar-presentear-estornar)).
- Um MVP novo pode levar até 1 hora para aparecer se o app de Functions rodar em mais de uma instância (cada instância tem seu próprio cache).
