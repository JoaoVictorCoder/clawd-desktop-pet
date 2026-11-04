# Clawd Companion 🦀

Um bichinho pixelado que mora em cima da sua barra de tarefas. Ele anda, tem emoções, conversa com você (usando o Claude Code ou outra IA: ChatGPT, Gemini, Ollama...), espia a tela, faz 32 truques... e envelhece se você abandonar o PC. Roda no **Windows, Mac e Linux**.

> Projeto de fã, **não oficial**, sem nenhuma afiliação com a Anthropic.

## Instalação

Baixe o instalador do seu sistema nos [Releases](https://github.com/JoaoVictorCoder/clawd-desktop-pet/releases/latest):

- **Windows:** o `.exe`. O app não é assinado, então o Windows pode avisar: clique em **Mais informações → Executar assim mesmo**.
- **Mac:** `.dmg`. Na primeira vez, clique com o botão direito no app → **Abrir**. Pra ele ver a tela, libere em Ajustes → Privacidade → Gravação de Tela.
- **Linux:** `.AppImage` (dê permissão de execução). Precisa de um ambiente com transparência (GNOME, KDE etc.). No Wayland, o clique através da janela pode não funcionar em todo lugar.

Ele abre junto com o sistema (dá pra desligar no menu) e se atualiza sozinho: no Windows e no Linux baixa a versão nova ao abrir e reinicia. No Mac, como o app não é assinado pela Apple, ele avisa e o menu ganha **Baixar versão nova**.

### Requisitos

- **Opcional:** [Claude Code](https://docs.claude.com/claude-code), com login feito, pra ele conversar e ver a tela. Sem ele, o Clawd funciona normalmente, só que usando falas prontas.
- **Ou** qualquer outra IA: veja [Usar outra IA](#usar-outra-ia).

## O que ele faz

- **Anda e explora:** caminha pela barra de tarefas, pula, cai, pode ser carregado e arremessado.
- **Emoções:** fica feliz, apaixonado, triste, bravo, assustado, tonto, com sono... Tem energia e carência: dorme quando cansa e fica triste se você ignora ele.
- **Conversa:** dê dois cliques nele pra conversar. Ele lembra das conversas anteriores.
- **Espia a tela:** se você ligar **Espiar e comentar sozinho**, de vez em quando ele comenta o que você está fazendo. Vem desligado porque o print é da tela inteira; se alguma janela aberta tiver título de banco, senha ou aba anônima, ele não tira print.
- **32 truques aleatórios:** bola de chiclete que estoura na cara, raio que deixa ele tostado, clone em cima da cabeça, jetpack, paraquedas do topo da tela, breakdance de ponta-cabeça, mágica do coelho, pintar um quadro, DJ, toc toc que racha a tela... Dá pra ver todos no menu **Truques**.
- **Envelhece:** se o PC ficar parado, ele fica velhinho, morre, vira um fantasminha e uma lápide aparece. Quando você mexer no mouse, ele revive.
- **Ícone na bandeja** (perto do relógio): clique pra chamar ele, botão direito pro menu.

Ainda não chegaram na versão nova (só na [versão antiga](#versão-antiga-powershell-só-windows)): subir e andar nas janelas e as atividades (jogar junto, notebook, pescar, casinhas...).

## Controles

| Ação | O que acontece |
|---|---|
| Clique | Cutuca ele (se exagerar, ele fica bravo e foge) |
| Dois cliques | Abre a conversa |
| Arrastar e soltar | Carrega ele. Soltando com força, arremessa |
| Passar o mouse em cima, de um lado pro outro | Carinho ❤️ |
| Botão direito | Menu: truques, opções, atualização, sair |

## Personalizar

As configurações (`config.json`), a memória e o log ficam na pasta de dados do app: `%APPDATA%\Clawd` no Windows, `~/Library/Application Support/Clawd` no Mac e `~/.config/Clawd` no Linux. Um `falas.json` (todas as falas dele) ou `persona.txt` (a personalidade usada nas conversas) colocado lá substitui o padrão. Os originais estão na raiz deste repositório, pra servir de base.

## Rodar do código

`cd app && npm install && npm start`. Se o Electron não abrir num clone novo, rode `npm install-scripts approve electron` e o `npm install` de novo.

Pra lançar uma versão: mude `version` em `app/package.json`, faça commit e `git tag v0.2.0 && git push --tags`. O GitHub Actions compila pros três sistemas e publica o Release, e os apps instalados se atualizam a partir dele.

## Usar outra IA

Por padrão ele usa o Claude Code. Pra usar outra IA, crie (ou edite) o `config.json` na pasta de dados (veja [Personalizar](#personalizar)) e reinicie o Clawd:

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

- Quando você conversa com ele, ou quando ele espia a tela, ele manda **um print da tela** pra IA escolhida (por padrão o Claude, usando a sua conta do Claude Code). Com Ollama ou LM Studio, nada sai do seu PC. O print não é salvo em disco.
- Ele não tira print se alguma janela aberta tiver título de senha, banco ou aba anônima. Mas esse filtro olha só os títulos, então não é garantido.
- Dá pra desligar isso no menu, desmarcando **Ver minha tela nas conversas** e **Espiar e comentar sozinho**.
- As conversas ficam salvas só no seu PC, em `memoria.json`. Pra apagar, use **Esquecer conversas** no menu.

## Versão antiga (PowerShell, só Windows)

A primeira versão do Clawd, feita em PowerShell, continua aqui e continua recebendo atualizações. Ela ainda tem coisas que a nova não tem: subir e andar nas janelas (e cair quando você fecha a janela) e as atividades espontâneas (pegar um controle quando você joga, abrir um notebook quando você programa, pescar, construir casinhas, jogar bola, tomar café, ler).

Pra instalar, abra o PowerShell e cole:

```powershell
irm https://raw.githubusercontent.com/JoaoVictorCoder/clawd-desktop-pet/main/install.ps1 | iex
```

Ou baixe o projeto (*Code → Download ZIP*), extraia e dê dois cliques em `instalar.bat`. Ela fica em `%LOCALAPPDATA%\Clawd` (é lá que vão o `config.json`, as falas e o `clawd.log`), abre junto com o Windows e se atualiza sozinha ao abrir. Pra desinstalar, use o atalho **Desinstalar Clawd** no menu Iniciar. Se você tiver as duas instaladas, feche uma antes de abrir a outra.

---

*English: a pixel desktop pet for Windows, Mac and Linux that walks on your taskbar, chats via Claude Code or any OpenAI-compatible API (OpenAI, Gemini, Ollama...), reacts to what you're doing, and does 32 random tricks. Download it from Releases. Unofficial fan project, not affiliated with Anthropic.*
