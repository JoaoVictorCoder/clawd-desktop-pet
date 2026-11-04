# Clawd Companion 🦀

Um bichinho pixelado que mora em cima da sua barra de tarefas do Windows. Ele anda, pula nas suas janelas, tem emoções, conversa com você (usando o Claude Code ou outra IA: ChatGPT, Gemini, Ollama...), espia a tela, joga videogame junto, constrói casinhas na área de trabalho... e envelhece se você abandonar o PC.

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
- **Ou** qualquer outra IA: veja [Usar outra IA](#usar-outra-ia).

## O que ele faz

- **Anda e explora:** caminha pela barra de tarefas, pula em cima das janelas e anda por elas. Se você arrastar a janela, ele vai junto. Se você fechar a janela, ele cai.
- **Emoções:** fica feliz, apaixonado, triste, bravo, assustado, tonto, com sono... Tem energia e carência: dorme quando cansa e fica triste se você ignora ele.
- **Conversa:** dê dois cliques nele pra conversar. Ele lembra das conversas anteriores.
- **Espia a tela:** de vez em quando ele comenta o que você está fazendo (vídeo, código, jogo).
- **Atividades espontâneas:** pega um controle quando você está jogando, abre um notebook quando você está programando, pesca em cima das janelas, constrói casinhas de blocos, joga bola, toma café, lê um livro.
- **32 truques aleatórios:** bola de chiclete que estoura na cara, raio que deixa ele tostado, clone em cima da cabeça, jetpack, paraquedas do topo da tela, breakdance de ponta-cabeça, mágica do coelho, pintar um quadro, DJ, toc toc que racha a tela... Dá pra ver todos no menu **Truques** (ou **Surpresa!**).
- **Envelhece:** se o PC ficar parado, ele fica velhinho, morre, vira um fantasminha e uma lápide aparece. Quando você mexer no mouse, ele revive.
- **Some sozinho** quando algum app entra em tela cheia.
- **Ícone na bandeja** (perto do relógio): clique pra chamar ele, dois cliques pra conversar, botão direito pro menu. Pelo menu dá pra esconder o Clawd sem fechar.
- **Se atualiza sozinho:** toda vez que abre, ele vê se tem versão nova aqui no GitHub e se atualiza. Sem internet, só abre normal. Dá pra procurar na hora em **Procurar atualização**, ou desligar em **Atualizar sozinho ao abrir**. Se você editou o `falas.json` ou o `persona.txt`, a sua versão é mantida.

## Controles

| Ação | O que acontece |
|---|---|
| Clique | Cutuca ele (se exagerar, ele fica bravo e foge) |
| Dois cliques | Abre a conversa |
| Arrastar e soltar | Carrega ele. Soltando com força, arremessa |
| Passar o mouse em cima, de um lado pro outro | Carinho ❤️ |
| Botão direito | Menu: atividades, opções, atualização, sair |
| Ícone na bandeja | Clique chama ele, dois cliques conversa, botão direito abre o menu |
| Clicar num bloco ou na bola | Quebra o bloco / chuta a bola |

## Personalizar

Tudo fica em `%LOCALAPPDATA%\Clawd`:

- `falas.json`: todas as falas dele. Pode editar à vontade.
- `persona.txt`: a personalidade usada nas conversas.
- `config.json`: é criado quando você muda alguma opção no menu. Por exemplo, `"morte_min": 10` são os minutos com o PC parado até ele morrer, e `"atualizar": false` desliga a atualização automática.

## Usar outra IA

Por padrão ele usa o Claude Code. Pra usar outra IA, crie (ou edite) o `config.json` em `%LOCALAPPDATA%\Clawd` e reinicie o Clawd:

```json
{
  "ia": "gemini",
  "ia_chave": "SUA_CHAVE_AQUI"
}
```

| `ia` | O que é | Precisa de chave? |
|---|---|---|
| `claude` | Claude Code (padrão) | Não, usa o login do Claude Code |
| `openai` | ChatGPT / OpenAI | Sim (ou variável `OPENAI_API_KEY`) |
| `gemini` | Google Gemini | Sim (ou `GEMINI_API_KEY`) |
| `ollama` | IA rodando no seu PC, de graça, com [Ollama](https://ollama.com) | Não |
| `lmstudio` | IA rodando no seu PC com [LM Studio](https://lmstudio.ai) | Não |
| `openrouter` | Centenas de modelos com uma chave só | Sim (ou `OPENROUTER_API_KEY`) |
| `groq` | Groq | Sim (ou `GROQ_API_KEY`) |
| `deepseek` | DeepSeek (não vê a tela) | Sim (ou `DEEPSEEK_API_KEY`) |

Opções extras:

- `"ia_modelo"`: troca o modelo. Ex.: `"gpt-4.1-mini"`, `"gemini-2.5-flash"`, `"llama3.2-vision"`.
- `"ia_url"`: qualquer outra API compatível com a da OpenAI (termina em `/v1`). Ex.: `{ "ia": "outra", "ia_url": "http://localhost:8080/v1", "ia_modelo": "meu-modelo" }`.
- `"ia_imagem": false`: pra modelos que não aceitam imagem. Ele continua conversando, só não vê a tela nem espia sozinho.

Com o Ollama, por exemplo: instale, rode `ollama pull gemma3` e use `{ "ia": "ollama" }`. Se algo der errado, o motivo fica em `clawd.log`.

## Privacidade

- Quando você conversa com ele, ou quando ele espia a tela, ele manda **um print da janela ativa** e o título dela pra IA escolhida (por padrão o Claude, usando a sua conta do Claude Code). Com Ollama ou LM Studio, nada sai do seu PC. O print não é salvo em disco.
- Ele nunca espia janelas cujo título indique senhas, bancos ou abas anônimas. Mas esse filtro olha só o título, então não é garantido.
- Dá pra desligar isso no menu, desmarcando **Ver minha tela** e **Espiar e comentar sozinho**.
- As conversas ficam salvas só no seu PC, em `memoria.json`. Pra apagar, use **Esquecer conversas** no menu.

---

*English: a pixel desktop pet for Windows that walks on your taskbar, climbs windows, chats via Claude Code or any OpenAI-compatible API (OpenAI, Gemini, Ollama...), reacts to what you're doing, and has spontaneous activities. Install with the PowerShell one-liner above. Unofficial fan project, not affiliated with Anthropic.*
