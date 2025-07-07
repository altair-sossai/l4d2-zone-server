# <img src="https://cdn.jsdelivr.net/gh/hjnilsson/country-flags/svg/br.svg" width="40"/> Left 4 Dead 2 — Correção para o Erro de Conexão UDP Connect Retry

- [<img src="https://cdn.jsdelivr.net/gh/hjnilsson/country-flags/svg/us.svg" width="20"/> README in English](./L4D2_CONNECT_FIX.en.md)
- [<img src="https://cdn.jsdelivr.net/gh/hjnilsson/country-flags/svg/es.svg" width="20"/> README en Español](./L4D2_CONNECT_FIX.es.md)

Se você estiver recebendo o seguinte erro ao tentar conectar no servidor:

```
Retrying public(181.214.221.198:27015)
Sending UDP connect to public IP 181.214.221.198:27015
```

<p align="center">
  <img src="/tutorials/assets/connection-failed.jpg?raw=true" alt="Falha na conexão após 30 tentativas"/>
</p>

Siga os passos abaixo para corrigir:

## ✅ Solução

1. **Feche o jogo.**
2. **Abra a Steam**, clique com o botão direito no **Left 4 Dead 2** na sua Biblioteca e selecione **Propriedades**.

<p align="center">
  <img src="/tutorials/assets/l4d2-properties.png?raw=true" alt="Propriedades do Left 4 Dead 2"/>
</p>

3. Em **Opções de Inicialização**, adicione o seguinte parâmetro:

   ```
   +clientport 27666
   ```

<p align="center">
  <img src="/tutorials/assets/l4d2-launch-options.png?raw=true" alt="Opções de inicialização do Left 4 Dead 2"/>
</p>

* `27666` pode ser qualquer número **no intervalo de 27005–27032**.
* Se ainda tiver problemas de conexão, tente mudar a porta — às vezes isso resolve conflitos com outros aplicativos.

## ✅ Observação Importante

Para que as opções de inicialização funcionem corretamente, **sempre inicie o jogo pela Steam**.

Se você abrir o jogo por um **atalho na Área de Trabalho**, é necessário adicionar os mesmos parâmetros de inicialização nas propriedades do atalho:

1. Clique com o botão direito no **atalho do jogo** e selecione **Propriedades**.
2. No campo **Destino**, adicione os parâmetros **após as aspas**, por exemplo:  

```
"E:\Steam\steamapps\common\Left 4 Dead 2\left4dead2.exe" -console +clientport 27666
```

## ⚙️ Exemplo de Opções de Inicialização

Veja um exemplo das minhas Opções de Inicialização:

```
-lv +precache_all_survivors 1 -novid -console -nojoy -noforcemaccel -noforcemparms -noforcemspd +clientport 27666
```

### O que significa cada parâmetro?

* `-lv` — Ativa o modo de baixa violência (pode reduzir os efeitos de sangue).
* `+precache_all_survivors 1` — Pré-carrega todos os modelos dos sobreviventes para evitar travamentos ao trocar de personagem.
* `-novid` — Pula o vídeo de introdução.
* `-console` — Ativa o console de desenvolvedor na inicialização.
* `-nojoy` — Desativa suporte a joystick (libera recursos do sistema).
* `-noforcemaccel`, `-noforcemparms`, `-noforcemspd` — Garantem que as configurações do mouse não sejam sobrescritas pelo jogo.
* `+clientport 27666` — Força o jogo a usar uma porta local específica para evitar conflitos de conexão.

---

## 📞 Precisa de ajuda?

Se o problema persistir, entre em contato: [https://steamcommunity.com/id/altairsossai/](https://steamcommunity.com/id/altairsossai/)

Boa sorte e bom jogo!