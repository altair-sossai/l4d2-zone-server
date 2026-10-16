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
| `!unpause` / `!ready` / `!r` | Marca seu time como pronto para voltar. O jogo volta quando os dois times estiverem prontos |
| `!unready` / `!nr` | Marca seu time como não pronto para voltar |
| `!toggleready` | Alterna seu time entre pronto e não pronto para voltar |

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

> **Sobre o mix:** os dois times precisam estar cheios e o mix só começa no início de um jogo novo (0 x 0). Os capitães precisam estar jogando (não em spectator). Não existe mix em 1v1. Se alguém sair durante o mix, o mix é cancelado; quem fizer isso pela segunda vez é **banido por 60 minutos**.

> **Sobre a fila (`!vaga`):**
> - **Antes do jogo começar (0 x 0):** se você está à frente na fila de alguém que está jogando, o `!vaga` coloca você no lugar dessa pessoa, e ela vai para spectator.
> - **Com o jogo em andamento:** só quem estava nos times do começo da partida pode usar `!vaga`, para voltar ao seu time no lugar de um substituto. Se o substituto estiver controlando o Tank, espere o Tank morrer.
> - O `!vaga` não funciona com mix em andamento nem com o seu lerp inválido.
> - Quando abre uma vaga, o servidor avisa o próximo da fila para digitar `!vaga`.

> **Tank vivo:** survivors não conseguem ir para spectator enquanto o Tank estiver vivo. Se precisar mesmo trocar, use `!pause`.

---

## Votações

| Comando | O que faz |
|---|---|
| `!match` / `!match <config>` | Abre votação para carregar uma config. Sem a config, abre um menu para escolher. Ex.: `!match zonemod` |
| `!chmatch <config>` | Abre votação para trocar para outra config |
| `!rmatch` | Abre votação para desligar a config atual |
| `!votecamp` / `!votecampaign` | Abre um menu para votar na troca de campanha (oficiais e customizadas) |
| `!voteboss <tank> <witch>` | Vota para mudar a porcentagem de spawn do Tank e da Witch (só no ready-up do primeiro round do mapa). `0` = não aparece, `-1` = mantém a atual |
| `!setscores <survivors> <infected>` | Abre votação para mudar o placar da partida (só quem está em um time) |
| `!slots <número>` | Abre votação para mudar a quantidade de vagas do servidor. Ex.: `!slots 10` |

Configs principais: `zonemod` (4v4), `zm3v3`, `zm2v2`, `zm1v1`, `zonehunters`, `zoneretro`. O `!match` sem config abre um menu com todas as configs instaladas no servidor.

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

## Skins de armas

| Comando | O que faz |
|---|---|
| `!skin` / `!skins` | Mostra a ajuda das skins e o link da loja de skins |
| `!skin <id>` / `!skins <id>` | Usa uma das suas skins. Ex.: `!skin hellsing-gold` |
| `!skin next [arma]` / `!skin prev [arma]` | Passa pelas skins que você tem para aquela arma. Depois da última, volta para a skin padrão |
| `!skin default [arma]` | Volta para a skin padrão |
| `!skin status` | Mostra se as skins estão ligadas, quantas estrelas você tem e quantas skins você tem |

`[arma]` é opcional. Sem ela, o comando usa a arma que está na sua mão (ou a sua arma principal e depois a secundária: arma branca ou Magnum). Valores: `smg`, `mac`, `mp5`, `pump`, `chrome`, `magnum` (ou `deagle`), `axe`, `katana`, `machete`, `bat`, `cricket`, `guitar`, `crowbar`, `golf`, `pan`.

Exemplos:

```
!skin hellsing-gold     -> usa a skin hellsing-gold
!skin next              -> próxima skin da arma na sua mão
!skin next pump         -> próxima skin da pump
!skin next magnum       -> próxima skin da Magnum
!skin default chrome    -> volta a chrome para a skin padrão
```

> **Sobre as skins:**
> - Existem skins para a SMG, MAC-10 (SMG com silenciador), MP5, pump, chrome, Magnum (Desert Eagle) e as armas brancas (machado, katana, facão, taco de beisebol, taco de críquete, guitarra, pé de cabra, taco de golfe e frigideira).
> - **Compra:** as skins são compradas na loja em [l4d2.com.br/skins](https://l4d2.com.br/skins) (entre com a Steam) usando **estrelas**: cada MVP de dano em SI e cada MVP de comuns em partidas competitivas vale 1 estrela. Conta todo o seu histórico, desde o início do ranking.
> - **Quando aparece:** a skin comprada já fica **equipada** e aparece no servidor **a partir da próxima troca de mapa**, porque os arquivos dela são enviados para todos quando o mapa carrega. Também dá para equipar uma skin ou voltar para a skin padrão pelo site; essa mudança também aparece a partir da próxima troca de mapa.
> - **Quanto tempo dura:** a skin comprada dura até o **reset do ranking** (a cada 2 meses). No reset ela é reembolsada automaticamente e as estrelas voltam para você, então dá para comprar de novo. Skins recebidas de **presente** ficam para sempre.
> - **Trocar no jogo:** `!skin <id>`, `!skin next`, `!skin prev` e `!skin default` só funcionam quando você é **survivor** e durante o **ready-up**, em qualquer mapa. Sua escolha fica salva e é carregada na próxima vez que você jogar.
> - A skin acompanha a arma: se você largar a arma, quem pegar usa com a sua skin.

> **Os downloads precisam estar ligados:** os arquivos das skins são enviados quando o mapa carrega, então quem estiver com os downloads desligados é expulso. A mensagem de expulsão diz qual configuração está errada e o comando de console que corrige:
> - `cl_allowdownload` está em `0`: digite `cl_allowdownload 1`
> - `cl_downloadfilter` está em `mapsonly` ou `none`: digite `cl_downloadfilter all`
>
> Depois, conecte de novo. A opção do menu **Opções > Multijogador > Conteúdo personalizado do servidor > Permitir tudo** só muda o `cl_downloadfilter`, então se a mensagem falar do `cl_allowdownload`, use o console. Se continuar acontecendo, confira essa configuração no seu `autoexec.cfg` ou `config.cfg`.

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
- **Lerp:** se o seu lerp estiver fora do permitido, você não consegue pegar vaga com `!vaga`, e o servidor mostra os comandos para corrigir. Cole no seu console:

```
cl_interp 0; cl_interp_ratio 0; rate 100000; cl_cmdrate 100; cl_updaterate 100
```

Precisa de ajuda? Fale com um admin no servidor.
