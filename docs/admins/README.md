# Guia de Comandos para Admins

Guia rápido dos comandos de admin do servidor. Os primeiros comandos são os mais usados no dia a dia; quanto mais para o fim, menos você vai precisar deles.

> Os comandos que qualquer jogador pode usar estão no [Guia de Comandos para Jogadores](../players/README.pt.md).

---

## Como usar os comandos

| Forma | Exemplo | Observação |
|---|---|---|
| Chat com `!` | `!swap Miosha` | O comando aparece no chat para todos |
| Chat com `/` | `/swap Miosha` | O comando fica **silencioso**, só você vê a resposta |
| Console (`~`) | `sm_swap Miosha` | Troque o `!` por `sm_` |

**Como escolher o alvo (`<alvo>`)**

- **Parte do nome:** `!swap mio` funciona se só um jogador tiver "mio" no nome.
- **`#userid`:** digite `status` no console para ver o número de cada jogador e use `!kick #12`. É o jeito mais seguro quando o nome tem caracteres estranhos ou é parecido com outro.
- **Grupos:** `@all` (todos), `@humans` (só humanos), `@bots` (só bots), `@me` (você mesmo), `@aim` (quem está na sua mira).

> 💡 Na dúvida, abra o menu com **`!admin`**. Quase tudo que está aqui (kick, ban, mute, trocar mapa, trocar de time) também dá para fazer por ele, sem digitar nada.

---

## Menu de admin

| Comando | O que faz |
|---|---|
| `!admin` | Abre o menu de admin (jogadores, votações, mapas, comandos do servidor) |

## Config da partida (ZoneMod)

| Comando | O que faz |
|---|---|
| `!forcematch <config> [mapa]` / `!fm <config> [mapa]` | Carrega a config competitiva. Se passar um mapa, a config já carrega nele. **Use `!fm zonemod` sempre que o servidor estiver sem config** |
| `!resetmatch` | Desliga a config atual e volta o servidor ao modo padrão |
| `!forcechangematch <config> [mapa]` / `!fchmatch <config> [mapa]` | Troca para outra config sem precisar desligar a atual |

Exemplos:

```
!fm zonemod               -> carrega o ZoneMod no mapa atual
!fm zonemod c2m1_highway  -> carrega o ZoneMod já em Dark Carnival
!fchmatch zm3v3           -> troca para o ZoneMod 3v3
```

Configs mais usadas: `zonemod` (4v4), `zm3v3`, `zm2v2`, `zm1v1`, `zonehunters`, `zoneretro`.

## Ready-up e pausa

| Comando | O que faz |
|---|---|
| `!forcestart` / `!fs` | Começa o round sem esperar todo mundo dar `!ready`. Com o jogo pausado, também despausa |
| `!forcepause` | Pausa o jogo. **Só um admin consegue despausar** uma pausa feita assim |
| `!forceunpause` | Despausa na hora, sem esperar os times darem ready |

> Use `!forcepause` quando precisar resolver algo (troca de jogador, alguém travado, discussão). Os jogadores não conseguem despausar até você usar `!forceunpause`.

## Times

| Comando | O que faz |
|---|---|
| `!swap <jogador1> [jogador2] ...` | Manda os jogadores listados para o time oposto |
| `!swapto <time> <jogador1> [jogador2] ...` | Manda os jogadores para um time específico: `1` = spectator, `2` = survivors, `3` = infected |
| `!swapto force <time> <jogador>` | Igual ao anterior, mas força a troca mesmo se o time estiver cheio |
| `!swapteams` | Inverte os dois times inteiros (survivors ↔ infected) |
| `!fixbots` | Cria os bots de survivor que estiverem faltando (quando o time fica com menos de 4) |

Exemplos:

```
!swapto 1 Zenk            -> manda Zenk para spectator
!swapto 2 Guigo Vegueta   -> manda os dois para survivors
!swap #12                 -> manda o jogador #12 para o time oposto
```

## Mix

| Comando | O que faz |
|---|---|
| `!mix` | Começa o mix **na hora**, sem votação. Os dois capitães são escolhidos por votação dos jogadores |
| `!mix <capitão1>` | Começa o mix na hora com `capitão1` como capitão dos survivors. O segundo capitão é escolhido por votação |
| `!mix <capitão1> <capitão2>` | Começa o mix na hora com os dois capitães definidos: `capitão1` nos survivors e `capitão2` nos infected |
| `!stopmix` | Cancela o mix em andamento (por exemplo, se um capitão saiu ou travou a escolha) |

Exemplos:

```
!mix                            -> começa o mix e os jogadores votam nos capitães
!mix vorkyss                    -> vorkyss é capitão, o outro sai por votação
!mix vorkyss Feeh               -> vorkyss e Feeh são os capitães
!mix "(LoD) Adeilson" Feeh      -> use aspas quando o nome tiver espaço ou símbolos
```

> - Os capitães precisam estar **jogando** (em survivors ou infected), não em spectator.
> - Pode usar o nome completo ou só o começo do nome.
> - Os dois times precisam estar **cheios** e o mix só pode começar no **início de um jogo novo** (placar 0 x 0).
> - Não existe mix em 1v1.
> - Se alguém sair do servidor durante o mix, o mix é cancelado. Na primeira vez a pessoa só leva um aviso; se sair de novo, é **banida por 30 minutos**.

## Moderação: kick, ban e mute

| Comando | O que faz |
|---|---|
| `!kick <alvo> [motivo]` | Expulsa o jogador do servidor |
| `!ban <alvo> <minutos> [motivo]` | Bane um jogador que **está no servidor**. `0` = permanente |
| `!addban <minutos> <SteamID> [motivo]` | Bane um jogador que **já saiu** do servidor, usando a SteamID |
| `!unban <SteamID>` | Remove o ban |
| `!mute <alvo>` / `!unmute <alvo>` | Bloqueia ou libera a **voz** do jogador |
| `!gag <alvo>` / `!ungag <alvo>` | Bloqueia ou libera o **chat de texto** do jogador |
| `!silence <alvo>` / `!unsilence <alvo>` | Bloqueia ou libera **voz e chat** ao mesmo tempo |

Exemplos:

```
!ban #12 60 xingando no chat
!ban #7 0 trapaça
!addban 1440 STEAM_1:0:12345678 saiu antes do ban
!unban STEAM_1:0:12345678
```

> ⚠️ Mute, gag e silence duram **até o jogador sair do servidor**. Se o problema continuar, use kick ou ban.
>
> ⚠️ Nos motivos de ban, escreva **só o motivo**. Nunca coloque IP ou dados pessoais do jogador.

## Mapa

| Comando | O que faz |
|---|---|
| `!map <mapa>` | Troca o mapa na hora. Ex.: `!map c2m1_highway` |

---

## Tank e Witch

| Comando | O que faz |
|---|---|
| `!givetank <jogador>` | Define quem vai ser o próximo Tank. O jogador precisa estar no time **infected** |
| `!tankshuffle` | Sorteia de novo quem vai ser o Tank |
| `!ftank <porcentagem>` | Força a porcentagem de spawn do Tank. **Só funciona durante o ready-up** |
| `!fwitch <porcentagem>` | Força a porcentagem de spawn da Witch. **Só funciona durante o ready-up** |

> Os jogadores também podem pedir isso por votação com `!voteboss <tank> <witch>`. O `!ftank`/`!fwitch` pula a votação.

## Placar e campanha

| Comando | O que faz |
|---|---|
| `!setscores <survivors> <infected>` | Abre uma votação para ajustar o placar. Admin pode iniciar mesmo estando de spectator |
| `!setnextcampaign` | Abre um menu para escolher a(s) próxima(s) campanha(s) da rotação, ou limpar a lista |

> Útil quando o servidor caiu no meio da partida e vocês precisam voltar com o placar certo.

## Ajudas durante a partida

| Comando | O que faz |
|---|---|
| `!hp [quantidade]` | Recupera a vida de todos os survivors vivos (padrão: 100) |
| `!give_starting_items` | Entrega de novo os itens iniciais para os survivors |

## Spectators e casters

| Comando | O que faz |
|---|---|
| `!caster <jogador>` | Registra o jogador como caster (narrador) |
| `!notcasting <jogador>` | Tira o jogador da lista de casters |
| `!resetcasters` | Limpa todos os casters registrados |
| `!kickspecs` | Expulsa os spectators **na hora**, sem votação (casters e admins não são expulsos) |
| `!broadcast` | Liga/desliga o modo "falar com todos": enquanto ligado, **todo mundo ouve sua voz**, inclusive os dois times |

> Use `!broadcast` para dar um aviso rápido por voz aos dois times. Lembre de desligar depois.

## Moderação geral

| Comando | O que faz |
|---|---|
| `!slay <alvo>` | Mata o jogador |
| `!rename <alvo> <novo nome>` | Troca o nome do jogador |
| `!who` | Mostra os jogadores conectados e quem é admin |
| `!votekick <alvo>` | Abre votação para expulsar o jogador |
| `!voteban <alvo>` | Abre votação para banir o jogador |
| `!votemap <mapa>` | Abre votação para trocar de mapa |

## Mensagens de admin

| Comando | O que faz |
|---|---|
| `!say <mensagem>` | Mensagem para todos no chat, com destaque de admin |
| `!csay <mensagem>` | Mensagem no **centro da tela** de todos |
| `!hsay <mensagem>` | Mensagem na caixa de dica (hint) de todos |
| `!psay <alvo> <mensagem>` | Mensagem privada para um jogador |
| `!chat <mensagem>` | Mensagem que **só os admins** veem |

> Atalho: no chat do time (`say_team`), comece a mensagem com `@` para falar só com os admins. Ex.: `@alguém pode ajudar aqui?`

## Servidor

| Comando | O que faz |
|---|---|
| `!slots <número>` | Muda a quantidade de vagas do servidor **na hora**, sem votação. Ex.: `!slots 10` |
| `!killlobbyres` | Remove a reserva de lobby do servidor (libera a entrada de quem não veio pelo lobby) |

---

## Comandos avançados

| Comando | O que faz |
|---|---|
| `!cvar <cvar> [valor]` | Mostra ou altera uma cvar do servidor |
| `!rcon <comando>` | Executa um comando direto no console do servidor |
| `!exec <arquivo>` | Executa um arquivo `.cfg` do servidor |
| `!reloadadmins` | Recarrega a lista de admins (depois de alguém ser adicionado) |
| `!listcampaigns` | Lista no console todas as campanhas instaladas |
| `!refreshcampaigns` | Atualiza a lista de campanhas do `!votecamp` |
| `!add_caster_id <SteamID>` | Adiciona a SteamID à lista de quem pode se registrar sozinho como caster (`!cast`) |
| `!remove_caster_id <SteamID>` | Remove a SteamID dessa lista |
| `!printcasters` | Mostra a lista de SteamIDs de casters |
| `statsreset` | **Só pelo console.** Zera as estatísticas da partida atual (`!stats`, `!mvp`) |

> ⚠️ Cuidado com `!cvar`, `!rcon` e `!exec`: dá para quebrar a config da partida. Se algo ficar estranho, `!resetmatch` e depois `!forcematch zonemod` resolve.

---

## Testes e debug (não use em partida)

Estes comandos existem, mas servem para **testes, debug ou diversão**. Usar em partida valendo estraga o jogo.

### Comandos de diversão e testes

| Comando | O que faz |
|---|---|
| `!cchelp` | Lista todos os comandos de testes disponíveis |
| `!godmode <alvo>` | Deixa o jogador imortal |
| `!teleport <alvo>` | Teleporta o jogador para onde você está mirando |
| `!revive <alvo>` | Levanta um survivor caído |
| `!sethpplayer <alvo> <vida>` | Define a vida do jogador |
| `!speedplayer <alvo> <velocidade>` | Muda a velocidade do jogador |
| `!panic` | Força um evento de horda |
| `!slap`, `!burn`, `!freeze`, `!beacon`, `!noclip`, `!timebomb` | Comandos de diversão: tapa, fogo, congelar, sinalizar, atravessar paredes, bomba |

### Manutenção e debug

| Comando | O que faz |
|---|---|
| `!crash` | **Derruba o servidor** para ele reiniciar. Todos são desconectados. Só use se o servidor estiver quebrado e ninguém estiver jogando |
| `!early_victory_debug` | Mostra os valores internos da vitória antecipada |
| `!tank_witch_debug_info` | Mostra informações internas de spawn do Tank e da Witch |

---

## Situações comuns

**Servidor sem config / jogo em modo padrão**
1. `!forcematch zonemod`

**Jogador caiu no meio do round**
1. `!forcepause`
2. Espere ele voltar, ou traga alguém da fila com `!swapto <time> <jogador>`
3. `!forceunpause`

**Times desbalanceados ou jogador no time errado**
1. `!swapto 1 <jogador>` para mandar para spectator
2. `!swapto 2 <jogador>` ou `!swapto 3 <jogador>` para colocar no time certo
3. Se faltar survivor, `!fixbots`

**Mix travado (capitão saiu ou não escolhe)**
1. `!stopmix`
2. Comece outro com `!mix`, ou já defina os capitães com `!mix <capitão1> <capitão2>`

**Servidor caiu e a partida voltou zerada**
1. `!forcematch zonemod`
2. `!setscores <survivors> <infected>` com o placar de antes e peça para os jogadores votarem **sim**

**Jogador tóxico**
1. `!gag` / `!mute` / `!silence` para parar na hora
2. Se continuar: `!kick <alvo> <motivo>`
3. Se for grave ou reincidente: `!ban <alvo> <minutos> <motivo>`
