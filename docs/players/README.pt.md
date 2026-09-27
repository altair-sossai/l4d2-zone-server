# Guia de Comandos para Jogadores

🌐 [English](README.md) | **Português** | [Español](README.es.md)

Tudo o que você pode digitar no chat do servidor, separado pelo que você quer fazer.

---

## Como usar os comandos

| Forma | Exemplo | Observação |
|---|---|---|
| Chat com `!` | `!ready` | O comando aparece no chat para todos |
| Chat com `/` | `/ready` | Fica **silencioso**, só você vê a resposta |
| Console (`~`) | `sm_ready` | Troque o `!` por `sm_` |

**O que significam `< >` e `[ ]`**

Nos comandos deste guia, `< >` e `[ ]` só indicam o que você deve escrever ali. **Não digite os símbolos**, troque tudo pelo valor:

| No guia | Significa | Você digita |
|---|---|---|
| `!mix <capitão1> <capitão2>` | `< >` = obrigatório | `!mix vorkyss Feeh` |
| `!roll [número]` | `[ ]` = opcional, pode deixar sem | `!roll` ou `!roll 20` |

❌ Errado: `!mix <vorkyss> <Feeh>`

✅ Certo: `!mix vorkyss Feeh`

**Nome com espaço:** coloque o nome entre aspas `" "`. Sem aspas, o jogo entende cada palavra como uma parte separada do comando.

❌ Errado: `!mix (LoD) Adeilson Feeh`

✅ Certo: `!mix "(LoD) Adeilson" Feeh`

---

## Ready-up (antes do round começar)

| Comando | O que faz |
|---|---|
| `!ready` / `!r` | Marca você como pronto. O round começa quando todos estiverem prontos |
| `!unready` / `!nr` | Tira o seu pronto |
| `!toggleready` | Alterna entre pronto e não pronto |
| `!hide` / `!show` | Esconde ou mostra o painel do ready-up (útil para ver outros menus) |
| `!return` | Leva você de volta para o saferoom se ficar preso durante o ready-up |

## Pausa

| Comando | O que faz |
|---|---|
| `!pause` | Pausa o jogo |
| `!unpause` / `!ready` | Marca seu time como pronto para voltar. O jogo volta quando os dois times estiverem prontos |
| `!unready` / `!nr` | Marca seu time como não pronto para voltar |

> Se um jogador cair ou desconectar com o round valendo, o jogo pode pausar sozinho. Quando ele voltar, use `!unpause` / `!ready` para continuar.

---

## Times e fila

| Comando | O que faz |
|---|---|
| `!spec` / `!s` | Vai para spectator |
| `!fila` / `!queue` | Mostra a fila de espera em ordem |
| `!vaga` / `!slot` | Pega uma vaga no jogo se for a sua vez na fila |
| `!mix` | Vota para começar um mix. Quando tiver votos suficientes, todos votam nos capitães, e os capitães escolhem os times por um menu |
| `!mix <capitão1> <capitão2>` | Abre uma votação propondo dois capitães: `capitão1` nos survivors e `capitão2` nos infected. Se a maioria votar **sim**, o mix começa com eles |
| `!teamflip` / `!tf` | Sorteia um time (Survivor ou Infected) para você, mostrando para todos |
| `!kickspecs` | Abre votação para expulsar os spectators |

Exemplos:

```
!mix                           -> vota para começar um mix
!mix vorkyss Feeh              -> propõe vorkyss e Feeh como capitães
!mix "(LoD) Adeilson" Feeh     -> use aspas quando o nome tiver espaço ou símbolos
```

> **Sobre o mix:** os dois times precisam estar cheios e o mix só começa no início de um jogo novo (0 x 0). Os capitães precisam estar jogando (não em spectator). Não existe mix em 1v1. Se alguém sair durante o mix, o mix é cancelado; quem fizer isso pela segunda vez é **banido por 30 minutos**.

> **Sobre a fila:** só dá para pegar vaga no começo de um jogo novo e quando não tem mix rolando. Quando abre uma vaga, o servidor avisa o próximo da fila para digitar `!vaga`.

> **Tank vivo:** survivors não conseguem ir para spectator enquanto o Tank estiver vivo. Se precisar mesmo trocar, use `!pause`.

---

## Votações

| Comando | O que faz |
|---|---|
| `!match` / `!match <config>` | Abre votação para carregar uma config. Sem a config, abre um menu para escolher. Ex.: `!match zonemod` |
| `!chmatch <config>` | Abre votação para trocar para outra config |
| `!rmatch` | Abre votação para desligar a config atual |
| `!votecamp` / `!votecampaign` | Abre um menu para votar na troca de campanha (oficiais e customizadas) |
| `!voteboss <tank> <witch>` | Vota para mudar a porcentagem de spawn do Tank e da Witch (só no ready-up). `0` = não aparece, `-1` = mantém a atual |
| `!setscores <survivors> <infected>` | Abre votação para mudar o placar da partida (só quem está em um time) |
| `!slots <número>` | Abre votação para mudar a quantidade de vagas do servidor. Ex.: `!slots 10` |

Configs disponíveis: `zonemod` (4v4), `zm3v3`, `zm2v2`, `zm1v1`, `zonehunters`, `zoneretro`.

---

## Informações da partida

| Comando | O que faz |
|---|---|
| `!boss` / `!tank` / `!witch` | Mostra onde o Tank e a Witch vão aparecer (%) e quem vai ser o Tank |
| `!cur` / `!current` | Mostra quanto os survivors já andaram no mapa (%) |
| `!health` / `!bonus` / `!damage` | Mostra o bônus atual dos survivors |
| `!mapinfo` | Mostra os valores de distância e bônus do mapa |
| `!cfg` / `!changelog` | Mostra o que a config atual muda no jogo |
| `!lerps` | Lista o lerp de todos os jogadores |
| `!rates` | Lista as configurações de rede de todos os jogadores |

## Estatísticas e ranking

| Comando | O que faz |
|---|---|
| `!stats` | Estatísticas dos survivors no round. Digite `!stats help` para ver todas as opções |
| `!mvp` | MVP dos survivors no round |
| `!mvpme` | Suas estatísticas de MVP |
| `!skill` | Estatísticas de habilidade (skeets, levels, crowns...) |
| `!ff` | Estatísticas de fogo amigo |
| `!acc` | Estatísticas de precisão |
| `!stats_auto <flags>` | Escolhe quais estatísticas aparecem automaticamente no fim do round. `-1` = nenhuma, `0` = padrão do servidor. Digite `!stats_auto help` para detalhes |
| `!ranking` | Mostra sua posição no ranking do servidor |

---

## Spectators

| Comando | O que faz |
|---|---|
| `!hear` | Escolhe de quem você ouve a voz: survivors, infected, só spectators ou todos. Ex.: `!hear survivors` |
| `!spechud` | Mostra ou esconde o HUD de spectator |
| `!tankhud` | Mostra ou esconde o HUD do Tank |
| `!cast` | Registra você como caster (só para casters autorizados) |
| `!notcasting` / `!uncast` | Tira você dos casters |

---

## Dentro do jogo

### Infected

| Comando | O que faz |
|---|---|
| `!warp <1-4>` / `!warp <nome>` | No modo fantasma (ghost), teleporta você até um survivor |

### Arremesso de pedra do Tank

| Comando | Tecla | Arremesso |
|---|---|---|
| `!overhand` | Reload | Por cima, com as duas mãos |
| `!underhand` | Use | Por baixo |
| `!overonehand` | M2 | Por cima, com uma mão |

### Survivors

| Comando | O que faz |
|---|---|
| `!secondary` | Liga/desliga a troca automática para a arma melee quando você pega uma |

---

## Diversão

| Comando | O que faz |
|---|---|
| `!coinflip` / `!cf` / `!flip` | Joga uma moeda (cara ou coroa) |
| `!roll [número]` / `!picknumber [número]` | Rola um dado. Ex.: `!roll 20` |

---

## Regras do servidor

- **Fogo amigo:** quem ficar dando dano no próprio time é expulso automaticamente, e o jogo é pausado.
- **AFK:** durante o ready-up, quem ficar AFK por muito tempo vai para spectator quando tiver alguém esperando para jogar.
- **Lerp:** se o seu lerp estiver fora do permitido, o servidor mostra os comandos para corrigir. Cole no seu console:

```
cl_interp 0; cl_interp_ratio 0; rate 100000; cl_cmdrate 100; cl_updaterate 100
```

Precisa de ajuda? Fale com um admin no servidor.
