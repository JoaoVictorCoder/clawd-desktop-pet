// Clawd (Electron) - processo principal: janela transparente por cima da tela,
// icone na bandeja, menu, IA (Claude Code ou API compativel com a OpenAI),
// print da tela e atualizacao automatica.

const { app, BrowserWindow, Tray, Menu, ipcMain, screen, powerMonitor, desktopCapturer, nativeImage, shell } = require('electron')
const path = require('path')
const fs = require('fs')
const { spawn, execFileSync } = require('child_process')

const REPO = 'JoaoVictorCoder/clawd-desktop-pet'
const isMac = process.platform === 'darwin'

if (!app.requestSingleInstanceLock()) { app.quit(); process.exit(0) }

// ---------- arquivos ----------
// falas.json e persona.txt ficam na raiz do repo (os mesmos da versao PowerShell);
// empacotado vao pra pasta resources. Uma copia em userData tem prioridade (pra editar).
const DATA = app.getPath('userData')
const RES = app.isPackaged ? process.resourcesPath : path.join(__dirname, '..')
const cfgPath = path.join(DATA, 'config.json')
const memPath = path.join(DATA, 'memoria.json')
const logPath = path.join(DATA, 'clawd.log')

function log(m) { try { fs.appendFileSync(logPath, `[${new Date().toLocaleTimeString()}] ${m}\n`) } catch {} }
function readRes(name) {
  const own = path.join(DATA, name)
  return fs.readFileSync(fs.existsSync(own) ? own : path.join(RES, name), 'utf8').replace(/^﻿/, '')
}
function readJSON(p, def) { try { return JSON.parse(fs.readFileSync(p, 'utf8').replace(/^﻿/, '')) } catch { return def } }

// ver = manda print da tela nas conversas; espiar = comenta sozinho o que ve (desligado:
// aqui o print e da tela toda, nao so da janela ativa); envelhecer/morte_min = PC parado
const CFG = Object.assign({
  ver: true, espiar: false, envelhecer: true, morte_min: 10, atualizar: true, iniciar: true,
  ia: 'claude', ia_url: '', ia_chave: '', ia_modelo: '', ia_imagem: true
}, readJSON(cfgPath, {}))
function saveConfig() {
  try { fs.mkdirSync(DATA, { recursive: true }); fs.writeFileSync(cfgPath, JSON.stringify(CFG, null, 2)) } catch (e) { log('config: ' + e) }
}

// ---------- IA ----------
const IA_PRESETS = {
  openai: ['https://api.openai.com/v1', 'gpt-4.1-mini', 'OPENAI_API_KEY', true],
  gemini: ['https://generativelanguage.googleapis.com/v1beta/openai', 'gemini-2.5-flash', 'GEMINI_API_KEY', true],
  ollama: ['http://localhost:11434/v1', 'gemma3', '', true],
  lmstudio: ['http://localhost:1234/v1', 'local-model', '', true],
  openrouter: ['https://openrouter.ai/api/v1', 'openai/gpt-4.1-mini', 'OPENROUTER_API_KEY', true],
  groq: ['https://api.groq.com/openai/v1', 'meta-llama/llama-4-scout-17b-16e-instruct', 'GROQ_API_KEY', true],
  deepseek: ['https://api.deepseek.com/v1', 'deepseek-chat', 'DEEPSEEK_API_KEY', false]
}
const AI = { http: CFG.ia !== 'claude', url: CFG.ia_url, key: CFG.ia_chave, model: CFG.ia_modelo, img: CFG.ia_imagem, exe: null }
const pre = IA_PRESETS[String(CFG.ia).toLowerCase()]
if (AI.http && pre) {
  AI.url = AI.url || pre[0]
  AI.model = AI.model || pre[1]
  if (!AI.key && pre[2]) AI.key = process.env[pre[2]] || ''
  if (!pre[3]) AI.img = false
}
if (AI.http && !AI.url) { AI.http = false; log(`ia '${CFG.ia}' sem ia_url no config.json`) }

// Claude Code e opcional: sem ele (e sem outra IA) o Clawd so usa as falas prontas
function findClaude() {
  const home = app.getPath('home')
  const cands = process.platform === 'win32'
    ? [path.join(process.env.LOCALAPPDATA || '', 'Microsoft', 'WinGet', 'Links', 'claude.exe'), path.join(home, '.local', 'bin', 'claude.exe'), path.join(process.env.APPDATA || '', 'npm', 'claude.cmd')]
    : [path.join(home, '.local', 'bin', 'claude'), path.join(home, '.claude', 'local', 'claude'), '/opt/homebrew/bin/claude', '/usr/local/bin/claude', '/usr/bin/claude']
  try {
    // apps abertos pelo Finder/menu nao herdam o PATH do terminal, por isso a lista acima
    const out = execFileSync(process.platform === 'win32' ? 'where' : 'which', ['claude'], { encoding: 'utf8', timeout: 3000 })
    cands.unshift(...out.split(/\r?\n/).filter(Boolean))
  } catch {}
  return cands.find(c => c && fs.existsSync(c)) || null
}
if (!AI.http && CFG.ia === 'claude') AI.exe = findClaude()

function askClaude(prompt, img) {
  return new Promise(resolve => {
    const content = []
    if (img) content.push({ type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: img } })
    content.push({ type: 'text', text: prompt })
    const args = ['-p', '--model', 'haiku', '--tools', '', '--no-session-persistence', '--strict-mcp-config', '--disable-slash-commands',
      '--setting-sources', '', '--input-format', 'stream-json', '--output-format', 'stream-json', '--verbose',
      '--system-prompt-file', path.join(DATA, 'persona-atual.txt')]
    let p
    try {
      // instalado via npm no Windows (.cmd): precisa passar pelo shell
      const viaShell = /\.(cmd|bat)$/i.test(AI.exe)
      p = spawn(AI.exe, viaShell ? args.map(a => `"${a}"`) : args, { cwd: DATA, windowsHide: true, shell: viaShell })
    } catch (e) { return resolve({ err: String(e) }) }
    let out = '', err = ''
    const timer = setTimeout(() => { p.kill(); resolve({ err: 'timeout' }) }, 75000)
    p.stdout.on('data', d => { out += d })
    p.stderr.on('data', d => { err += d })
    p.on('error', e => { clearTimeout(timer); resolve({ err: String(e) }) })
    p.on('close', code => {
      clearTimeout(timer)
      for (const l of out.split('\n')) {
        if (!/"type"\s*:\s*"result"/.test(l)) continue
        try {
          const o = JSON.parse(l)
          return resolve(o.is_error ? { err: String(o.result) } : { text: String(o.result) })
        } catch {}
      }
      resolve({ err: `exit ${code}: ${err}${out}`.slice(0, 2000) })
    })
    p.stdin.end(JSON.stringify({ type: 'user', message: { role: 'user', content } }) + '\n')
  })
}

async function askHttp(prompt, img) {
  const content = [{ type: 'text', text: prompt }]
  if (img && AI.img) content.push({ type: 'image_url', image_url: { url: 'data:image/jpeg;base64,' + img } })
  const headers = { 'Content-Type': 'application/json' }
  if (AI.key) headers.Authorization = 'Bearer ' + AI.key
  try {
    const r = await fetch(AI.url.replace(/\/+$/, '') + '/chat/completions', {
      method: 'POST', headers, signal: AbortSignal.timeout(75000),
      body: JSON.stringify({ model: AI.model, messages: [{ role: 'system', content: readRes('persona.txt') }, { role: 'user', content }] })
    })
    const s = await r.text()
    if (!r.ok) return { err: `http ${r.status}: ${s}` }
    return { text: String(JSON.parse(s).choices[0].message.content) }
  } catch (e) { return { err: String(e && e.message || e) } }
}

// apps onde ele nunca espia (senhas, bancos, abas anonimas): se alguma janela aberta
// tiver um desses titulos, nao tira print
const PRIVATE = /senha|password|bitwarden|1password|keepass|lastpass|dashlane|nubank|itau|bradesco|santander|caixa econ|banco|bank|inprivate|incognito|an.nima|privad/i

async function snapshot(maxSide) {
  if (!CFG.ver) return null
  try {
    const wins = await desktopCapturer.getSources({ types: ['window'], thumbnailSize: { width: 0, height: 0 } })
    if (wins.some(w => PRIVATE.test(w.name))) return null
    const d = screen.getDisplayNearestPoint(screen.getCursorScreenPoint())
    const k = maxSide / Math.max(d.size.width, d.size.height)
    const shots = await desktopCapturer.getSources({ types: ['screen'], thumbnailSize: { width: Math.round(d.size.width * k), height: Math.round(d.size.height * k) } })
    const shot = shots.find(s => s.display_id === String(d.id)) || shots[0]
    if (!shot || shot.thumbnail.isEmpty()) return null
    return shot.thumbnail.toJPEG(70).toString('base64')
  } catch (e) { log('print: ' + e); return null }
}

ipcMain.handle('init', () => {
  // o Claude Code le a persona de um arquivo: deixa uma copia atual em userData
  try { fs.mkdirSync(DATA, { recursive: true }); fs.writeFileSync(path.join(DATA, 'persona-atual.txt'), readRes('persona.txt')) } catch {}
  return {
    falas: JSON.parse(readRes('falas.json')), cfg: CFG, hist: readJSON(memPath, []),
    hasAI: !!(AI.http || AI.exe), aiImg: !AI.http || AI.img, area: win.getBounds(), platform: process.platform
  }
})
ipcMain.handle('ai', async (_e, prompt, img) => {
  const r = AI.http ? await askHttp(prompt, img) : await askClaude(prompt, img)
  if (r.err) log(`${CFG.ia}: ${r.err}`)
  return r
})
ipcMain.handle('snapshot', (_e, maxSide) => snapshot(maxSide))
ipcMain.on('save-hist', (_e, hist) => { try { fs.writeFileSync(memPath, JSON.stringify(hist)) } catch {} })
ipcMain.on('log', (_e, m) => log(m))

// ---------- janela ----------
// uma janela transparente do tamanho da area de trabalho; ela deixa o mouse passar,
// menos quando o cursor esta em cima do Clawd (ou do balao, ou da caixa de conversa)
let win, tray
let hit = { rects: [], capture: false }
let ignoring = true

function createWindow() {
  const d = screen.getPrimaryDisplay()
  win = new BrowserWindow({
    ...d.workArea, frame: false, transparent: true, resizable: false, movable: false,
    skipTaskbar: true, alwaysOnTop: true, hasShadow: false, focusable: true, show: false,
    fullscreenable: false, minimizable: false, maximizable: false,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), backgroundThrottling: false }
  })
  win.setAlwaysOnTop(true, 'screen-saver')
  if (isMac) win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: false })
  win.setIgnoreMouseEvents(true, { forward: true })
  win.loadFile(path.join(__dirname, 'index.html'))
  win.once('ready-to-show', () => win.showInactive())
  // se a area de trabalho mudar (barra de tarefas, resolucao), acompanha
  const fit = () => { const a = screen.getPrimaryDisplay().workArea; win.setBounds(a); win.webContents.send('area', a) }
  screen.on('display-metrics-changed', fit)
  screen.on('display-added', fit)
  screen.on('display-removed', fit)
}

ipcMain.on('hit', (_e, h) => { hit = h })
ipcMain.on('focus-input', () => { win.setIgnoreMouseEvents(false); ignoring = false; win.focus() })
ipcMain.on('blur-input', () => win.blur())
ipcMain.on('menu', () => buildMenu().popup({ window: win }))

// cursor e tempo parado vao pro renderer a cada ~33ms; aqui tambem decide se a janela pega o mouse
function pump() {
  if (!win || win.isDestroyed()) return
  const c = screen.getCursorScreenPoint()
  const b = win.getBounds()
  const x = c.x - b.x, y = c.y - b.y
  const over = hit.capture || hit.rects.some(r => x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3])
  if (over === ignoring) { ignoring = !over; win.setIgnoreMouseEvents(ignoring, { forward: true }) }
  win.webContents.send('pump', { x, y, idle: powerMonitor.getSystemIdleTime() })
}

// ---------- menu e bandeja ----------
const send = (a, v) => win && win.webContents.send('action', a, v)
let updateURL = null
let tricks = []   // [nome, rotulo], vem do truques.js
ipcMain.on('tricks', (_e, list) => { tricks = list; if (process.platform === 'linux' && tray) tray.setContextMenu(buildMenu()) })

function buildMenu() {
  const toggle = (label, key) => ({ label, type: 'checkbox', checked: !!CFG[key], click: i => { CFG[key] = i.checked; saveConfig(); send('config', CFG) } })
  const items = [
    { label: 'Conversar', click: () => send('chat') },
    { label: 'Truques', submenu: [
      { label: 'Surpresa!', click: () => send('trick', '*') },
      { type: 'separator' },
      ...tricks.map(([name, label]) => ({ label, click: () => send('trick', name) }))
    ] },
    { label: 'Pular', click: () => send('hop') },
    { label: 'Dançar', click: () => send('dance') },
    { label: 'Dormir', click: () => send('sleep') },
    { type: 'separator' },
    toggle('Envelhecer com o PC parado', 'envelhecer'),
    toggle('Ver minha tela nas conversas', 'ver'),
    toggle('Espiar e comentar sozinho', 'espiar'),
    { label: 'Espiar agora', click: () => send('peek') },
    { type: 'separator' },
    { label: 'Esquecer conversas', click: () => { try { fs.unlinkSync(memPath) } catch {} send('forget') } },
    { type: 'separator' },
    { label: 'Esconder o Clawd', type: 'checkbox', checked: !win.isVisible(), click: i => { if (i.checked) win.hide(); else win.showInactive() } },
    { label: 'Procurar atualização', click: () => checkUpdate(true) },
    toggle('Atualizar sozinho ao abrir', 'atualizar')
  ]
  if (process.platform !== 'linux') {
    items.push({ label: 'Abrir junto com o sistema', type: 'checkbox', checked: CFG.iniciar, click: i => { CFG.iniciar = i.checked; saveConfig(); setLogin() } })
  }
  if (updateURL) items.push({ label: 'Baixar versão nova', click: () => shell.openExternal(updateURL) })
  items.push({ label: 'Sair', click: () => app.quit() })
  return Menu.buildFromTemplate(items)
}

ipcMain.on('tray-icon', (_e, small, big) => {
  if (tray) return
  // Windows usa 32px; Mac (barra de menus) e Linux, 18px
  tray = new Tray(nativeImage.createFromDataURL(process.platform === 'win32' ? big : small))
  tray.setToolTip('Clawd')
  const show = () => { if (!win.isVisible()) win.showInactive(); send('called') }
  tray.on('click', show)
  tray.on('double-click', () => send('chat'))
  tray.on('right-click', () => tray.popUpContextMenu(buildMenu()))
  // no Linux o clique esquerdo nem sempre chega: o menu fica sempre ligado
  if (process.platform === 'linux') tray.setContextMenu(buildMenu())
})

// ---------- atualizacao ----------
// Windows (instalador) e Linux (AppImage): electron-updater baixa a versao nova dos
// Releases do GitHub e reinicia. Mac sem assinatura nao deixa trocar o app sozinho:
// ele avisa e o menu ganha "Baixar versao nova".
function newer(a, b) {
  const pa = a.replace(/^v/, '').split('.').map(Number), pb = b.replace(/^v/, '').split('.').map(Number)
  for (let i = 0; i < 3; i++) { if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) > (pb[i] || 0) }
  return false
}

async function checkManual(manual) {
  try {
    const r = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { headers: { 'User-Agent': 'clawd-desktop-pet' }, signal: AbortSignal.timeout(8000) })
    const j = await r.json()
    if (j.tag_name && newer(j.tag_name, app.getVersion())) {
      updateURL = j.html_url
      if (process.platform === 'linux') tray && tray.setContextMenu(buildMenu())
      send('update', 'baixar')
    } else if (manual) send('update', 'atualizado')
  } catch (e) { log('atualizar: ' + e); if (manual) send('update', 'erro') }
}

function checkUpdate(manual) {
  if (!app.isPackaged) { if (manual) send('update', 'atualizado'); return }
  let updater = null
  if (!isMac && !(process.platform === 'linux' && !process.env.APPIMAGE)) {
    try { updater = require('electron-updater').autoUpdater } catch (e) { log('electron-updater: ' + e) }
  }
  if (!updater) return checkManual(manual)
  updater.removeAllListeners()
  updater.on('update-available', () => send('update', 'baixando'))
  updater.on('update-not-available', () => { if (manual) send('update', 'atualizado') })
  updater.on('update-downloaded', () => { send('update', 'instalando'); setTimeout(() => updater.quitAndInstall(true, true), 4000) })
  updater.on('error', e => { log('atualizar: ' + e); if (manual) send('update', 'erro') })
  updater.checkForUpdates().catch(() => {})
}

// abre junto com o sistema (Windows e Mac; no Linux o AppImage nao tem esse recurso)
function setLogin() {
  if (app.isPackaged && process.platform !== 'linux') app.setLoginItemSettings({ openAtLogin: !!CFG.iniciar })
}

// ---------- inicio ----------
app.on('second-instance', () => { if (win) { win.showInactive(); send('called') } })
app.whenReady().then(() => {
  if (isMac) app.dock.hide()
  setLogin()
  createWindow()
  setInterval(pump, 33)
  if (CFG.atualizar) setTimeout(() => checkUpdate(false), 5000)
  // pra testar: CLAWD_TRUQUE=chuva npm start
  if (process.env.CLAWD_TRUQUE) setTimeout(() => send('trick', process.env.CLAWD_TRUQUE), 3000)
})
app.on('window-all-closed', () => app.quit())
