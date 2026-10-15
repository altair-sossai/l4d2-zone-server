# 5. Loja de skins (PlayStats web)

🌐 [English](05-skin-shop.md) | **Português** · [Início da wiki](README.pt.md)

**Repositório:** l4d2-playstats-web (ASP.NET Core MVC, Bootstrap 3) · **Módulo principal:** `L4D2PlayStats.Core/Skins`

## Catálogo: `skins.json`

O catálogo é um recurso embutido (`L4D2PlayStats.Core/Skins/Data/skins.json`), versionado junto com o código. Ele é ordenado por raridade e depois por preço, para ficar fácil de ler:

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

### Raridades e preços

Cada skin foi avaliada olhando suas imagens e recebeu uma raridade e um preço individual dentro da faixa da raridade:

| Raridade | Skins | Faixa de preço (estrelas) |
|---|---|---|
| Lendária | 8 | 520–700 |
| Épica | 26 | 300–450 |
| Rara | 51 | 150–240 |
| Incomum | 44 | 70–130 |
| Comum | 42 | 30–60 |

O catálogo inteiro custa cerca de **29.700 estrelas** — mais do que todas as estrelas dos 100 melhores jogadores juntos quando a loja abriu —, então ter todas as skins foi pensado para ser quase impossível.

### Preços alterados

Os admins podem mudar um preço sem deploy. A alteração fica na tabela `SkinPrices` (PartitionKey `SkinPrice`, RowKey = id da skin) e tem prioridade sobre o preço do catálogo:

```csharp
public record Skin
{
    [JsonPropertyName("price")] public int DefaultPrice { get; init; }
    [JsonIgnore] public int? CustomPrice { get; init; }
    [JsonIgnore] public int Price => CustomPrice ?? DefaultPrice;
    ...
}
```

Salvar de novo o preço padrão (ou "Voltar ao padrão") apaga a alteração. As compras guardam o preço realmente pago, então mudar um preço nunca afeta compras anteriores.

## Armazenamento: a tabela `SkinShop`

Uma partição por jogador (`PartitionKey` = SteamID64). Três tipos de linha:

| RowKey | Entidade | Campos |
|---|---|---|
| `Wallet` | `SkinWalletEntity` | `Spent`, `UpdatedAtUtc` (+ ETag) |
| `Owned_<skinId>` | `SkinPurchaseEntity` | `SkinId`, `Weapon`, `Price`, `StarsBefore`, `Gift`, `PlayerName`, `GiftedByCommunityId`, `GiftedByName`, `PurchasedAtUtc` |
| `Equipped_<weapon>` | `SkinEquipmentEntity` | `Weapon`, `SkinId`, `Source` (`shop`, `site`, `game`, `gift`), `UpdatedAtUtc` |

Manter todas as linhas de um jogador numa única partição é o que torna a transação de compra possível: o Azure Table Storage só suporta transações dentro de uma única partição.

O **saldo** é sempre calculado, nunca gravado:

```csharp
public int Balance => Math.Max(0, Stars - Spent);   // Stars vêm da API
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

Testes de integração (rodando contra o Azurite) cobrem tudo isso, incluindo 20 compras em paralelo da mesma skin (exatamente uma dá certo) e compras em paralelo de skins diferentes (nunca gastando mais que o saldo).

### Equipar, presentear, reembolsar

- **Equipar / desequipar** — confere se o jogador tem a skin (ou se a arma existe) e faz upsert/delete da linha `Equipped_<weapon>`.
- **Presente** (admin) — adiciona uma compra com `Price = 0`, `Gift = true`, o id e o nome do admin, e equipa a skin. As estrelas não são alteradas.
- **Reembolso** (admin) — numa transação: apaga a compra, subtrai o preço de `Spent` e remove a linha de equipamento se aquela skin estava equipada. Tenta de novo em caso de conflito de ETag.

## Endpoints

### Usados pelo site (autenticação por cookie + token antiforgery)

| Método | Rota | Quem |
|---|---|---|
| POST | `/api/shop/skins/{skinId}/buy` | jogador logado |
| POST | `/api/shop/skins/{skinId}/equip` | jogador logado |
| POST | `/api/shop/weapons/{weapon}/unequip` | jogador logado |
| POST | `/api/shop/skins/{skinId}/price` `{price}` | admin (1–100.000; `null` volta ao padrão) |
| POST | `/api/shop/gift` `{communityId, skinId}` | admin (qualquer formato de Steam ID ou link do perfil) |
| POST | `/api/shop/refund` `{communityId, skinId}` | admin |
| GET | `/api/admin/players` | admin — jogadores para o seletor de jogadores |

### Usados pelo plugin do jogo

| Método | Rota | Autenticação |
|---|---|---|
| GET | `/api/skins` | nenhuma — skins compradas por pelo menos um jogador: `[{id, weapon}]` |
| GET | `/api/players/skins` | nenhuma — `[{communityId, skins:[…], equipped:[{weapon, skin}]}]` |
| GET | `/api/players/{communityId}/wallet` | nenhuma — `{mvpSiDamage, mvpCommon, stars, spent, balance}` |
| POST | `/api/players/{communityId}/skins/equip` `{weapon, skin}` | `Authorization: <SecretKey>` (`skin` vazio = padrão) |

## Telas

### Loja — `/skins`

- Destaque com os três passos (ganhe estrelas, compre e equipe, troque no jogo), o saldo do jogador (`X estrelas para gastar`, com os MVPs conquistados e as estrelas gastas) e o botão **"Como uso minhas skins no jogo?"**, que abre uma tabela com todos os comandos.
- Abas **Loja** (agrupada por raridade, com cores) e **Minhas skins**; filtros por arma, raridade e "só as que posso comprar".
- Os cards mostram o preço e o estado: *Comprar por N*, *Faltam N estrelas*, *Sua → Equipar*, *Equipada → Voltar ao padrão*.
- Toda ação mostra uma mensagem clara; compras e trocas sempre lembram que a skin **aparece a partir da próxima troca de mapa**.

### Perfil do jogador — `/player/{id}`

Um painel **Skins** lista as skins que o jogador tem, marcando as equipadas.

### Admin (menu "Admin" da navbar, só para `ServerAdmins`)

| Tela | Funcionalidades |
|---|---|
| Banimentos do chat `/chat-bans` | Lista paginada com avatar, Steam ID, motivo, data e admin; modal de detalhes para editar o motivo ou remover; *Adicionar banimento* com quem falou no chat recentemente e o seletor de jogadores |
| Compras de skins `/admin/skins/purchases` | Totais; busca; lista paginada com imagem da skin, avatar e nome do jogador, preço ou *Presente · por admin*, data; modal de detalhes com reembolso (com confirmação); *Dar uma skin* |
| Preços das skins `/admin/skins/prices` | Busca, filtros de raridade e arma; lista paginada marcando os preços alterados; modal para alterar/voltar o preço ou dar aquela skin de presente |

Peças reutilizáveis (`Views/Shared`): `_Pagination` + `PagedListModel<T>`, `_PlayerPickerModal` (busca por nome — incluindo nomes anteriores —, Steam ID; ranking atual e histórico completo), `_SkinPickerModal` (grade como a da loja, com filtros) e `_GiftModal` (usa os dois seletores; pode abrir com uma skin já selecionada — também a partir dos detalhes da skin na loja, para admins).

## Notas de segurança

- Os POSTs da loja e do admin exigem o cookie de login **e** um token antiforgery (header `RequestVerificationToken`).
- Os endpoints de admin usam `[AdminAuthorize]` (o SteamID64 do usuário precisa estar em `ServerAdmins`).
- O endpoint de escrita do plugin usa `[RequiredSecretKey]`, que compara o header `Authorization` com o `SecretKey` do site.
- As consultas às tabelas usam `TableClient.CreateQueryFilter` (parametrizado); os ids nas rotas são validados (`{communityId:long}`, busca no catálogo) antes de serem usados nas chaves.

## Tradução

Todo texto existe em **inglês, português e espanhol**: arquivos `.resx` por view em `Resources/Views/...` (`Skins/Index`, `SkinsAdmin/Purchases`, `SkinsAdmin/Prices`, `ChatBans/Index`, `Shared/_GiftModal`, `Shared/_PlayerPickerModal`, `Shared/_SkinPickerModal`) e chaves compartilhadas em `SharedResource.*.resx`. O plugin do jogo tem seus próprios arquivos de frases nos mesmos três idiomas.
