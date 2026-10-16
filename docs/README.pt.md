# Documentação — l4d2-zone-server

🌐 [English](README.md) | **Português** | [Español](README.es.md)

Documentação escrita para este servidor. Nada nesta pasta é enviado para o servidor de jogo.

Todo documento existe em três idiomas e segue a mesma regra de nome: `nome.md` é o inglês (a versão que o GitHub abre por padrão), `nome.pt.md` é o português e `nome.es.md` é o espanhol. Cada um começa com links para os outros dois.

## Jogadores

| Documento | Idiomas |
|---|---|
| Guia de comandos para jogadores | [English](players/README.md) · [Português](players/README.pt.md) · [Español](players/README.es.md) |
| Corrigindo o problema de "UDP connect retry" | [English](tutorials/connect-fix/README.md) · [Português](tutorials/connect-fix/README.pt.md) · [Español](tutorials/connect-fix/README.es.md) |
| Changelog do servidor — 04/08/2026 | [English](changelog/2026-08-04.md) · [Português](changelog/2026-08-04.pt.md) · [Español](changelog/2026-08-04.es.md) |

## Admins

| Documento | Idiomas |
|---|---|
| Guia de comandos para admins | [English](admins/README.md) · [Português](admins/README.pt.md) · [Español](admins/README.es.md) |

## Plugins e sistemas

| Documento | Idiomas |
|---|---|
| Plugins customizados (objetivo, ConVars, comandos, configuração) | [English](plugins/README.md) · [Português](plugins/README.pt.md) · [Español](plugins/README.es.md) |
| Wiki das skins de armas e da loja de skins | [English](weapon-skins/README.md) · [Português](weapon-skins/README.pt.md) · [Español](weapon-skins/README.es.md) |

## Manutenção

| Documento | Idiomas |
|---|---|
| Compilando os plugins customizados | [English](maintenance/compile-custom-plugins.md) · [Português](maintenance/compile-custom-plugins.pt.md) · [Español](maintenance/compile-custom-plugins.es.md) |
| Configuração do servidor com Ansible | [English](maintenance/ansible.md) · [Português](maintenance/ansible.pt.md) · [Español](maintenance/ansible.es.md) |

## Estrutura

```
docs/
├── admins/           Guia de comandos para admins
├── changelog/        Changelogs do servidor
├── maintenance/      Compilar os plugins e configurar o servidor
├── players/          Guia de comandos para jogadores
├── plugins/          Referência dos plugins customizados
├── tutorials/        Guias passo a passo para jogadores
└── weapon-skins/     Wiki das skins de armas e da loja de skins
```
