# Clawd Companion 🦀

Um bichinho pixelado que mora em cima da sua barra de tarefas do Windows. Ele anda, pula nas suas janelas, tem emoções, conversa com você (usando o Claude Code), espia a tela, joga videogame junto, constrói casinhas na área de trabalho... e envelhece se você abandonar o PC.

> Projeto de fã, **não oficial**, sem nenhuma afiliação com a Anthropic.

## Instalação

**Jeito rápido:** abra o PowerShell e cole:

```powershell
irm https://raw.githubusercontent.com/JoaoVictorCoder/clawd-desktop-pet/main/install.ps1 | iex
```

**Ou:** baixe o projeto (botão verde *Code → Download ZIP*), extraia e dê dois cliques em `instalar.bat`.

O Clawd é instalado em `%LOCALAPPDATA%\Clawd`, ganha um atalho no menu Iniciar e passa a abrir junto com o Windows. Pra desinstalar, use o atalho **Desinstalar Clawd** no menu Iniciar.

### Requisitos

- Windows 10 ou 11. Não precisa instalar nada: ele usa o PowerShell que já vem no Windows.
- **Opcional:** [Claude Code](https://docs.claude.com/claude-code), com login feito, pra ele conversar e ver a tela:
  ```powershell
  winget install Anthropic.ClaudeCode
  claude
  ```
  Sem o Claude Code, ele funciona normalmente, só que usando falas prontas.

## O que ele faz

- **Anda e explora:** caminha pela barra de tarefas, pula em cima das janelas e anda por elas. Se você arrastar a janela, ele vai junto. Se você fechar a janela, ele cai.
- **Emoções:** fica feliz, apaixonado, triste, bravo, assustado, tonto, com sono... Tem energia e carência: dorme quando cansa e fica triste se você ignora ele.
- **Conversa:** dê dois cliques nele pra conversar. Ele lembra das conversas anteriores.
- **Espia a tela:** de vez em quando ele comenta o que você está fazendo (vídeo, código, jogo).
- **Atividades espontâneas:** pega um controle quando você está jogando, abre um notebook quando você está programando, pesca em cima das janelas, constrói casinhas de blocos, joga bola, toma café, lê um livro.
- **32 truques aleatórios:** bola de chiclete que estoura na cara, raio que deixa ele tostado, clone em cima da cabeça, jetpack, paraquedas do topo da tela, breakdance de ponta-cabeça, mágica do coelho, pintar um quadro, DJ, toc toc que racha a tela... Dá pra ver todos no menu **Truques** (ou **Surpresa!**).
- **Envelhece:** se o PC ficar parado, ele fica velhinho, morre, vira um fantasminha e uma lápide aparece. Quando você mexer no mouse, ele revive.
- **Some sozinho** quando algum app entra em tela cheia.

## Controles

| Ação | O que acontece |
|---|---|
| Clique | Cutuca ele (se exagerar, ele fica bravo e foge) |
| Dois cliques | Abre a conversa |
| Arrastar e soltar | Carrega ele. Soltando com força, arremessa |
| Passar o mouse em cima, de um lado pro outro | Carinho ❤️ |
| Botão direito | Menu: atividades, opções, sair |
| Clicar num bloco ou na bola | Quebra o bloco / chuta a bola |

## Personalizar

Tudo fica em `%LOCALAPPDATA%\Clawd`:

- `falas.json`: todas as falas dele. Pode editar à vontade.
- `persona.txt`: a personalidade usada nas conversas.
- `config.json`: é criado quando você muda alguma opção no menu. Por exemplo, `"morte_min": 10` são os minutos com o PC parado até ele morrer.

## Privacidade

- Quando você conversa com ele, ou quando ele espia a tela, ele manda **um print da janela ativa** e o título dela pro Claude, usando a sua conta do Claude Code. O print não é salvo em disco.
- Ele nunca espia janelas cujo título indique senhas, bancos ou abas anônimas. Mas esse filtro olha só o título, então não é garantido.
- Dá pra desligar isso no menu, desmarcando **Ver minha tela** e **Espiar e comentar sozinho**.
- As conversas ficam salvas só no seu PC, em `memoria.json`. Pra apagar, use **Esquecer conversas** no menu.

---

*English: a pixel desktop pet for Windows that walks on your taskbar, climbs windows, chats via Claude Code, reacts to what you're doing, and has spontaneous activities. Install with the PowerShell one-liner above. Unofficial fan project, not affiliated with Anthropic.*
