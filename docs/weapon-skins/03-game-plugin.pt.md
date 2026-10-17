# 3. Plugin do servidor de jogo — `l4d2_weapon_skins`

🌐 [English](03-game-plugin.md) | **Português** | [Español](03-game-plugin.es.md) · [Início da wiki](README.pt.md)

**Código:** [`addons/sourcemod/scripting/l4d2_weapon_skins.sp`](../../addons/sourcemod/scripting/l4d2_weapon_skins.sp) (v3.2.0) · **Config:** [`addons/sourcemod/configs/weapon_skins.cfg`](../../addons/sourcemod/configs/weapon_skins.cfg) · **Traduções:** `addons/sourcemod/translations/{,pt/,es/}l4d2_weapon_skins.phrases.txt`

O plugin é carregado de `plugins/` (carga automática), não de `optional/`, então ele já está rodando no lobby e os arquivos das skins já estão na tabela de downloads quando os jogadores conectam pela primeira vez.

## Dados que ele guarda em memória

| Variável | Conteúdo |
|---|---|
| `g_hSkins` / `g_hSkinsByName` | Skins do `weapon_skins.cfg` (structs `WeaponSkin`) e um mapa id → índice |
| `g_hWeaponModels` | Modelos combinados/originais por arma e seus índices de precache |
| `g_hPurchasedSkins` | Ids das skins compradas por pelo menos um jogador (de `/api/skins`) |
| `g_hOwnedSkins` | Chaves `"<steamid64>:<skin>"` de todas as skins compradas (de `/api/players/skins`) |
| `g_hPlayerChoices` | Skin equipada por `"<steamid64>:<weapon>"` |
| `g_hLocalChanges` | Quando um jogador trocou a skin no jogo pela última vez (protege trocas recentes, veja abaixo) |
| `g_hTestChoices` | Escolhas do `!skin test` dos admins, limpas no início do mapa |

## Início do mapa: montando a tabela de downloads

No `OnMapStart` o plugin lê o `weapon_skins.cfg`:

1. **A pasta do modelo combinado de cada arma** entra na tabela de downloads e recebe precache, tenha alguém comprado skin ou não.
2. **Cada skin** só é preparada se alguém a comprou (ou se o modo de teste está ligado):

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

O `skin.ready` diz ao resto do código se os arquivos daquela skin estão na tabela de downloads **deste** mapa. Uma skin comprada durante o mapa já é do jogador, mas só fica pronta no próximo mapa.

### Hibernação e os arquivos de cache

Um servidor de L4D2 vazio hiberna: os callbacks de HTTP assíncrono só são processados depois que o primeiro jogador conecta — tarde demais para os downloads desse jogador. Por isso o plugin salva em disco as últimas respostas válidas da API e lê esses arquivos quando não tem nada em memória:

- `addons/sourcemod/data/weapon_skins_cache.json` — skins compradas (`/api/skins`);
- `addons/sourcemod/data/weapon_skins_players_cache.json` — skins de cada jogador e equipadas (`/api/players/skins`).

## Conversando com o site

Duas cvars, compartilhadas com o `l4d2_gameinfo_sync`, configuram o site: `l4d2_web_url` (definida em `cfg/server.cfg`) e `l4d2_web_secret` (definida em `cfg/server_secrets.cfg`, que é ignorado pelo git).

| Chamada | Quando | Para quê |
|---|---|---|
| `GET {url}/api/skins` | configs executadas, início do round, fim do round, a cada 2 min com jogadores | Quais skins precisam ser baixadas |
| `GET {url}/api/players/skins` | igual | Quem tem o quê e o que está equipado |
| `GET {url}/api/players/{id}/wallet` | `!skin status` | Estrelas e saldo |
| `POST {url}/api/players/{id}/skins/equip` com `Authorization: <l4d2_web_secret>` | um jogador troca a skin no jogo | Salvar a skin equipada no site |

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

Um jogador pode trocar a skin no jogo enquanto uma atualização está em andamento; o site poderia responder com o valor antigo. Cada troca no jogo grava o `GetEngineTime()`; cada atualização grava quando foi pedida. Até 15 s depois da troca (`LOCAL_CHANGE_GRACE`), a escolha local vale:

```sourcepawn
if (requestedAt > changedAt + LOCAL_CHANGE_GRACE)
{
	g_hLocalChanges.Remove(key);   // o site já tem a troca
	continue;
}
// mantém o valor local em vez da resposta do site
```

### Aviso de compra nova

Quando uma atualização mostra uma skin que os dados anteriores não tinham, o dono (se estiver conectado) recebe uma mensagem no chat: *"Compra recebida: X (arma). Ela já está equipada e aparece a partir da próxima troca de mapa."* Se outro jogador já tinha comprado essa skin (os arquivos dela estão neste mapa), o plugin aplica na hora e avisa isso.

### Estornos

Quando uma compra é estornada (por um admin ou no fim da temporada do ranking), a próxima atualização não lista mais aquela skin para o jogador: as armas registradas a partir daí usam a skin padrão, e a partir do próximo mapa os arquivos da skin só são baixados se outra pessoa ainda tiver a skin. Uma arma que já está com a skin continua com ela até sair do jogo.

## Aplicando uma skin

Uma skin é aplicada trocando o modelo pelo **modelo combinado** da arma e definindo o `m_nSkin` com a family da skin (simplificado):

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

- **Modelo de mundo** (o que os outros veem, e a arma no chão): aplicado ao equipar, ao pegar a arma e 0,1 s depois de largar (o engine reseta o modelo quando a arma é largada). Quando um jogador pega uma arma de um spawn (`weapon_*_spawn`), a arma no slot da arma do spawn (pistolas e armas brancas: secundário; o resto: primário) volta ao modelo de mundo original antes do uso e recebe a skin de novo logo depois.
- **Modelo de visão** (primeira pessoa): a entidade `m_hViewModel` do jogador recebe o modelo de visão combinado e a family no `OnPostThinkPost`, a cada frame, só enquanto a arma ativa tem skin.
- **Sem pisca em primeira pessoa**: o cliente prevê as animações da arma e, sempre que uma recomeça, desenha por um instante o modelo de visão original até chegar a atualização do servidor; com ping, o jogador vê a arma original piscar por cima da skin. A animação de idle recomeça mais ou menos uma vez por segundo, então, enquanto a arma ativa de um jogador humano mostra uma skin, o plugin mantém o `m_flTimeWeaponIdle` da arma pelo menos 5 s no futuro (`HoldWeaponIdle`). A animação de idle nunca recomeça e esse pisca some; a sequência de idle continua em loop sozinha. Ainda pode aparecer um pisca curto no começo do tiro, porque essa animação também é prevista.
- **Restaurando**: quando uma arma perde a skin, o modelo original e o `m_nSkin` original da arma voltam.

### Qual skin uma arma recebe?

Cada entidade de arma lembra a skin que recebeu quando foi registrada pela primeira vez (`g_iWeaponSkin[weapon]`). **A skin acompanha a arma**: se o dono larga a arma, quem pegar usa a arma com a skin do dono. A skin da arma de um jogador é escolhida assim:

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

Um jogador com `cl_allowdownload 0` (ou com `cl_downloadfilter` diferente de `all`/`nosounds`) veria um modelo `ERROR`. O plugin consulta as duas cvars assim que o jogador começa a conectar (`OnClientConnected`):

- `weapon_skins_kick_no_downloads 1` (o valor definido no `shared_cvars.cfg`) → com as skins ligadas, o jogador é expulso. A mensagem da expulsão diz qual cvar está com o valor errado e o comando de console que resolve (`cl_allowdownload 1` ou `cl_downloadfilter all`), e pede para o jogador conferir essa cvar no `autoexec.cfg` ou no `config.cfg` se continuar acontecendo. Cada expulsão é gravada no log do SourceMod com `LogMessage` (nome e SteamID do jogador, nunca o IP):

  ```text
  [l4d2_weapon_skins.smx] Kicked Player<12><STEAM_1:0:12345><> because cl_allowdownload is "0"
  ```

- `0` → o jogador fica e **os modelos de mundo voltam ao original para todo mundo** enquanto ele estiver no servidor (os modelos de visão continuam aparecendo para quem consegue ver, menos para quem estiver assistindo esse jogador em primeira pessoa).

> A opção do menu do jogo *Opções > Multijogador > Conteúdo personalizado do servidor > Permitir tudo* só altera o `cl_downloadfilter`. O `cl_allowdownload` não tem opção no menu: só pode ser alterado no console ou num arquivo de config. Por isso um jogador que escolheu "Permitir tudo" no menu ainda pode ser expulso, e por isso a mensagem traz o comando de console exato.

## Limpeza de pilhas de armas

Trocar de arma várias vezes nos spawns infinitos do safe room pode acumular armas largadas e causar lag no servidor. Quando uma arma primária é largada, o plugin conta as armas primárias largadas dentro de `weapon_skins_pile_radius` e remove as mais antigas acima de `weapon_skins_pile_max`. Spawns, armas colocadas pelo mapa, armas secundárias e armas na mão nunca são removidas.

## Comandos

| Comando | Quem | O que faz |
|---|---|---|
| `!skin` / `!skins` | todos | Ajuda e o link da loja |
| `!skin <id>` | todos | Usa uma das suas skins (só durante o ready-up, como sobrevivente) |
| `!skin next` / `!skin prev` `[arma]` | todos | Passa pelas suas skins da arma; depois da última, volta para a padrão |
| `!skin default [arma]` | todos | Volta para a skin padrão |
| `!skin status` | todos | Skins ligadas/desligadas, suas estrelas e quantas skins você tem |
| `!skin on` / `!skin off` | root | Liga/desliga as skins para todos (continua valendo após trocar de mapa) |
| `!skin test <id\|default> [arma]` | root | Testa uma skin em você até o mapa trocar |

`[arma]` aceita `smg` (ou `uzi`), `mac` (ou `mac10`, `mac-10`, `silenced`), `mp5`, `pump`, `chrome`, `magnum` (ou `deagle`), `axe` (ou `fireaxe`), `bat`, `cricket`, `guitar`, `golf`, `pan`, qualquer outro nome de script de arma branca (`katana`, `machete`, `crowbar`) e as chaves completas (`weapon_smg`, `weapon_melee_katana`, …).

## Cvars

| Cvar | Padrão | Para quê |
|---|---|---|
| `weapon_skins_enabled` | `0` | Chave geral (definida como `1` no `shared_cvars.cfg`) |
| `l4d2_web_url` | `""` | URL do site, compartilhada com o `l4d2_gameinfo_sync` |
| `l4d2_web_secret` | `""` | Segredo do site, compartilhado com o `l4d2_gameinfo_sync` |
| `weapon_skins_kick_no_downloads` | `0` | Expulsa jogadores sem downloads (definida como `1` no `shared_cvars.cfg`) |
| `weapon_skins_pile_radius` / `weapon_skins_pile_max` | `120` / `3` | Limpeza de pilhas de armas (`weapon_skins_pile_max 0` desliga) |
| `weapon_skins_preview_all` | `0` | Modo de teste: todas as skins são baixadas e podem ser usadas pelos admins root |
