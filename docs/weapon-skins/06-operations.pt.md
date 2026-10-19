# 6. Operação e procedimentos

🌐 [English](06-operations.md) | **Português** | [Español](06-operations.es.md) · [Início da wiki](README.pt.md)

## Configuração e segredos

> Valores de segredos nunca são escritos em repositórios, documentação ou chat. Esta página só diz **onde** cada um fica.

### Servidor de jogo

| Configuração | Arquivo | Versionado? |
|---|---|---|
| `l4d2_web_url` (URL do site, compartilhada pelo `l4d2_weapon_skins` e pelo `l4d2_gameinfo_sync`) | `cfg/server.cfg` | sim |
| `l4d2_web_secret` (= o `SecretKey` do site) | `cfg/server_secrets.cfg` | **não** (ignorado pelo git, existe só no servidor) |
| `weapon_skins_enabled`, `weapon_skins_kick_no_downloads`, configurações de pilhas | `cfg/cfgogl/{zonemod,neomod}/shared_cvars.cfg` | sim |
| `sv_downloadurl` (FastDL) | `cfg/server.cfg` | sim |

O `cfg/server.cfg` roda `exec server_secrets.cfg` no início, então os segredos são carregados em todo início de mapa.

### Site (`appsettings.json`, só no servidor web)

| Chave | Para quê |
|---|---|
| `AzureWebJobsStorage` | Conta de storage (tabelas `SkinShop`, `SkinPrices`, `ChatBans`, …) |
| `PlayStatsApiUrl`, `ServerId`, `PlayStatsSecret` | Chamadas à PlayStats API (estrelas, ranking) |
| `SecretKey` | Segredo compartilhado conferido pelo `[RequiredSecretKey]` (servidor de jogo → site) |
| `ServerAdmins` | Lista de SteamID64 dos admins (separados por `;`) |
| `SteamApiKey` | Steam Web API (nomes e avatares) |
| `ServerDns` | Endereço do servidor de jogo mostrado no site (página do servidor) |
| `SkinShotsUrl` (opcional) | Onde ficam as fotos das skins; o padrão é o container `assets/skin-shots` da conta `l4d2playstats` |

### API (app settings do Azure Functions)

`AzureWebJobsStorage` — a mesma conta de storage. A tabela `Statistics` é a origem do ranking e das estrelas: **nunca apague nem edite essa tabela**.

## Deploys

| Repositório | Gatilho | O que acontece |
|---|---|---|
| l4d2-zone-server | push na `master` (mudanças só em `docs/` ou em arquivos `*.md` não disparam) | `addons/`, `cfg/`, `bash/`, `scripts/` são empacotados e extraídos na pasta do jogo. O `server_secrets.cfg` não é alterado |
| l4d2-zone-server-assets | push na `main` | `models/` e `materials/` vão para a pasta do jogo e para o blob do FastDL; `fastdl/` e `assets/` (incluindo as fotos das skins em `assets/skin-shots/`) vão para blobs. Só os arquivos novos ou alterados vão para os blobs, e nada é apagado |
| l4d2-playstats-api | push na `main` | Build, testes e o artefato de build `function`. A pipeline do repositório não publica nada: a publicação no app do Azure Functions acontece fora dele, a partir desse artefato |
| l4d2-playstats-web | push na `main` | Publicação self-contained, copiada para o servidor web e reiniciada na sessão `screen` `l4d2-playstats-web` |
| l4d2-anti-cheat-client | push na `main` | Build, testes e um pacote assinado do cliente enviado para o blob storage; os jogadores recebem a versão nova (com o novo manifesto de assets do servidor) quando o número da versão muda |

**Ordem quando uma mudança envolve vários repositórios:** API → site → zone-server. O plugin depende dos endpoints do site, e o site depende da API. Quando arquivos de skin mudam, o cliente do anti-cheat e os assets vêm primeiro: veja a próxima seção.

**Plugins e configs** só passam a valer depois que o servidor os recarrega: reinicie o servidor de jogo depois de um deploy do zone-server que altere plugins.

### Quando os modelos combinados mudam

Adicionar, remover ou alterar uma skin muda os modelos combinados e os arquivos das skins. Siga esta ordem:

1. **Cliente do anti-cheat** — publique o cliente novo (novo manifesto de assets do servidor + aumento da versão) e confira se ele já está disponível para os jogadores.
2. **Assets** — faça o push do repositório de assets (pasta do jogo + FastDL + fotos das skins).
3. **Site** — faça o push do catálogo (`skins.json`) e das miniaturas.
4. **Zone-server** — faça o push do `weapon_skins.cfg` (índices de family).
5. **Reinicie o servidor de jogo com ele vazio** (veja abaixo).

Por quê: o anti-cheat confere os arquivos de skin enviados pelo servidor com o manifesto dele, então um jogador cujo cliente ainda tem o manifesto antigo e que baixa o modelo novo é expulso. E um modelo alterado precisa ser baixado na conexão, não numa troca de mapa, por isso o servidor é reiniciado.

## Reiniciando o servidor de jogo

1. Confira se ninguém está jogando: envie `status` para a sessão `screen` `27015` e veja a quantidade de jogadores.
2. Reinicie usando só os scripts do servidor: `bash/stop.sh 27015`, espere alguns segundos, `bash/start.sh 27015 c2m1_highway`.
3. Confira `sm plugins info l4d2_weapon_skins` (status `running`) e o log de erros do SourceMod do dia.

> **Não** rode os scripts de bootstrap ou de firewall remotamente: eles podem derrubar a sessão SSH.

## Tarefas comuns

| Tarefa | Como |
|---|---|
| Mudar o preço de uma skin | Admin → Preços das skins → clique na skin → altere → Salvar (ou Restaurar padrão). Vale só para compras novas |
| Estornar uma compra | Admin → Compras de skins → clique na compra → *Estornar compra* → *Confirmar estorno*. As estrelas voltam; a skin é desequipada |
| Estornar tudo | Ferramenta de admin para casos excepcionais (por exemplo, depois de recalcular os preços). Admin → Compras de skins → *Estornar tudo* → marque a confirmação → *Estornar tudo*. Todas as compras **e todos os presentes** de todos os jogadores são estornados (mesmas regras do estorno individual); as estrelas dos jogadores não mudam, só o que foi gasto volta. Não pode ser desfeito. Se algum item falhar, rode de novo |
| Estorno da temporada | Automático no reset do ranking (00:00 UTC do dia 1º de jan, mar, mai, jul, set e nov = 21:00 do dia anterior em Brasília). Procure `Skin purchases made before the season of ... refunded` no log do site. Os presentes ficam. Não precisa fazer nada; se o site estava fora do ar no reset, ele recupera em até 10 minutos depois de subir |
| Dar uma skin | Admin → Compras de skins → *Dar skin de presente* (ou pelo modal de preço, ou pelos detalhes da skin na loja). Escolha o jogador e a skin. Os presentes nunca são estornados pelo estorno da temporada |
| Banir um jogador do chat | Admin → Bans do Chat → *Adicionar ban* → escolha entre quem falou recentemente ou *Escolher da lista* |
| Testar todas as skins no jogo | `!cvar weapon_skins_preview_all 1`, troque o mapa, reconecte; admins root podem usar qualquer skin. Depois desligue e troque o mapa (todo jogador que conectar nesse meio-tempo baixa todas as skins, ~300 MB) |
| Adicionar uma skin nova | Veja [Assets das skins → Adicionando uma skin nova](02-assets.pt.md#adicionando-uma-skin-nova-checklist) |
| Trocar o segredo compartilhado | Mude o `SecretKey` do site **e** o `l4d2_web_secret` no `server_secrets.cfg` para o mesmo valor novo, depois reinicie o site e o servidor de jogo |

## Solução de problemas

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| A skin comprada não aparece | Ela só aparece a partir da próxima troca de mapa | Troque o mapa; confira se o `/api/skins` lista a skin |
| As skins de um jogador sumiram no início de um mês | Estorno da temporada no reset do ranking | Esperado: as estrelas voltaram e o jogador pode comprar de novo. Os presentes ficam |
| A arma aparece como `ERROR` | Os modelos foram baixados durante uma troca de mapa | Reinicie o jogo; os modelos devem ser baixados na conexão |
| A skin aparece só para alguns jogadores | Um jogador está com os downloads desligados e `weapon_skins_kick_no_downloads` está `0` | Ligue a expulsão, ou peça para o jogador ligar os downloads |
| Jogador expulso por downloads mesmo com "Permitir tudo" no menu | `cl_allowdownload` está `0` (ele não tem opção no menu) | A mensagem da expulsão traz o comando: `cl_allowdownload 1` no console, e tirar `cl_allowdownload 0` do `autoexec.cfg`/`config.cfg`. As expulsões ficam no log do SourceMod (`Kicked ... because ...`) |
| Jogadores expulsos pelo anti-cheat logo depois de um deploy de skins | Os assets foram publicados antes do cliente do anti-cheat com o manifesto novo | Publique o cliente novo; veja [Quando os modelos combinados mudam](#quando-os-modelos-combinados-mudam) |
| "Não foi possível carregar suas estrelas" na loja | O site não conseguiu acessar a API | Verifique a API; as compras ficam bloqueadas até ela responder |
| MVPs novos ainda não contados | Cache da API (até 1 h) | Aguarde; o próximo upload limpa o cache naquela instância |
| O primeiro mapa depois de reiniciar baixa skins que ninguém comprou | `weapon_skins_cache.json` antigo de outra versão | Apague os arquivos de cache em `addons/sourcemod/data/` e reinicie |
| Chat/game info pararam de chegar no site | `l4d2_web_url`/`l4d2_web_secret` ausentes ou diferentes do `SecretKey` | Confira o `server.cfg`, o `server_secrets.cfg` e o `SecretKey` do site |

## Testes

- **Serviço da loja** — durante o desenvolvimento, testes de integração rodaram o `SkinShopService` e os repositórios reais contra o **Azurite** (o emulador local do Azure Storage), com um serviço de estrelas falso: compra, compra duplicada, estrelas insuficientes, API fora do ar, compras simultâneas, equipar/desequipar, presente, estorno, preços alterados. O projeto de testes não está versionado; teste mudanças na loja contra o Azurite, nunca contra as tabelas de produção.
- **Site local** — rode o site com um content root separado cujo `appsettings.json` aponte o `AzureWebJobsStorage` para `UseDevelopmentStorage=true`, para nada tocar nas tabelas de produção. Lembre que o estorno da temporada roda quando o site sobe: compras no Azurite com data anterior à temporada atual são estornadas.
- **Estrelas** — compare o `/api/stars` com o ranking de todo o histórico guardado mais o período atual.
- **Plugin** — compile com o `spcomp` incluído ([`addons/sourcemod/scripting/sourcemod/spcomp.exe`](../../addons/sourcemod/scripting/sourcemod/spcomp.exe)) e teste no servidor, de preferência sem ninguém jogando.
