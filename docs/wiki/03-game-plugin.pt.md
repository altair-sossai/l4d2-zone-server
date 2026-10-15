# 3. Plugin do servidor de jogo — `l4d2_weapon_skins`

🌐 [English](03-game-plugin.md) | **Português** · [Início da wiki](README.pt.md)

**Código:** `addons/sourcemod/scripting/l4d2_weapon_skins.sp` · **Config:** `addons/sourcemod/configs/weapon_skins.cfg` · **Traduções:** `addons/sourcemod/translations/{,pt/,es/}l4d2_weapon_skins.phrases.txt`

O plugin carrega a partir de `plugins/` (carga automática), não de `optional/`. Assim ele já está rodando no lobby e os arquivos das skins já estão na tabela de downloads quando os jogadores conectam pela primeira vez.

## Dados que ele mantém em memória

| Variável | Conteúdo |
|---|---|
| `g_hSkins` / `g_hSkinsByName` | Skins do `weapon_skins.cfg` (structs `WeaponSkin`) e um mapa id → índice |
| `g_hWeaponModels` | Modelos combinados/originais de cada arma e seus índices de precache |
| `g_hPurchasedSkins` | Ids de skins compradas por pelo menos um jogador (de `/api/skins`) |
| `g_hOwnedSkins` | Chaves `"<steamid64>:<skin>"` de toda skin que alguém tem (de `/api/players/skins`) |
| `g_hPlayerChoices` | Skin equipada por `"<steamid64>:<arma>"` |
| `g_hLocalChanges` | Quando o jogador trocou de skin no jogo pela última vez (protege trocas recentes, veja abaixo) |
| `g_hTestChoices` | Skins de teste do admin (`!skin test`), limpas no início do mapa |

## Início do mapa: montando a tabela de downloads

No `OnMapStart` o plugin lê o `weapon_skins.cfg`:

1. **A pasta do modelo combinado de cada arma** entra na tabela de downloads e é feito o precache, tenha ou não alguém com skin daquela arma.
2. **Cada skin** só é preparada se alguém a comprou (ou se o modo de teste estiver ligado):

```sourcepawn
bool PrepareSkin(WeaponSkin skin)
{
	...
	if (!models.ready || (!g_hPreviewAll.BoolValue && !g_hPurchasedSkins.ContainsKey(skin.name)))
	{
		return false;
	}
	...
	AddDirectoryToDownloadsTable(skin.materials);
	...
	return true;
}
```

`skin.ready` diz ao resto do código se os arquivos daquela skin estão na tabela de downloads **deste** mapa. Uma skin comprada durante o mapa é do jogador, mas só fica pronta no mapa seguinte.

### Hibernação e os arquivos de cache

Um servidor de L4D2 vazio hiberna: as respostas HTTP assíncronas só são processadas depois que o primeiro jogador conecta — tarde demais para os downloads desse jogador. Por isso o plugin salva em disco as últimas respostas válidas da API e as lê quando não tem nada em memória:

- `addons/sourcemod/data/weapon_skins_cache.json` — skins compradas (`/api/skins`);
- `addons/sourcemod/data/weapon_skins_players_cache.json` — skins de cada jogador e equipadas (`/api/players/skins`).

## Comunicação com o site

Duas cvars, compartilhadas com o `l4d2_gameinfo_sync`, configuram o site: `l4d2_web_url` (definida no `cfg/server.cfg`) e `l4d2_web_secret` (definida no `cfg/server_secrets.cfg`, que é ignorado pelo git).

| Chamada | Quando | Para quê |
|---|---|---|
| `GET {url}/api/skins` | configs executadas, início e fim de round, a cada 2 min com jogadores | Quais skins precisam ser baixadas |
| `GET {url}/api/players/skins` | idem | Quem tem o quê e o que está equipado |
| `GET {url}/api/players/{id}/wallet` | `!skin status` | Estrelas e saldo |
| `POST {url}/api/players/{id}/skins/equip` com `Authorization: <l4d2_web_secret>` | o jogador troca de skin no jogo | Salvar a skin equipada no site |

```sourcepawn
void RefreshShop()
{
	...
	FormatEx(endpoint, sizeof(endpoint), "%s/api/skins", apiUrl);
	HTTPRequest skinsRequest = new HTTPRequest(endpoint);
	skinsRequest.Get(OnPurchasedSkinsResponse);

	FormatEx(endpoint, sizeof(endpoint), "%s/api/players/skins", apiUrl);
	HTTPRequest playersRequest = new HTTPRequest(endpoint);
	playersRequest.Get(OnPlayerSkinsResponse, GetEngineTime());
}
```

Respostas com campos faltando são rejeitadas e os últimos dados válidos são mantidos.

### Não perder uma troca feita no jogo

O jogador pode trocar de skin no jogo enquanto uma atualização está em andamento; o site poderia responder com o valor antigo. Cada troca no jogo registra o `GetEngineTime()`; cada atualização registra quando foi pedida. Até 15 s depois da troca (`LOCAL_CHANGE_GRACE`), a escolha local vale:

```sourcepawn
if (requestedAt > changedAt + LOCAL_CHANGE_GRACE)
{
	g_hLocalChanges.Remove(key);   // o site já tem a troca
	continue;
}
// mantém o valor local em vez da resposta do site
```

### Aviso de compra nova

Quando uma atualização traz uma skin que os dados anteriores não tinham, o dono (se estiver conectado) recebe no chat: *"Compra recebida: X (arma). Ela já está equipada e aparece a partir da próxima troca de mapa."* Se outro jogador já tinha comprado aquela skin (os arquivos já estão neste mapa), o plugin aplica na hora e avisa isso.

## Aplicando uma skin

Uma skin é aplicada trocando o modelo pelo **modelo combinado** da arma e definindo `m_nSkin` com a family da skin (simplificado):

```sourcepawn
void ApplyWorldModel(int weapon, WeaponSkin skin)
{
	if (!g_bWorldModelsEnabled) return;

	if (GetEntProp(weapon, Prop_Send, "m_nModelIndex") == skin.defaultWorldModelIndex)
		SetEntityModel(weapon, skin.worldModel);

	if (HasEntProp(weapon, Prop_Send, "m_iWorldModelIndex") && GetEntProp(weapon, Prop_Send, "m_iWorldModelIndex") != skin.worldModelIndex)
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", skin.worldModelIndex);

	if (GetEntProp(weapon, Prop_Send, "m_nSkin") != skin.family)
		SetEntProp(weapon, Prop_Send, "m_nSkin", skin.family);
}
```

- **Modelo de mundo** (o que os outros veem, e a arma no chão): aplicado ao equipar, ao pegar e 0,1 s depois de soltar (o motor reseta o modelo quando a arma é solta).
- **Modelo de visão** (primeira pessoa): a entidade `m_hViewModel` do jogador recebe o modelo de visão combinado e a family no `OnPostThinkPost`, a cada frame, só enquanto a arma ativa tem skin.
- **Restauração**: quando uma arma perde a skin, o modelo original e o `m_nSkin` original da arma são devolvidos.

### Qual skin uma arma recebe?

Cada entidade de arma guarda a skin que recebeu quando foi rastreada pela primeira vez (`g_iWeaponSkin[weapon]`). **A skin acompanha a arma**: se o dono soltar, quem pegar usa com a skin do dono. A skin da arma de um jogador é escolhida assim:

```sourcepawn
int GetPlayerWeaponSkin(int client, int weapon)
{
	... // chave = "<steamid64>:<chave da arma>"
	if (g_hTestChoices.GetString(key, name, sizeof(name)))
		return FindReadySkin(name);                       // teste do admin

	if (!g_hPlayerChoices.GetString(key, name, sizeof(name)))
		return -1;                                        // nada equipado

	if (!HasPreviewAccess(client) && !SteamIdOwnsSkin(steamId, name))
		return -1;                                        // não é mais dele

	return FindReadySkin(name);                           // -1 se não está nos downloads deste mapa
}
```

As armas brancas compartilham a classe `weapon_melee`, então a chave da arma é montada a partir do nome do script: `weapon_melee_<m_strMapSetScriptName>` (por exemplo `weapon_melee_fireaxe`).

## Jogadores sem downloads

Um jogador com `cl_allowdownload 0` (ou `cl_downloadfilter` diferente de `all`/`nosounds`) veria um modelo `ERROR`. O plugin consulta as duas cvars assim que o jogador começa a conectar:

- `weapon_skins_kick_no_downloads 1` → o jogador é expulso com uma mensagem explicando como ligar os downloads;
- `0` → o jogador fica e os **modelos de mundo voltam ao original para todos** enquanto ele estiver no servidor (os modelos de visão continuam aparecendo para quem consegue ver, exceto para quem estiver espectando esse jogador em primeira pessoa).

## Limpeza de pilhas de armas

Trocar de arma várias vezes nos spawns infinitos da saferoom pode empilhar armas no chão e causar lag. Quando uma arma primária é solta, o plugin conta as armas primárias soltas dentro de `weapon_skins_pile_radius` e remove as mais antigas acima de `weapon_skins_pile_max`. Spawns, armas colocadas pelo mapa, armas secundárias e armas na mão nunca são removidas.

## Comandos

| Comando | Quem | O que faz |
|---|---|---|
| `!skin` / `!skins` | todos | Ajuda e link da loja |
| `!skin <id>` | todos | Usa uma das suas skins (só no ready-up, como sobrevivente) |
| `!skin next` / `!skin prev` `[arma]` | todos | Passa pelas suas skins da arma; depois da última, volta para a padrão |
| `!skin default [arma]` | todos | Volta para a skin padrão |
| `!skin status` | todos | Skins ligadas/desligadas, suas estrelas e quantas skins você tem |
| `!skin on` / `!skin off` | root | Liga/desliga as skins para todos (vale depois da troca de mapa) |
| `!skin test <id\|default> [arma]` | root | Testa uma skin em você até o mapa trocar |

`[arma]` aceita `smg`, `mac`, `mp5`, `pump`, `chrome`, `axe`, `katana`, `machete`, `bat`, `cricket`, `guitar`, `crowbar`, `golf`, `pan` e as chaves completas.

## Cvars

| Cvar | Padrão | Para quê |
|---|---|---|
| `weapon_skins_enabled` | `0` | Liga/desliga geral (definida como `1` no `shared_cvars.cfg`) |
| `l4d2_web_url` | `""` | URL do site, compartilhada com o `l4d2_gameinfo_sync` |
| `l4d2_web_secret` | `""` | Segredo do site, compartilhado com o `l4d2_gameinfo_sync` |
| `weapon_skins_kick_no_downloads` | `0` | Expulsa jogadores sem downloads |
| `weapon_skins_pile_radius` / `weapon_skins_pile_max` | `120` / `3` | Limpeza de pilhas de armas |
| `weapon_skins_preview_all` | `0` | Modo de teste: todas as skins baixadas e utilizáveis por admins root |
