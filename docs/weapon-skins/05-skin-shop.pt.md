# 5. Loja de skins (PlayStats web)

🌐 [English](05-skin-shop.md) | **Português** | [Español](05-skin-shop.es.md) · [Início da wiki](README.pt.md)

**Repositório:** l4d2-playstats-web (ASP.NET Core MVC, Bootstrap 3) · **Módulo principal:** `L4D2PlayStats.Core/Skins`

## Catálogo: `skins.json`

O catálogo é um recurso embutido (`L4D2PlayStats.Core/Skins/Data/skins.json`), versionado junto com o código. O arquivo é um objeto com um array `skins`, ordenado por raridade e depois por preço, para ficar fácil de ler. Uma entrada:

```json
{
  "id": "dark-matter",
  "weapon": "weapon_smg_silenced",
  "rarity": "legendary",
  "price": 700,
  "workshopId": "3377651383",
  "title": { "en": "MAC-10 Dark Matter", "pt": "MAC-10 Dark Matter", "es": "MAC-10 Dark Matter" },
  "description": { "en": "...", "pt": "...", "es": "..." },
  "originalTitle": "MAC-10 DARK MATTER",
  "originalDescription": "..."
}
```

- `id` é o mesmo id usado no `weapon_skins.cfg` e pelo `!skin <id>`.
- A miniatura é `wwwroot/imgs/skins/<id>.jpg`.
- `workshopId` liga a skin à página original na Workshop (o botão *Ver no Workshop*).

### Raridades e preços

Cada skin foi avaliada olhando as imagens e recebeu uma raridade e um preço individual dentro da faixa da raridade:

| Raridade | Skins | Faixa de preço (estrelas) |
|---|---|---|
| Lendária | 9 | 520–700 |
| Épica | 30 | 300–450 |
| Rara | 58 | 150–240 |
| Incomum | 54 | 70–130 |
| Comum | 45 | 30–60 |

As 196 skins do catálogo custam juntas **34.500 estrelas** (preços padrão) — mais que todas as estrelas de todos os jogadores juntos quando a loja abriu — então ter todas as skins numa temporada é para ser quase impossível.

### Preços alterados

Os admins podem mudar um preço sem deploy. A alteração fica na tabela `SkinPrices` (PartitionKey `SkinPrice`, RowKey = id da skin) e vale no lugar do preço do catálogo:

```csharp
public record Skin
{
    [JsonPropertyName("price")] public int DefaultPrice { get; init; }
    [JsonIgnore] public int? CustomPrice { get; init; }
    [JsonIgnore] public int Price => CustomPrice ?? DefaultPrice;
    ...
}
```

Salvar de novo o preço padrão (ou "Restaurar padrão") apaga a alteração. As compras guardam o preço realmente pago, então mudar um preço nunca afeta compras antigas (e um estorno sempre devolve o que foi pago).

## Armazenamento: a tabela `SkinShop`

Uma partição por jogador (`PartitionKey` = SteamID64). Três tipos de linha:

| RowKey | Entidade | Campos |
|---|---|---|
| `Wallet` | `SkinWalletEntity` | `Spent`, `UpdatedAtUtc` (+ ETag) |
| `Owned_<skinId>` | `SkinPurchaseEntity` | `SkinId`, `Weapon`, `Price`, `StarsBefore`, `Gift`, `PlayerName`, `GiftedByCommunityId`, `GiftedByName`, `PurchasedAtUtc` |
| `Equipped_<weapon>` | `SkinEquipmentEntity` | `Weapon`, `SkinId`, `Source` (`shop`, `site`, `game`, `gift`), `UpdatedAtUtc` |

Manter todas as linhas de um jogador numa única partição é o que torna a transação de compra possível: o Azure Table Storage só tem transações dentro de uma mesma partição.

O **saldo** é sempre calculado, nunca guardado:

```csharp
public int Balance => Math.Max(0, Stars - Spent);   // as estrelas vêm da API
```

## A transação de compra

`SkinShopService.BuyAsync(communityId, playerName, skinId)` — o front-end envia só o id da skin; todo o resto é decidido no servidor.

```csharp
var skin = await skinService.FindAsync(skinId);           // catálogo + preço alterado
if (skin == null) return SkinNotFound;
if (await repository.FindPurchaseAsync(communityId, skin.Id) != null) return AlreadyOwned;

var stars = await GetStarsAsync(communityId);              // atualizado, direto da API
if (stars == null) return StarsUnavailable;                // na dúvida, recusa

for (var attempt = 1; attempt <= 3; attempt++)
{
    var wallet = await repository.FindWalletAsync(communityId) ?? new SkinWalletEntity { PartitionKey = communityId };
    var balance = stars.Stars - wallet.Spent;
    if (balance < skin.Price) return InsufficientStars;

    var walletAction = wallet.ETag == default
        ? new TableTransactionAction(TableTransactionActionType.Add, wallet)
        : new TableTransactionAction(TableTransactionActionType.UpdateReplace, wallet, wallet.ETag);

    wallet.Spent += skin.Price;

    var actions = new List<TableTransactionAction>
    {
        new(TableTransactionActionType.Add, purchase),           // falha se já tiver a skin
        walletAction,                                             // falha se a carteira mudou
        new(TableTransactionActionType.UpsertReplace, equipment)  // já equipada
    };

    try { await repository.SubmitAsync(actions); }
    catch (TableTransactionFailedException e) when (e.FailedTransactionActionIndex == 0 && e.Status == 409)
    { return AlreadyOwned; }
    catch (TableTransactionFailedException e) when (e.FailedTransactionActionIndex == 1 && e.Status is 409 or 412)
    { continue; }   // outra requisição mudou a carteira: lê de novo e tenta outra vez

    return Success;
}
return Busy;
```

O que isso garante:

| Risco | Proteção |
|---|---|
| Comprar a mesma skin duas vezes | A linha da compra é um `Add`: uma segunda falha com 409 |
| Compra sem débito (ou débito sem compra) | Compra, carteira e equipamento são gravados em **uma** transação: tudo ou nada |
| Duas compras ao mesmo tempo gastando as mesmas estrelas | A atualização da carteira depende do ETag; a que perde lê de novo e confere o saldo outra vez |
| Preço ou saldo forjado no navegador | A requisição leva só o id da skin; o preço vem do catálogo e as estrelas, da API |
| API fora do ar | As compras são recusadas (`StarsUnavailable`), nunca presumidas |

Durante o desenvolvimento esses casos foram cobertos por testes de integração rodando contra o Azurite, incluindo 20 compras em paralelo da mesma skin (exatamente uma dá certo) e compras em paralelo de skins diferentes (nunca gastando mais que o saldo). O projeto de testes não está versionado no repositório.

### Equipar, presentear, estornar

- **Equipar / desequipar** — confere se o jogador tem a skin (ou se a arma existe) e faz upsert/delete da linha `Equipped_<weapon>`.
- **Presente** (admin) — adiciona uma compra com `Price = 0`, `Gift = true`, o id e o nome do admin, e equipa a skin. As estrelas não são alteradas. Os presentes nunca são estornados pelo estorno da temporada.
- **Estorno** (admin) — numa transação: apaga a compra, subtrai o preço de `Spent` e remove a linha de equipamento se aquela skin estava equipada. Tenta de novo em caso de conflito de ETag.
- **Estorno da temporada** (automático) — as skins são compradas por temporada do ranking (dois meses, em UTC: jan–fev, mar–abr, …; o reset é às 00:00 UTC do dia 1º de jan, mar, mai, jul, set e nov, que é 21:00 do dia anterior em Brasília). O `SkinSeason.Current` dá o início, o fim, o último dia e os dias restantes da temporada. O `SkinSeasonRefundBackgroundService` roda quando o site sobe e a cada 10 minutos e chama `SkinShopService.RefundSeasonAsync(SkinSeason.Current.Start)`: toda compra que **não é presente** e foi feita antes do início da temporada atual é estornada com as mesmas regras do estorno do admin — as estrelas gastas voltam, a skin sai da conta e a linha de equipamento dela é removida. A compra é conferida de novo logo antes de ser apagada, então uma skin comprada de novo na temporada nova nunca é afetada. Os presentes ficam para sempre. A execução é idempotente, então uma execução perdida (site fora do ar no reset) é recuperada na próxima; quando algo é estornado, ela grava no log `Skin purchases made before the season of … refunded` com os totais.
- **Estornar tudo** (ferramenta de admin) — o `RefundAllAsync` estorna todas as compras **e todos os presentes** de todos os jogadores, com as mesmas regras do estorno individual. Assim como o estorno da temporada, ele trabalha jogador por jogador (até 8 jogadores em paralelo, uma compra por vez em cada jogador) e devolve os totais e a quantidade de falhas.

## Endpoints

### Usados pelo site (autenticação por cookie + token antiforgery)

| Método | Rota | Quem |
|---|---|---|
| POST | `/api/shop/skins/{skinId}/buy` | jogador logado |
| POST | `/api/shop/skins/{skinId}/equip` | jogador logado |
| POST | `/api/shop/weapons/{weapon}/unequip` | jogador logado |
| POST | `/api/shop/skins/{skinId}/price` `{price}` | admin (1–100.000; `null` restaura) |
| POST | `/api/shop/gift` `{communityId, skinId}` | admin (qualquer formato de Steam ID ou link do perfil) |
| POST | `/api/shop/refund` `{communityId, skinId}` | admin |
| POST | `/api/shop/refund-all` | admin — estorna todas as compras e presentes: `{purchases, gifts, stars, players, failed}` |
| GET | `/api/admin/players` | admin — jogadores para o seletor de jogadores |

### Usados pelo plugin do jogo

| Método | Rota | Autenticação |
|---|---|---|
| GET | `/api/skins` | nenhuma — skins compradas por pelo menos um jogador: `[{id, weapon}]` |
| GET | `/api/players/skins` | nenhuma — `[{communityId, skins:[…], equipped:[{weapon, skin}]}]` |
| GET | `/api/players/{communityId}/wallet` | nenhuma — `{mvpSiDamage, mvpCommon, stars, spent, balance}` |
| POST | `/api/players/{communityId}/skins/equip` `{weapon, skin}` | `Authorization: <SecretKey>` (`skin` vazio = padrão) |

## Páginas

### Loja — `/skins`

- Destaque com os três passos (ganhe estrelas, compre e equipe, troque no jogo), o saldo do jogador (`X estrelas para gastar`, com os MVPs ganhos e as estrelas gastas) e o botão **"Como uso minhas skins no jogo?"**, que abre uma tabela com todos os comandos.
- Um aviso **"Skins por temporada"**: as skins compradas valem até o reset do ranking, a cada dois meses; ele mostra o último dia da temporada atual e os dias restantes, e diz que no reset toda compra é estornada automaticamente e as estrelas voltam, enquanto os presentes ficam para sempre.
- Uma linha de créditos: todas as skins foram feitas pela comunidade na Steam Workshop; o botão *Ver no Workshop* de cada skin abre o trabalho original.
- Abas **Loja** (agrupada por raridade, com cores) e **Minhas skins**; filtros por arma, raridade e "só as que posso comprar".
- Os cards mostram o preço e o estado: *Comprar por N*, *Faltam N*, *Comprada → Equipar*, *Equipada → Voltar para a padrão*.
- A confirmação da compra mostra a skin e o preço, diz que ela é equipada na arma na hora e aparece a partir da próxima troca de mapa, diz até quando a skin vale (o último dia da temporada; depois ela é estornada automaticamente) e termina com *"A compra não pode ser desfeita antes do reset do ranking."*
- Toda ação mostra uma mensagem clara; compras e trocas sempre lembram que a skin **aparece a partir da próxima troca de mapa**.

### Perfil do jogador — `/player/{id}`

Uma linha **Estrelas** mostra o saldo, as estrelas ganhas e as estrelas gastas, e um painel **Skins** lista as skins do jogador, marcando as equipadas. Quando dois jogadores são comparados (`/player/{id}/{otherId}`), os dois aparecem lado a lado seguindo o padrão da página: o primeiro jogador em branco, o segundo em amarelo.

### Admin (menu "Admin" na barra de navegação, só para `ServerAdmins`)

| Página | Recursos |
|---|---|
| Bans do Chat `/chat-bans` | Lista paginada com avatar, Steam ID, motivo, data e admin; modal de detalhes para editar o motivo ou remover; *Adicionar ban* com quem falou recentemente no chat e o seletor de jogadores |
| Compras de skins `/admin/skins/purchases` | Aviso com o último dia da temporada (quando as compras são estornadas automaticamente; os presentes ficam); totais; busca; lista paginada com imagem da skin, avatar e nome do jogador, preço ou *Presente · por admin*, data; modal de detalhes com *Estornar compra* (com confirmação); *Dar skin de presente*; *Estornar tudo* (ferramenta de admin que estorna todas as compras e presentes, com uma caixa de confirmação) |
| Preços das skins `/admin/skins/prices` | Busca, filtros de raridade e arma; lista paginada marcando os preços alterados; modal para alterar/restaurar o preço ou dar aquela skin de presente |

Peças reutilizáveis (`Views/Shared`): `_Pagination` + `PagedListModel<T>`, `_PlayerPickerModal` (busca por nome — inclusive nomes antigos —, Steam ID; ranking atual e histórico de todos os tempos), `_SkinPickerModal` (grade igual à da loja, com filtros) e `_GiftModal` (usa os dois seletores; pode abrir com uma skin já escolhida — também pelos detalhes da skin na loja, para admins).

## Notas de segurança

- Os POSTs da loja e do admin exigem o cookie de login **e** um token antiforgery (cabeçalho `RequestVerificationToken`).
- Os endpoints de admin usam `[AdminAuthorize]` (o SteamID64 do usuário precisa estar em `ServerAdmins`).
- O endpoint de escrita do plugin usa `[RequiredSecretKey]`, que compara o cabeçalho `Authorization` com o `SecretKey` do site.
- As consultas às tabelas usam `TableClient.CreateQueryFilter` (parametrizado); os ids nas rotas são validados (`{communityId:long}`, busca no catálogo) antes de serem usados em chaves.

## Localização

Todo texto existe em **inglês, português e espanhol**: arquivos `.resx` por view em `Resources/Views/...` (`Skins/Index`, `SkinsAdmin/Purchases`, `SkinsAdmin/Prices`, `ChatBans/Index`, `Shared/_GiftModal`, `Shared/_PlayerPickerModal`, `Shared/_SkinPickerModal`) e chaves compartilhadas em `SharedResource.*.resx`. O plugin do jogo tem seus próprios arquivos de frases nos mesmos três idiomas.
