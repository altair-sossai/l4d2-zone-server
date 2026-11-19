# Plugins Customizados — l4d2-zone-server

🌐 [English](README.md) | **Português** | [Español](README.es.md)

Este documento descreve os plugins mantidos neste repositório:

- **Plugins customizados** — escritos especificamente para este servidor.
- **Plugins adaptados** — criados por outros autores e modificados aqui (correções e ajustes) para se adequar a este servidor. Eles **não são obra original**; o autor e o repositório originais são creditados em cada seção.

Para os demais plugins de terceiros que vêm sem modificações com a base [ZoneMod / L4D2 Competitive Rework](https://github.com/SirPlease/L4D2-Competitive-Rework), consulte os autores originais.

- **Fontes:** [`addons/sourcemod/scripting/`](../../addons/sourcemod/scripting/) (`.sp`)
- **Compilados:** [`addons/sourcemod/plugins/optional/`](../../addons/sourcemod/plugins/optional/) (`.smx`) — exceto `annoyance_exploit_fixes`, que fica em `plugins/fixes/`
- **Script de compilação:** [`ps/compile-custom-plugins.ps1`](../../ps/compile-custom-plugins.ps1) — veja [Compilando os plugins customizados](../maintenance/compile-custom-plugins.pt.md)

---

## Como a configuração funciona neste repositório

A maioria destes plugins fica em `optional/`, então eles não são carregados automaticamente — são carregados explicitamente e configurados pela camada de configuração do ZoneMod. Estes são os pontos de contato:

| Arquivo | Finalidade |
|------|---------|
| `cfg/cfgogl/<mod>/shared_plugins.cfg`  | **Carrega** cada plugin (`sm plugins load optional/<name>.smx`) |
| `cfg/cfgogl/<mod>/shared_cvars.cfg`    | **Define ConVars** via `confogl_addcvar <cvar> <value>` |
| `cfg/cfgogl/<mod>/shared_settings.cfg` | Também define ConVars via `confogl_addcvar` (usado para `l4d2_spec_lister_hint`) |
| `cfg/server.cfg`                       | Valores do servidor inteiro que precisam existir antes de qualquer config de partida ser carregada (`l4d2_web_url`, `playstats_url`, `playstats_public_url`) |
| `cfg/server_secrets.cfg`               | **Segredos** (tokens/chaves de API) via `sm_cvar` — **ignorado pelo git**, nunca commitado; executado no início do `server.cfg` |
| `cfg/playstats_token.cfg`              | **Fora do repositório.** Gravado pelo pipeline de deploy a partir de uma variável secreta, com o token deste servidor no l4d2.com.br (`playstats_token` e `l4d2_web_secret`); executado pelo `server.cfg` |

`<mod>` é a pasta de config ativa, principalmente [`zonemod`](../../cfg/cfgogl/zonemod/) e [`neomod`](../../cfg/cfgogl/neomod/).

> **ConVars marcadas como `PROTECTED`** são criadas com `FCVAR_PROTECTED`, então o valor delas nunca é mostrado aos clientes. Segredos de verdade nunca vão nos arquivos de cfg versionados: o token do PlayStats é gravado pelo pipeline de deploy no `cfg/playstats_token.cfg`, e os demais segredos vão no `cfg/server_secrets.cfg`, para nunca vazarem no repositório público; as demais ConVars protegidas (URLs) são definidas nos arquivos cfg versionados.

As mensagens de chat mostradas aos jogadores ficam em [`addons/sourcemod/translations/`](../../addons/sourcemod/translations/) (`<name>.phrases.txt`) e podem ser traduzidas/editadas lá.

---

## Índice

**Plugins customizados**

| Plugin | Resumo |
|--------|-----------|
| [l4d2_queue](#l4d2_queue) | Fila de jogadores — mostra quem joga em seguida e permite que os jogadores peçam uma vaga |
| [l4d2_friendly_fire_control](#l4d2_friendly_fire_control) | Expulsa jogadores que passam de um limite de fogo amigo |
| [l4d2_early_victory](#l4d2_early_victory) | Pula o último mapa quando a partida já está decidida |
| [l4d2_afk_to_spec](#l4d2_afk_to_spec) | Move jogadores AFK para espectador durante o ready-up |
| [l4d2_block_spec_during_tank](#l4d2_block_spec_during_tank) | Impede que sobreviventes troquem de time enquanto o tank está vivo |
| [l4d2_no_skip_getup_animation](#l4d2_no_skip_getup_animation) | Impede pular a animação de levantar trocando de time |
| [l4d2_alltalk_before_round_start](#l4d2_alltalk_before_round_start) | Ativa o all-talk antes de a primeira rodada começar |
| [l4d2_tank_is_comming](#l4d2_tank_is_comming) | Avisa todos quando o ponto de spawn do tank se aproxima |
| [l4d2_spec_lister](#l4d2_spec_lister) | Permite que espectadores escolham qual time ouvem |
| [l4d2_forced_names](#l4d2_forced_names) | Fixa um nome para SteamIDs específicos |
| [l4d2_campaign_vote](#l4d2_campaign_vote) | Permite que qualquer jogador vote para trocar para qualquer campanha instalada |
| [l4d2_lerp_advisor](#l4d2_lerp_advisor) | Diz aos jogadores com lerp inválido quais comandos de rede executar |

**Plugins de estatísticas (mantidos no l4d2-playstats-hub)**

| Plugin | Resumo |
|--------|--------|
| [l4d2_playstats_sync, l4d2_gameinfo_sync, l4d2_ranking, l4d2_show_patent_icon, l4d2_weapon_skins](#plugins-de-estatísticas-l4d2-playstats-hub) | Estatísticas, partida ao vivo, ranking, patentes e skins de armas do l4d2.com.br |

**Plugins adaptados (terceiros)**

| Plugin | Autor original | Resumo |
|--------|-----------------|-----------|
| [l4d2_mix](#l4d2_mix-adaptado) | Luckylock (LuckyServ) | Escolha de capitães/times (mix) por menus no jogo |
| [annoyance_exploit_fixes](#annoyance_exploit_fixes-adaptado) | Sir (SirPlease) | Bloqueia abuso do callvote e flood de chat via `bugpause` |

---

# Plugins customizados

## l4d2_queue

**Fonte:** [`scripting/l4d2_queue.sp`](../../addons/sourcemod/scripting/l4d2_queue.sp) · **Versão:** 2.0.0

**O que faz** — Mantém uma fila ordenada de todos os jogadores humanos do servidor, na ordem em que conectaram, e a usa para decidir quem joga em seguida. A fila é salva em `addons/sourcemod/data/l4d2_queue.txt`, então sobrevive a trocas de mapa e recarregamentos do plugin. Comportamento que os jogadores veem:

- Quando um novo jogo começa depois de um jogo terminado, a fila é reordenada: o time vencedor vai para a frente e o time perdedor vai para o final, atrás de todos que estavam esperando. Por cerca de 60 segundos depois que a rodada começa, os times são organizados automaticamente para que os primeiros jogadores da fila (pulando quem tem lerp inválido) sejam os que jogam. Usar `!slot` nesse meio-tempo mostra *"The teams are being arranged automatically, please wait a moment."*
- `!fila` / `!queue` mostra a lista de espera em ordem (`Queue:` seguido de `1º`, `2º`…). Jogadores dos times iniciais ficam de fora, jogadores que estão em um time aparecem destacados, e nada é mostrado enquanto não houver mais jogadores do que vagas.
- `!vaga` / `!slot` durante o ready-up de um novo jogo (placar 0–0):
  - Se um time tem uma vaga livre, o jogador entra nela: *"You have taken a slot in the game."*
  - Caso contrário, ele pega a vaga do jogador mais atrás na fila entre os que estão jogando atrás dele. Quem pediu vê *"You have claimed a slot, {player} was moved to spectators."* e o jogador removido recebe *"{player} has claimed your slot because they were ahead of you in the queue."*
  - Se todos que estão jogando estão à frente dele: *"Everyone on the teams is ahead of you in the queue."*
  - Um jogador só pode pegar a vaga do mesmo jogador `l4d2_queue_max_claims` vezes antes de o jogo começar: *"You have already claimed a slot from {player} too many times."*
- Durante um jogo em andamento, só jogadores dos times iniciais podem usar `!slot`, para voltar ao time original no lugar de um substituto: *"During the game only players from the starting teams can request a slot."* Se o substituto estiver controlando o tank, o pedido espera: *"{player} is controlling the tank, request your slot again when the tank dies."* `!slot` não faz nada depois que a rodada termina.
- Nenhuma vaga pode ser pedida enquanto um mix está em andamento: *"You can only request a slot at the start of a new game and while no mix is in progress."*
- Um jogador com lerp inválido (fora do `sm_min_lerp` / `sm_max_lerp` do `lerpmonitor`) não pode pedir vaga: *"Your lerp ({n}ms) is invalid. Adjust it between {min}ms and {max}ms before requesting a slot."*
- 30 segundos depois que uma rodada começa, durante o ready-up de um novo jogo com mais jogadores do que vagas, todo espectador recebe o lembrete: *"Check the !queue. If you are ahead of someone playing, use !slot."*
- Um jogador desconectado mantém seu lugar por `l4d2_queue_disconnect_timeout` segundos antes de ser removido. No fim da segunda rodada de um mapa, a fila é mostrada a todos depois de `l4d2_queue_endmap_delay` segundos (para que o painel de MVP/estatísticas apareça primeiro).

**Objetivo** — Tornar o rodízio em um servidor cheio justo e transparente, para que ninguém perca a vez e todos possam ver quem é o próximo.

**ConVars**

| ConVar | Padrão | Descrição |
|--------|---------|-------------|
| `l4d2_queue_disconnect_timeout` | `300` | Segundos que um jogador desconectado fica na fila antes de ser removido |
| `l4d2_queue_endmap_delay` | `8.0` | Segundos depois do fim da 2ª rodada do mapa antes de mostrar a fila (espera o MVP/estatísticas primeiro) |
| `l4d2_queue_max_claims` | `2` | Quantas vezes um jogador pode pegar a vaga do mesmo jogador antes de o jogo começar |

**Comandos**

| Comando | Acesso | Descrição |
|---------|--------|-------------|
| `sm_fila` / `sm_queue` | todos | Mostra a fila atual |
| `sm_vaga` / `sm_slot` | todos | Pede uma vaga disponível |

**Como configurar** — Defina as ConVars no `shared_cvars.cfg`, por exemplo `confogl_addcvar l4d2_queue_disconnect_timeout 300`.

---

## l4d2_friendly_fire_control

**Fonte:** [`scripting/l4d2_friendly_fire_control.sp`](../../addons/sourcemod/scripting/l4d2_friendly_fire_control.sp) · **Versão:** 1.0.0

**O que faz** — Enquanto uma rodada está valendo, acompanha o dano de fogo amigo entre sobreviventes humanos. Cada jogador tem um acumulador que sobe com o dano que causa a um colega de time e desce `decrement` a cada `interval` segundos. Quando o acumulador chega a `limit`, o jogador é expulso e o jogo é pausado (os jogadores despausam normalmente com `!unpause`, como numa pausa por crash); todos veem *"{player} was kicked for friendly fire."* e o jogador expulso recebe o motivo *"You were kicked for friendly fire."* Dano acidental ocasional se dissipa e nunca causa expulsão; só dano ao time contínuo/repetido causa.

O dano é ignorado quando a vítima está incapacitada, pendurada ou caindo de uma borda, presa por um infectado especial, ou tem vida total (permanente + temporária) igual ou abaixo de `min_health` (por exemplo, derrubar por misericórdia um colega com pouca vida). Os contadores são zerados quando a rodada termina.

**Objetivo** — Desencorajar automaticamente dano intencional ou repetido ao próprio time sem precisar de um admin online, perdoando um tiro perdido de vez em quando.

**ConVars**

| ConVar | Padrão | Descrição |
|--------|---------|-------------|
| `l4d2_friendly_fire_control_enabled` | `1` | Ativa (`1`) / desativa (`0`) o plugin |
| `l4d2_friendly_fire_control_interval` | `1.0` | Intervalo (s) em que o dano de FF acumulado diminui |
| `l4d2_friendly_fire_control_decrement` | `1.0` | Quanto é subtraído do acumulador a cada intervalo |
| `l4d2_friendly_fire_control_limit` | `20.0` | Dano de FF acumulado que causa a expulsão |
| `l4d2_friendly_fire_control_min_health` | `10.0` | O FF é ignorado quando a vida total da vítima é igual ou menor que este valor |

**Comandos** — Nenhum.

**Como configurar** — As cinco ConVars no `shared_cvars.cfg`. Diminua `limit` para um servidor mais rígido; aumente `decrement` ou diminua `interval` para perdoar mais rápido.

---

## l4d2_early_victory

**Fonte:** [`scripting/l4d2_early_victory.sp`](../../addons/sourcemod/scripting/l4d2_early_victory.sp) · **Versão:** 1.7.0

**Rendição por equipe** — `!surrender` ou `!render` abre uma votação somente para os humanos da própria equipe, inclusive jogadores mortos. Espectadores não podem iniciar nem votar. Por padrão, fica disponível a partir do segundo mapa, em qualquer round, após 10 segundos de live. Os votos Sim precisam superar estritamente 50% dos integrantes elegíveis no início: em quatro jogadores, são necessários três. Abstenções não aprovam a rendição; saída ou troca de equipe de um eleitor cancela a votação. Uma tentativa recusada ou cancelada aplica um intervalo de 60 segundos para aquela equipe.

Ao aprovar, o resultado é fixado: o adversário recebe `max(placar A, placar B) + l4d2_surrender_points` (250 por padrão), preservando o placar de quem se rendeu e a identidade da equipe durante a troca de lados. O plugin bloqueia novas votações, anuncia cada etapa e mata todos após `l4d2_early_victory_slay_delay`. Se era o primeiro round, aguarda o segundo, protege a espera de `l4d2_surrender_forcestart_delay` contra ready ou forcestart antecipados, executa `sm_forcestart`, aguarda o evento de live e mata todos após `l4d2_surrender_second_slay_delay`. Esse fluxo exige ReadyUp manual ou por equipe (modos 1 ou 3), com auto-ready desativado; no segundo round essa restrição não se aplica. Se o forcestart não produzir live no tempo esperado, há retentativa, aviso aos jogadores e diagnóstico no log; a campanha não é trocada com rounds incompletos. Os infectados humanos são preparados após a aprovação, após o live do segundo round e antes do encerramento natural ou dos slays, garantindo os registros de spawn exigidos pela API. Só troca de campanha após concluir o segundo round e esperar `l4d2_early_victory_change_delay`, com mínimo efetivo de 2 segundos para a gravação do PlayStats. O envio continua pelo sincronizador existente no próximo round; o plugin não aguarda confirmação HTTP. A habilitação da rendição é independente da detecção automática de vitória. As regras de liberação (segundo mapa, qualquer round, 10 segundos de live e maioria estrita dos integrantes) são fixas; a duração da votação reutiliza `l4d2_early_victory_vote_duration`.

**O que faz** — Detecta quando uma campanha versus já está decidida antes do último mapa. Durante a segunda rodada do capítulo configurado (por padrão o 4º mapa, nunca um final), verifica o placar a cada 5 segundos (não enquanto há um tank vivo ou um sobrevivente incapacitado). A partida está decidida quando o time que joga de sobrevivente está à frente por pelo menos `min_diff`, ou não consegue mais ficar a menos de `min_diff` do outro time nem com a pontuação máxima que resta no mapa. Então todos recebem *"Game decided ({score} x {score}). Losing team will vote."* e o time perdedor recebe uma votação curta com o título *"Game decided, keep playing?"*:

- Se pelo menos metade do time perdedor votar Sim (votos não dados contam como Não) → *"Losing team chose to continue."* e a partida segue normalmente. Se a votação for cancelada → *"Vote cancelled. Match continues."*
- Caso contrário → *"No majority to continue. Ending match."*, toca um som de vitória, a próxima campanha é anunciada (*"Next campaign: {name}"*) com uma contagem regressiva na tela (*"Next campaign: {name} - changing map in {n}s"*), todos são mortos depois de `slay_delay`, e o servidor troca para o primeiro mapa da próxima campanha depois de mais `change_delay` segundos.
- Durante a segunda rodada desse capítulo, votações para trocar de campanha são bloqueadas: *"Map change blocked until the match ends."* Quando a trava de troca de campanha está ativa e a rendição está habilitada para aquele mapa e round, a mensagem orienta o jogador a usar `!surrender`. Durante um encerramento já aprovado, pede para aguardar a próxima campanha.

A próxima campanha é o primeiro item de uma fila de rotação (veja abaixo); quando a fila está vazia, é uma aleatória entre as 10 campanhas oficiais que o plugin conhece (Dead Center, Dark Carnival, Swamp Fever, Hard Rain, The Parish, No Mercy, Death Toll, Dead Air, Blood Harvest, Cold Stream). A campanha em jogo é removida da fila no início do mapa. Um admin pode adicionar campanhas à fila ou limpá-la por um menu (*"Queue the next campaigns (in queue: {n})"* / *"Clear list"*); cada mudança é anunciada (*"The next campaigns are: …"*).

**Objetivo** — Evitar jogar um último mapa sem sentido quando o resultado já está definido, e girar o servidor para uma campanha nova de forma limpa.

**ConVars**

| ConVar | Padrão | Descrição |
|--------|---------|-------------|
| `l4d2_early_victory_enabled` | `1` | Ativa / desativa |
| `l4d2_early_victory_chapter` | `4` | Capítulo (índice do mapa) que dispara a verificação |
| `l4d2_early_victory_min_diff` | `15` | Diferença mínima de placar necessária para iniciar a votação |
| `l4d2_early_victory_vote_duration` | `15` | Duração das votações de vitória antecipada e de rendição, em segundos |
| `l4d2_early_victory_slay_delay` | `5.0` | Segundos depois do anúncio antes de matar todos |
| `l4d2_early_victory_change_delay` | `3.0` | Segundos depois de matar todos antes de trocar de campanha |
| `l4d2_surrender_enabled` | `1` | Ativa as votações de rendição |
| `l4d2_surrender_cooldown` | `60.0` | Intervalo após tentativa recusada ou cancelada, por equipe |
| `l4d2_surrender_points` | `250` | Pontos acima do maior placar, dados ao adversário |
| `l4d2_surrender_forcestart_delay` | `8.0` | Espera após início do segundo round antes do forcestart; mínimo 6 segundos para inicializar o PlayStats |
| `l4d2_surrender_second_slay_delay` | `3.0` | Espera após live no segundo round automático; mínimo 1 segundo |

**Comandos**

| Comando | Acesso | Descrição |
|---------|--------|-------------|
| `l4d2_early_victory_queue "<Campaign>"` | servidor (cfg) | Adiciona uma campanha oficial à fila de rotação (uma por linha); nomes desconhecidos são registrados como erro |
| `l4d2_early_victory_queue_lock` | servidor (cfg) | Trava a fila; chamadas seguintes de `l4d2_early_victory_queue` são ignoradas |
| `sm_setnextcampaign` | `ADMFLAG_CHANGEMAP` | Menu para adicionar campanhas à fila ou limpá-la |
| `sm_early_victory_debug` | `ADMFLAG_ROOT` | Mostra os placares internos e o detalhamento dos bônus para depuração |
| `sm_surrender`, `sm_render` | jogadores das equipes | Votação para a própria equipe se render e perder a partida |

**Como configurar** — Defina as ConVars via `confogl_addcvar` no `shared_cvars.cfg` e, logo depois, monte a rotação de campanhas com linhas `l4d2_early_victory_queue` diretas, terminando com `l4d2_early_victory_queue_lock`. Exemplo (resumido do [`zonemod/shared_cvars.cfg`](../../cfg/cfgogl/zonemod/shared_cvars.cfg)):

```
confogl_addcvar l4d2_early_victory_chapter 4
confogl_addcvar l4d2_early_victory_min_diff 15
l4d2_early_victory_queue "The Parish"
l4d2_early_victory_queue "Hard Rain"
l4d2_early_victory_queue "Death Toll"
l4d2_early_victory_queue_lock
```

---

## l4d2_afk_to_spec

**Fonte:** [`scripting/l4d2_afk_to_spec.sp`](../../addons/sourcemod/scripting/l4d2_afk_to_spec.sp) · **Versão:** 1.0.0

**O que faz** — Durante o ready-up, observa jogadores AFK (sem mexer o mouse, apertar teclas ou mandar mensagem no chat). Quando os dois times estão cheios e pelo menos um espectador está esperando para jogar, um jogador que está AFK há mais tempo que o limite é movido para espectador para liberar a vaga, e todos veem *"{player} was moved to spectators after being AFK for {n} seconds."* O limite depende do jogo: `new_game_timeout` enquanto o placar é 0–0, `ongoing_game_timeout` depois que o jogo começou. Só age durante o ready-up, então uma rodada valendo nunca é atrapalhada.

**Objetivo** — Impedir que jogadores AFK segurem uma vaga enquanto jogadores ativos esperam, sem interferir em uma rodada em andamento.

**ConVars**

| ConVar | Padrão | Descrição |
|--------|---------|-------------|
| `l4d2_afk_to_spec_new_game_timeout` | `180` | Segundos que um jogador pode ficar AFK durante o ready-up enquanto o placar é 0–0 |
| `l4d2_afk_to_spec_ongoing_game_timeout` | `360` | Segundos que um jogador pode ficar AFK durante o ready-up depois que o jogo começou |

**Comandos** — Nenhum.

**Como configurar** — Defina os dois limites no `shared_cvars.cfg`.

---

## l4d2_block_spec_during_tank

**Fonte:** [`scripting/l4d2_block_spec_during_tank.sp`](../../addons/sourcemod/scripting/l4d2_block_spec_during_tank.sp) · **Versão:** 1.0.0

**O que faz** — Enquanto o tank está vivo, impede que sobreviventes troquem de time (`jointeam`, `sm_spectate`/`sm_spec`/`sm_s`). O jogador bloqueado recebe *"Tank is alive, use !pause to change team."* A restrição é liberada enquanto o jogo está pausado, então trocas legítimas continuam possíveis.

**Objetivo** — Impedir que jogadores fujam do tank ou abusem de trocas para espectador no meio do tank para resetar o controle/aggro.

**ConVars** — Nenhuma.

**Comandos** — Intercepta `sm_spectate`, `sm_spec`, `sm_s` e `jointeam` (nenhum comando novo registrado).

**Como configurar** — Não precisa de configuração; basta carregá-lo.

---

## l4d2_no_skip_getup_animation

**Fonte:** [`scripting/l4d2_no_skip_getup_animation.sp`](../../addons/sourcemod/scripting/l4d2_no_skip_getup_animation.sp) · **Versão:** 1.0.0

**O que faz** — Bloqueia o exploit em que um jogador pula a animação de levantar (depois de levar pounce, charge etc.) indo rapidamente para espectador e voltando. Um sobrevivente que levou qualquer dano nos últimos 5 segundos não pode ir para espectador: `sm_spectate`/`sm_spec`/`sm_s` e `jointeam` para qualquer time que não seja o dos sobreviventes são ignorados em silêncio, então a animação sempre acontece até o fim.

**Objetivo** — Remover um exploit de movimento/tempo e manter as animações de levantar iguais para todos.

**ConVars** — Nenhuma.

**Comandos** — Intercepta `sm_spectate`, `sm_spec`, `sm_s` e `jointeam` (nenhum comando novo registrado).

**Como configurar** — Não precisa de configuração; basta carregá-lo.

---

## l4d2_alltalk_before_round_start

**Fonte:** [`scripting/l4d2_alltalk_before_round_start.sp`](../../addons/sourcemod/scripting/l4d2_alltalk_before_round_start.sp) · **Versão:** 1.1.0

**O que faz** — 10 segundos depois que um mapa começa, liga o `sv_alltalk` se o placar ainda é 0–0 (o primeiro mapa de um jogo), para que os dois times possam conversar durante o aquecimento/ready-up, e desliga em qualquer outro mapa. Quando a contagem regressiva para valer começa (do `readyup`), desliga o all-talk de novo, restaurando as regras de voz competitivas. Cada mudança é anunciada com *"All talk: ON"* / *"All talk: OFF"*.

**Objetivo** — Permitir conversa amigável entre os times antes da partida começar e, depois, aplicar automaticamente a voz só entre o time quando importa.

**ConVars** — Nenhuma (controla o `sv_alltalk` do jogo).

**Comandos** — Nenhum.

**Como configurar** — Não precisa de configuração; basta carregá-lo.

---

## l4d2_tank_is_comming

**Fonte:** [`scripting/l4d2_tank_is_comming.sp`](../../addons/sourcemod/scripting/l4d2_tank_is_comming.sp) · **Versão:** 1.0.0

**O que faz** — Acompanha o progresso dos sobreviventes no mapa em relação à porcentagem de spawn do tank e, conforme o time se aproxima, mostra uma contagem regressiva no chat: *"Tank in {n}%"* (**Tank** em verde, porcentagem em verde-claro). Os avisos aparecem em 15%, 10% e depois a cada 1% de 5% até 1%, cada um só uma vez. Eles param assim que o tank realmente nasce e são reiniciados quando a rodada começa a valer. Nada é mostrado durante o ready-up ou pausas.

**Objetivo** — Dar aos dois times um aviso justo e consistente de que o tank está chegando, em vez de depender de as pessoas decorarem os pontos de spawn.

**ConVars** — Nenhuma (lê `versus_boss_buffer` e os dados de porcentagem dos bosses).

**Comandos** — Nenhum.

**Como configurar** — Não precisa de configuração; basta carregá-lo. Requer os includes `l4d2_boss_percents` / `readyup` / `pause` na compilação (já presentes neste repositório).

---

## l4d2_spec_lister

**Fonte:** [`scripting/l4d2_spec_lister.sp`](../../addons/sourcemod/scripting/l4d2_spec_lister.sp) · **Versão:** 2.0.0

**O que faz** — Permite que um espectador escolha a voz de qual time quer ouvir (padrão: todos). `!hear` sem argumento abre um menu (*"Who do you want to hear?"*) com as opções *Survivors + spectators*, *Infected + spectators*, *Spectators only* e *Everyone*; ou passe um argumento direto (`!hear survivors|infected|spectators|all`), que confirma com *"You are now hearing: {choice}."* Os outros espectadores são sempre ouvidos. A escolha não tem efeito enquanto o `sv_alltalk` está ligado. 15 segundos depois que um mapa começa (só na primeira rodada), os espectadores recebem uma dica sobre o `!hear` quando `l4d2_spec_lister_hint` é `1`. Admins têm um modo de transmissão (`sm_broadcast`): enquanto ligado, todos ouvem o admin (*"{admin} is now talking to everyone."* / *"{admin} stopped talking to everyone."*).

**Objetivo** — Melhorar a experiência de assistir e narrar, permitindo isolar a comunicação de um time sem deixar de ouvir os outros espectadores.

**ConVars**

| ConVar | Padrão | Descrição |
|--------|---------|-------------|
| `l4d2_spec_lister_hint` | `1` | Mostra aos espectadores uma dica sobre o comando `!hear`. `0`:esconder, `1`:mostrar |

**Comandos**

| Comando | Acesso | Descrição |
|---------|--------|-------------|
| `sm_hear` | todos (espectadores) | Escolhe quem você ouve como espectador. Sem argumento abre o menu; argumento opcional: `survivors` / `infected` / `spectators` / `all` |
| `sm_broadcast` | `ADMFLAG_CHAT` | Liga/desliga o modo de transmissão — enquanto ligado, todos ouvem você |

**Como configurar** — Defina `l4d2_spec_lister_hint` no `shared_settings.cfg` (o `zonemod` define como `0`).

---

## l4d2_forced_names

**Fonte:** [`scripting/l4d2_forced_names.sp`](../../addons/sourcemod/scripting/l4d2_forced_names.sp) · **Versão:** 1.0.0

**O que faz** — Vincula SteamIDs específicos a um nome fixo. Um jogador vinculado recebe o nome ao entrar e, se trocar de nome, volta imediatamente para o nome fixo. Os formatos de id `STEAM_0` e `STEAM_1` são aceitos.

**Objetivo** — Manter jogadores conhecidos com um nome consistente e reconhecível — útil para a integridade das estatísticas/ranking e para a moderação.

**ConVars** — Nenhuma.

**Comandos** — Nenhum.

**Como configurar** — Edite o [`configs/forced_names.cfg`](../../addons/sourcemod/configs/forced_names.cfg), um par `"<steamid>" "<name>"` por jogador, no formato KeyValues:

```
"ForcedNames"
{
	"STEAM_0:1:67149995" "Xei" // https://steamcommunity.com/profiles/76561198094565719
	"STEAM_0:1:28225724" "jon" // https://steamcommunity.com/profiles/76561198016717177
}
```

O plugin lê este arquivo com a API `KeyValues` (não com `exec`), ao iniciar e a cada execução de config — não precisa recarregar manualmente, e nomes com unicode não são cortados como seriam em um cfg executado com `exec`.

---

## l4d2_campaign_vote

**Fonte:** [`scripting/l4d2_campaign_vote.sp`](../../addons/sourcemod/scripting/l4d2_campaign_vote.sp) · **Versão:** 1.0.0

**O que faz** — Permite que qualquer jogador navegue por todas as campanhas instaladas — oficiais e customizadas — e inicie uma votação de troca de mapa por um menu, sem precisar de permissão de admin. Digitar `!votecampaign` (ou `!votecamp`) abre um menu com o título *"Choose a campaign to start a map change vote:"* listando todas as campanhas em ordem alfabética. A lista é montada lendo os arquivos `missions/*.txt` de dentro dos addons VPK montados (pelo sistema de arquivos da Valve), então sempre reflete o que está realmente instalado. As 14 campanhas oficiais aparecem com o nome em inglês (Dead Center, Dark Carnival, …); campanhas customizadas aparecem com o título do próprio VPK. Selecionar um item executa `callvote changemission <Name>` como se o jogador tivesse digitado, iniciando a votação padrão de troca de campanha. Se a lista de campanhas não puder ser lida, o jogador recebe *"Could not read the campaign list."*

**Objetivo** — Dar aos jogadores uma forma simples e independente de propor uma troca de campanha pela votação nativa do jogo, incluindo campanhas customizadas.

**ConVars** — Nenhuma.

**Comandos**

| Comando | Acesso | Descrição |
|---------|--------|-------------|
| `sm_votecampaign` / `sm_votecamp` | todos | Abre o menu de campanhas e inicia uma votação de troca de mapa para a campanha escolhida |
| `sm_listcampaigns` | `ADMFLAG_GENERIC` | Mostra no console o nome bruto e o DisplayTitle de cada campanha encontrada na pasta missions |
| `sm_refreshcampaigns` | `ADMFLAG_GENERIC` | Recarrega o `campaign_vote.cfg` e limpa a lista de campanhas em cache para que ela seja lida de novo na próxima abertura do menu |

**Como configurar** — Opcionalmente edite o [`configs/campaign_vote.cfg`](../../addons/sourcemod/configs/campaign_vote.cfg) (formato KeyValues) para esconder campanhas do menu (`IgnoredCampaigns`) ou trocar o título exibido de uma campanha (`CustomTitles`); `<name>` precisa ser exatamente o `Name` bruto da missão (veja `sm_listcampaigns`). O arquivo é lido de novo a cada execução de config. Os textos mostrados aos jogadores (título do menu e mensagens) ficam em [`addons/sourcemod/translations/l4d2_campaign_vote.phrases.txt`](../../addons/sourcemod/translations/l4d2_campaign_vote.phrases.txt) (inglês, português e espanhol). A votação `changemission` precisa estar habilitada nas configurações de votação do servidor para a votação realmente começar.

---

## l4d2_lerp_advisor

**Fonte:** [`scripting/l4d2_lerp_advisor.sp`](../../addons/sourcemod/scripting/l4d2_lerp_advisor.sp) · **Versão:** 2.0.0

**O que faz** — Funciona junto com o `lerpmonitor`: **não** altera as configurações de ninguém (o servidor não pode forçar CVars do cliente), apenas *orienta*. Quando um jogador conecta (cerca de 5 segundos depois de ser autorizado e estar no servidor) ou entra no time dos sobreviventes/infectados, o plugin verifica o lerp dele e, se estiver fora da faixa permitida, mostra uma mensagem curta de duas linhas — um título colorido (*"Invalid lerp! Paste this in the game console:"*) seguido dos comandos exatos que o jogador deve colar no console do jogo (a linha de comandos fica sem cor para copiar/colar sem problemas, e também é repetida no console dele). As verificações ao conectar acontecem mesmo com o jogador como espectador, então ele é avisado antes de tentar jogar. A orientação só aparece durante o ready-up (quando o `readyup` está carregado), e um intervalo de 3 segundos evita mensagens duplicadas.

O valor do lerp e a faixa válida vêm **inteiramente do `lerpmonitor`** — o lerp atual vem do native `LM_GetCurrentLerpTime` e os limites das CVars `sm_min_lerp` / `sm_max_lerp` dele — então mudar os limites lá muda automaticamente quando este aviso aparece, sem nada para atualizar aqui. Se o `lerpmonitor` não estiver carregado, o plugin fica em silêncio.

**Objetivo** — Dar aos jogadores com lerp ruim/padrão uma solução clara e independente, em vez de apenas serem movidos para espectador pelo `lerpmonitor`, sem duplicar nada da lógica de detecção dele.

**ConVars**

| ConVar | Padrão | Descrição |
|--------|---------|-------------|
| `l4d2_lerp_advisor_enabled` | `1` | Ativa / desativa a mensagem de orientação |

Os comandos sugeridos (`cl_interp 0; cl_interp_ratio 0; rate 100000; cl_cmdrate 100; cl_updaterate 100`) estão fixos no código do plugin, então são mostrados ao jogador por inteiro (um valor de CVar definido via `confogl_addcvar` seria cortado no primeiro `;`).

**Comandos** — Nenhum.

**Como configurar** — Defina `l4d2_lerp_advisor_enabled` no `shared_cvars.cfg`. Requer o `lerpmonitor` carregado (ele fornece o valor do lerp e a faixa `sm_min_lerp` / `sm_max_lerp`). Os textos mostrados aos jogadores ficam em [`addons/sourcemod/translations/l4d2_lerp_advisor.phrases.txt`](../../addons/sourcemod/translations/l4d2_lerp_advisor.phrases.txt) (inglês, português e espanhol).

---

# Plugins de estatísticas (l4d2-playstats-hub)

`l4d2_playstats_sync`, `l4d2_gameinfo_sync`, `l4d2_ranking`, `l4d2_show_patent_icon` e `l4d2_weapon_skins`, com as traduções deles e o `configs/weapon_skins.cfg`, não ficam neste repositório. Eles são mantidos no [l4d2-playstats-hub](https://github.com/altair-sossai/l4d2-playstats-hub), junto com o site com que conversam, o l4d2.com.br. O `l4d2_playstats`, plugin do Competitive Rework que grava os arquivos de estatísticas, continua aqui.

- **Deploy** — a cada deploy, o pipeline deste repositório ([`azure-pipelines.yml`](../../azure-pipelines.yml)) baixa o `l4d2-playstats-hub-plugins.zip` da [última release do hub](https://github.com/altair-sossai/l4d2-playstats-hub/releases/latest) e copia a pasta `addons` dele por cima do servidor. `l4d2_gameinfo_sync` e `l4d2_weapon_skins` vão para `plugins/` (carregamento automático); os outros três vão para `plugins/optional/`.
- **Carregamento** — o `cfg/cfgogl/<mod>/shared_plugins.cfg` carrega os plugins, como antes.
- **Configurações que ficam aqui** — as ConVars de cada modo no `shared_cvars.cfg` (`ranking_show_motd_panel`, `patent_icon_*`, `gameinfo_*`, `weapon_skins_*`).
- **Endereço do site** — o `cfg/server.cfg` define `playstats_url "http://124.198.128.43:5000"` (HTTP simples, para o navegador do jogo também abrir), `playstats_public_url "https://l4d2.com.br"` (o endereço que os jogadores leem no chat) e `l4d2_web_url` (lido pelo plugin do anti-cheat).
- **Token** — fora do repositório. O pipeline grava o `cfg/playstats_token.cfg` a partir de uma variável secreta, e o `server.cfg` o executa.
- **Removidos** — as ConVars antigas `playstats_access_token` e `ranking_url`, e o `playstats_url` apontando para a API antiga do PlayStats.

O que cada plugin faz, as ConVars e os comandos: [Conectando um servidor de jogo](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/game-server.pt.md) e a [pasta de plugins](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/plugins/README.pt.md) do hub. Para jogadores e admins: [loja de skins](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/skin-shop.pt.md), [servidor ao vivo](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/live-server.pt.md), [patentes](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/patents.pt.md) e [páginas dentro do jogo](https://github.com/altair-sossai/l4d2-playstats-hub/blob/main/docs/manual/in-game-pages.pt.md).

---

# Plugins adaptados (terceiros)

## l4d2_mix (adaptado)

> **Não é obra original.** Este plugin foi criado por **Luckylock (LuckyServ)** — repositório original: <https://github.com/LuckyServ/>. A cópia neste repositório foi **modificada com correções e ajustes para este servidor** (integração com a fila, mensagens traduzidas/localizadas e ajustes de comportamento). Todo o crédito pelo plugin original é do seu autor.

**Fonte (versão deste servidor):** [`scripting/l4d2_mix.sp`](../../addons/sourcemod/scripting/l4d2_mix.sp) · **Versão:** 5.0.0

**O que faz** — Conduz um "mix": os jogadores votam para começar, todos são movidos para espectador, os capitães são escolhidos por votação e os capitães escolhem seus times por menus no jogo. Mensagens que os jogadores veem (com o prefixo *"Mix Manager:"*):

- Um mix só pode ser iniciado durante o ready-up de um novo jogo (placar 0–0), com os dois times cheios (*"Both teams must be full to start a mix."*).
- Qualquer um que esteja em um time pode usar `!mix` para votar pelo início. O progresso aparece conforme os votos chegam (*"{player} has voted to start a mix. (votes needed: {n})"*), e o mix começa quando votos suficientes são atingidos (*"Started by vote."*) ou quando um admin o inicia (*"Started by admin {name}."*). Depois de cada mix concluído, o próximo no mesmo ready-up precisa de `l4d2_mix_additional_players_after_mix` votos a mais.
- `!mix <captain1> <captain2>` propõe dois capitães (jogadores nos times, pelo nome ou começo do nome) e inicia uma votação de sim/não entre os jogadores nos times (*"{player} proposed {a} and {b} as captains."*); ela passa com mais da metade deles votando Sim (*"Captains approved!"*). Um admin que usa esse formato inicia o mix com esses capitães na hora.
- Proteções contra estados inválidos: *"Mix has already started."*, *"A mix cannot be started during a live round."*, *"You cannot start a mix as a spectator."*, *"Mix is not available in 1v1 matches."*
- Durante a escolha, os jogadores não podem entrar sozinhos em um time: *"You cannot join a team without being picked."*
- Se um jogador dos times sair durante o mix, ele é cancelado. Na primeira vez, o jogador é avisado de que abandonar de novo dá ban; na segunda vez (antes de o jogo começar) ele é banido por `l4d2_mix_abandon_ban_time` minutos.
- O `sm_kickspecs` fica bloqueado durante um mix e por `l4d2_mix_kickspecs_block_time` segundos depois que ele termina.
- Um admin pode pará-lo com `!stopmix` (*"Stopped by admin {name}."*); usar esse comando quando nada está em andamento retorna *"No mix is currently in progress."*

**Objetivo** — Oferecer uma escolha de times justa, baseada em capitães, para jogos pug/mix, conduzida pelos próprios jogadores e com possibilidade de intervenção de admin.

**ConVars**

| ConVar | Padrão | Descrição |
|--------|---------|-------------|
| `l4d2_mix_start_votes` | `2` | Número de votos necessários para iniciar um mix (1–8) |
| `l4d2_mix_additional_players_after_mix` | `2` | Jogadores extras que precisam votar depois de cada mix iniciado, antes de o jogo começar (`0` desativa) |
| `l4d2_mix_kickspecs_block_time` | `40` | Segundos depois do fim de um mix durante os quais o `sm_kickspecs` fica bloqueado (`0` desativa) |
| `l4d2_mix_abandon_ban_time` | `30` | Minutos de ban para um jogador que abandona um mix pela segunda vez (`0` desativa o ban) |
| `l4d2_mix_captain_vote_duration` | `20` | Segundos que a votação de proposta de capitães (`!mix <captain1> <captain2>`) fica aberta |

**Comandos**

| Comando | Acesso | Descrição |
|---------|--------|-------------|
| `sm_mix` | todos | Vota para iniciar um mix; um admin com `ADMFLAG_CHANGEMAP` o inicia na hora |
| `sm_mix <captain1> <captain2>` | todos | Propõe dois capitães e inicia uma votação entre os jogadores nos times; um admin inicia o mix com eles na hora |
| `sm_mix <captain>` | `ADMFLAG_CHANGEMAP` | Inicia o mix com esse jogador como primeiro capitão; o segundo capitão é votado normalmente |
| `sm_stopmix` | `ADMFLAG_CHANGEMAP` | Para o mix atual |

**Como configurar** — Defina as ConVars no `shared_cvars.cfg`, por exemplo `confogl_addcvar l4d2_mix_start_votes 2`.

---

## annoyance_exploit_fixes (adaptado)

> **Não é obra original.** Este plugin foi criado por **Sir** como parte do [SirPlease/L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework). A cópia neste repositório foi **modificada com uma correção para este servidor** (bloqueio do `bugpause`, veja abaixo). Todo o crédito pelo plugin original é do seu autor.

**Fonte (versão deste servidor):** [`scripting/annoyance_exploit_fixes.sp`](../../addons/sourcemod/scripting/annoyance_exploit_fixes.sp) · **Versão:** 0.2.1

**O que faz** — Uma coletânea de pequenas correções para comportamentos irritantes/exploráveis dos clientes. Originalmente: bloqueia uma votação enquanto uma nova votação ainda não é permitida (*"A vote can't be called right now, try again in {n}s!"*), bloqueia votações de kick que não miram um colega de time, bloqueia o auto-kick e (em jogos CEDAPug) bloqueia votações de voltar ao lobby/trocar de campanha no meio da partida. A cópia deste servidor também bloqueia por completo o comando nativo `bugpause` do cliente, sempre, para todos os clientes. O `bugpause` é disparado quando um jogador abre a janela "Report a Bug" embutida do L4D2 — um recurso antigo cujos relatórios a Valve não lê mais — e a engine transmite uma notificação no chat sem nenhum limite de frequência, então um jogador pode associar uma tecla a ele e inundar o chat de todos ([Valve issue #2765](https://github.com/ValveSoftware/Source-1-Games/issues/2765)). Como o recurso não serve mais para nada, o bloqueio é incondicional.

**Objetivo** — Fechar pequenas formas de os clientes atrapalharem ou irritarem outros jogadores, incluindo o flood de chat pelo `bugpause`.

**ConVars** — Nenhuma.

**Comandos** — Intercepta `callvote` e `bugpause` (nenhum comando novo registrado).

**Como configurar** — Não precisa de configuração; carregado para o servidor inteiro pelo [`cfg/generalfixes.cfg`](../../cfg/generalfixes.cfg) (`sm plugins load fixes/annoyance_exploit_fixes.smx`), independentemente de qual modo está ativo.
