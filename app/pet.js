// Clawd (Electron) - o bichinho: sprite, fisica, emocoes, balao, conversa e velhice.
// Porte do clawd.ps1. Tudo e desenhado num canvas do tamanho da area de trabalho.
'use strict'

const C = document.getElementById('c')
const G = C.getContext('2d')
const inpBox = document.getElementById('inp')
const tb = document.getElementById('tb')

// ---------- constantes ----------
const COLS = 18, ROWS = 10      // sprite
const OX = 6, OY = 12           // posicao do sprite dentro do "quadro" dele (em celulas)
const FH = 32                   // altura do quadro: espaco pras particulas em cima
const PX = 4
const SW = COLS * PX, SH = ROWS * PX
const GRAV = 0.9
const rnd = n => Math.floor(Math.random() * n)
const rndr = (a, b) => a + rnd(b - a)
const pick = a => a[rnd(a.length)]
const sign = v => (v > 0) - (v < 0)
const clamp = (v, a, b) => Math.max(a, Math.min(b, v))

const BR = {
  O: 'rgb(217,119,87)',   // corpo
  K: 'rgb(25,25,25)',     // olhos
  R: 'rgb(232,72,104)',   // coracao / raiva
  P: 'rgb(240,150,140)',  // bochecha
  B: 'rgb(120,175,255)',  // lagrima / zzz / suor
  Y: 'rgb(255,206,64)',   // estrela / exclamacao
  N: 'rgb(175,135,255)',  // nota musical
  W: 'rgb(245,245,245)',  // cabelo branco / fantasma
  G: 'rgb(150,150,162)',  // lapide
  D: 'rgb(70,70,82)',     // letras da lapide
  M: 'rgb(115,80,50)',    // terra
  L: 'rgb(80,170,80)',    // caule
  C: 'rgb(140,95,55)',    // bengala
  E: 'rgb(60,45,40)'      // tostado
}
// cor do corpo desbotando com a idade (0 = jovem, 10 = bem velhinho)
const AGEBR = Array.from({ length: 11 }, (_, i) => {
  const a = i / 10
  return `rgb(${Math.round(217 + (178 - 217) * a)},${Math.round(119 + (160 - 119) * a)},${Math.round(87 + (152 - 87) * a)})`
})

const LYING = [
  '..................',
  '..................',
  '...O.O......O.O...',
  '...O.O......O.O...',
  '..OOOOOOOOOOOOOO..',
  '..OOKOKOOOOKOKOO..',
  'OOOOOKOOOOOOKOOOOO',
  'OOOOKOKOOOOKOKOOOO',
  '..OOOOOOOOOOOOOO..',
  '..OOOOOOOOOOOOOO..'
]
const GRAVE = [
  '......GGGGGGG.....',
  '.....GGGGGGGGG....',
  '....GGGGGGGGGGG...',
  '....GDDDGDGDDDG...',
  '....GDGDGDGDGDG...',
  '....GDDGGDGDDDG...',
  '....GDGDGDGDGGG...',
  '.Y..GGGGGGGGGGG.R.',
  '.L..GGGGGGGGGGG.L.',
  'MMMMMMMMMMMMMMMMMM'
]
const EYES = {
  neutral: ['.K.', '.K.', '...'],
  thinking: ['.K.', '.K.', '...'],
  closed: ['...', 'KKK', '...'],
  sleep: ['...', 'KKK', '...'],
  happy: ['.K.', 'K.K', '...'],
  love: ['R.R', 'RRR', '.R.'],
  sad: ['...', '.K.', '.K.'],
  angry: ['K..', '.K.', '.K.'],
  surprised: ['KKK', 'K.K', 'KKK'],
  scared: ['KKK', 'K.K', 'KKK'],
  dizzy: ['K.K', '.K.', 'K.K'],
  excited: ['.Y.', 'YYY', '.Y.'],
  sleepy: ['...', 'KKK', '.K.']
}
const PAT = {
  heart: ['.R.R.', 'RRRRR', 'RRRRR', '.RRR.', '..R..'],
  z: ['BBB', '..B', '.B.', 'B..', 'BBB'],
  bang: ['Y', 'Y', 'Y', '.', 'Y'],
  what: ['YYY', '..Y', '.Y.', '...', '.Y.'],
  star: ['.Y.', 'YYY', '.Y.'],
  note: ['..NN', '..N.', '..N.', 'NNN.', 'NN..'],
  sweat: ['.B.', 'BBB', '.B.'],
  anger: ['RR.RR', 'R...R', '.....', 'R...R', 'RR.RR'],
  tear: ['B', 'B'],
  ghost: ['..WWWWWW..', '.WWWWWWWW.', '.WWKWWKWW.', 'WWWKWWKWWW', '.WWWWWWWW.', '.WWWWWWWW.', '.WW.WW.WW.', '.W..W..W..']
}

// ---------- estado ----------
let Falas = {}, CFG = {}, hasAI = false, aiImg = true
let area = { w: innerWidth, h: innerHeight }
const cursor = { x: -9999, y: -9999 }
let idle = 0
const S = {
  sx: 0, sy: 0, vx: 0, vy: 0,
  state: 'idle', stateT: 60, dir: 1, look: 0, lookY: 0,
  speed: 1.6, frame: 0, blink: 0, tick: 0, squash: 0,
  drag: false, moved: false, dragMood: 'scared', offX: 0, offY: 0, downX: 0, downY: 0, lastX: 0, lastY: 0, dvx: 0, dvy: 0,
  mood: 'neutral', moodT: 0, energy: 100, social: 70,
  pokes: [], petAcc: 0, hoverTick: 0, lastHX: 0, lastHY: 0, pendingClick: 0,
  thrown: false, lastErr: -9999, nextChatter: 400, nextPeek: 6000,
  age: 0, deadT: 0, wasOld: false, ghostOn: false, gx: 0, gy: 0
}
const Parts = []
const Balloon = { active: false, text: '', lines: [], shown: 0, life: 0, prio: 0, hold: false, w: 10, boxH: 10, tail: 10, x: 0, y: 0 }
const Chat = { busy: false, kind: 'chat', img: null, hist: [] }

// ---------- falas ----------
function Line(key, vars) {
  const list = [].concat(Falas[key] || [])
  if (!list.length || !list[0]) return ''
  let t = String(pick(list))
  if (vars) for (const k in vars) t = t.split('{' + k + '}').join(String(vars[k]))
  return t
}

// ---------- balao de fala ----------
const BB = 2, PAD = 8, MAXW = 220, LINEH = 17
const FONT = '600 13px "Segoe UI Semibold", "Segoe UI", system-ui, -apple-system, sans-serif'

function wrap(text) {
  G.font = FONT
  const lines = []
  let cur = ''
  for (const w of text.split(' ')) {
    const t = cur ? cur + ' ' + w : w
    if (cur && G.measureText(t).width > MAXW - 2 * PAD) { lines.push(cur); cur = w } else cur = t
  }
  if (cur) lines.push(cur)
  return lines
}

function Say(text, prio = 1, hold = false) {
  if (!text) return
  if (Balloon.active && Balloon.prio > prio) return
  Object.assign(Balloon, { text, shown: 0, prio, hold, life: 50 + Math.round(text.length * 1.5), active: true })
  Balloon.lines = wrap(text)
  G.font = FONT
  const tw = Math.max(...Balloon.lines.map(l => G.measureText(l).width))
  Balloon.w = Math.ceil(Math.max(tw + 2 * PAD, 10 * BB))
  Balloon.boxH = Balloon.lines.length * LINEH + 2 * PAD - 2
  Update_Bubble()
}
function Hide_Bubble() { Balloon.active = false; Balloon.prio = 0 }

function Update_Bubble() {
  if (!Balloon.active) return
  let cx = S.sx + SW / 2
  let top = S.sy - 2 * PX
  if (S.ghostOn) { cx = S.sx + (S.gx - OX + 5) * PX; top = S.sy + (S.gy - OY - 1) * PX }   // fala o fantasminha
  const h = Balloon.boxH + 2 * BB
  Balloon.x = Math.round(clamp(cx - Balloon.w / 2, 4, area.w - Balloon.w - 4))
  Balloon.y = Math.round(Math.max(4, top - h))
  Balloon.tail = Math.round(clamp(cx - Balloon.x, 4 * BB, Balloon.w - 4 * BB))
}

function Draw_Bubble() {
  const { x, y, w, boxH: h, tail: t } = Balloon, b = BB
  const R = (c, rx, ry, rw, rh) => { G.fillStyle = c; G.fillRect(x + rx, y + ry, rw, rh) }
  const dark = 'rgb(40,40,40)', white = '#fff'
  R(dark, b, 0, w - 2 * b, h); R(dark, 0, b, w, h - 2 * b); R(white, b, b, w - 2 * b, h - 2 * b)
  R(dark, t - 3 * b, h - b, 6 * b, b); R(white, t - 2 * b, h - b, 4 * b, b)
  R(dark, t - 2 * b, h, 4 * b, b); R(white, t - b, h, 2 * b, b)
  R(dark, t - b, h + b, 2 * b, b)
  G.font = FONT; G.fillStyle = 'rgb(30,30,30)'; G.textBaseline = 'top'
  let left = Balloon.shown
  Balloon.lines.forEach((l, i) => {
    if (left <= 0) return
    G.fillText(l.slice(0, left), x + PAD, y + PAD + i * LINEH)
    left -= l.length + 1
  })
}

// ---------- caixa de conversa ----------
async function Show_Input() {
  if (inpBox.style.display === 'block') return
  Chat.img = hasAI && aiImg ? await window.clawd.snapshot(768) : null   // antes da caixa aparecer
  if (Balloon.prio < 3) Hide_Bubble()
  Set_State('idle'); S.stateT = 300
  inpBox.style.display = 'block'
  const x = clamp(S.sx + SW / 2 - inpBox.offsetWidth / 2, 4, area.w - inpBox.offsetWidth - 4)
  const y = Math.max(4, S.sy - inpBox.offsetHeight - 3 * PX)
  inpBox.style.left = x + 'px'; inpBox.style.top = y + 'px'
  window.clawd.focusInput()
  tb.value = ''
  setTimeout(() => tb.focus(), 30)
}
function Hide_Input() {
  if (inpBox.style.display !== 'block') return
  inpBox.style.display = 'none'
  window.clawd.blurInput()
}
tb.addEventListener('keydown', e => {
  if (e.key === 'Enter') {
    e.preventDefault()
    const msg = tb.value.trim(); Hide_Input()
    if (msg) Start_Chat(msg)
  } else if (e.key === 'Escape') { e.preventDefault(); Hide_Input() }
})
tb.addEventListener('blur', () => setTimeout(Hide_Input, 100))

// ---------- conversa com a IA ----------
const two = n => String(n).padStart(2, '0')
function Get_Context() {
  const d = new Date()
  return `${two(d.getHours())}:${two(d.getMinutes())}, humor ${Get_Expr()}, energia ${Math.round(S.energy)}, carencia ${Math.round(100 - S.social)}. Voce esta em cima da barra.`
}
function Get_Recent(n) { return Chat.hist.slice(-n).map(h => (h.r === 'u' ? 'Usuario: ' : 'Clawd: ') + h.t) }

function Start_Chat(msg) {
  if (Chat.busy) { Say(Line('ocupado'), 2); return }
  Chat.hist.push({ r: 'u', t: msg })
  S.social = Math.min(100, S.social + 25)
  Invoke_AI(Get_Context() + '\n' + Get_Recent(6).join('\n'), Chat.img, 'chat')
  Chat.img = null
}

async function Start_Peek() {
  if (!hasAI || !aiImg || Chat.busy) return
  const img = await window.clawd.snapshot(512)
  if (!img) return
  Invoke_AI(Get_Context() + '\nEspiou a tela (print). Comente. Nao repita: ' + Get_Recent(2).join(' / '), img, 'peek')
}

async function Invoke_AI(prompt, img, kind) {
  Chat.kind = kind
  if (!hasAI) {
    if (kind === 'chat') { Balloon.prio = 0; Say(Line('sem_claude_instalado'), 3); Set_Mood('sad', 60) }
    return
  }
  Chat.busy = true
  if (kind === 'chat') Say('...', 3, true)
  const r = await window.clawd.ai(prompt, img)
  Chat.busy = false
  Finish_Chat(r.text || '', r.err || '')
}

const EMO = { feliz: 'happy', amor: 'love', triste: 'sad', bravo: 'angry', surpreso: 'surprised', pensativo: 'thinking', animado: 'excited', sono: 'sleepy', medo: 'scared', neutro: 'neutral' }

function Finish_Chat(out, err) {
  // modelos que "pensam" alto (deepseek-r1, qwen3...) mandam o raciocinio entre <think>
  let txt = out.replace(/<think>[\s\S]*?<\/think>/g, '').trim()
  if (!txt) {
    if (Chat.kind === 'peek') return
    Balloon.prio = 0; Say(Line('sem_claude'), 3); Set_Mood('sad', 60)
    return
  }
  let mood = 'neutral'
  const m = txt.match(/\[(\w+)\]/)
  if (m && EMO[m[1].toLowerCase()]) mood = EMO[m[1].toLowerCase()]
  const acts = [...txt.matchAll(/\{(\w+)\}/g)].map(x => x[1].toLowerCase())
  txt = txt.replace(/\{\w+\}/g, '').replace(/\[\w+\]/g, '').replace(/\*/g, '').replace(/\s+/g, ' ').trim()
  // as vezes a acao vem sem chaves no comeco da fala
  const a0 = txt.match(/^(pular|dan\w+|dormir|explorar|acenar)\b[\s,.:!-]*/i)
  if (a0) { acts.push(a0[1].toLowerCase()); txt = txt.slice(a0[0].length) }
  // garante fala curta: fica so com a primeira frase se passar do limite
  if (txt.length > 80) {
    const f = txt.match(/^.{10,80}?[.!?](\s|$)/)
    txt = f ? f[0].trim() : txt.slice(0, 77).trim() + '...'
  }
  Chat.hist.push({ r: 'c', t: txt })
  while (Chat.hist.length > 40) Chat.hist.shift()
  window.clawd.saveHist(Chat.hist)

  Balloon.prio = 0
  Say(txt, 3)
  Set_Mood(mood, 180)
  for (const a of acts) {
    if (/^pul/.test(a)) Invoke_Hop()
    else if (/^dan/.test(a)) Set_State('dance')
    else if (/^dorm/.test(a)) Set_State('sleep')
    else if (/^acen/.test(a)) Set_State('wave')
  }
}

// ---------- emocoes e particulas ----------
const Test_Alive = () => S.state !== 'dead' && S.state !== 'revive'

function Get_Expr() {
  if (!Test_Alive()) return 'dead'
  if (S.state === 'sleep') return 'sleep'
  if (S.drag && S.moved) return S.dragMood
  if (S.moodT > 0) return S.mood
  if (Chat.busy) return 'thinking'
  if (S.energy < 20) return 'sleepy'
  if (S.social < 25) return 'sad'
  return 'neutral'
}

function Emit(k, n = 1) {
  for (let i = 0; i < n; i++) {
    if (Parts.length > 24) return
    const p = { k, x: OX + 7 + rndr(-4, 5), y: OY - 5 + rndr(-1, 2), vx: (Math.random() - 0.5) * 0.06, vy: -0.07 - Math.random() * 0.05, life: 45 + rnd(15) }
    if (k === 'tear') Object.assign(p, { x: OX + 5 + S.look, y: OY + 5, vx: 0, vy: 0.14, life: 22 })
    if (k === 'z') Object.assign(p, { x: OX + 14, y: OY - 2, vx: 0.05, vy: -0.06 })
    if (k === 'sweat') Object.assign(p, { x: OX + 15, y: OY - 1, vx: 0.03, vy: 0.05, life: 25 })
    Parts.push(p)
  }
}

function Set_Mood(m, t) {
  S.mood = m; S.moodT = t
  const e = { happy: ['note'], love: ['heart', 2], sad: ['tear'], angry: ['anger'], surprised: ['bang'], scared: ['sweat'], excited: ['star', 2], thinking: ['what'] }[m]
  if (e) Emit(...e)
}

function Step_Particles() {
  for (let i = Parts.length - 1; i >= 0; i--) {
    const p = Parts[i]; p.x += p.vx; p.y += p.vy; p.life--
    if (p.life <= 0 || p.y < 0 || p.y > FH) Parts.splice(i, 1)
  }
  const e = Get_Expr(), t = S.tick
  if (e === 'sleep' && t % 35 === 0) Emit('z')
  if (e === 'love' && t % 30 === 0) Emit('heart')
  if (e === 'angry' && t % 45 === 0) Emit('anger')
  if (e === 'sad' && t % 90 === 0) Emit('tear')
  if (e === 'scared' && t % 25 === 0) Emit('sweat')
  if (e === 'thinking' && t % 70 === 0) Emit('what')
  if (e === 'excited' && t % 40 === 0) Emit('star')
  if (S.state === 'dance' && t % 22 === 0) Emit('note')
}

// ---------- sprite ----------
const blankRow = () => Array(COLS).fill('.')

function Get_DeadSprite() {
  const t = S.deadT
  if (S.state === 'dead' && t < 30) return Get_Sprite('scared')
  if (S.state === 'dead' && t < 170) {
    const grid = LYING.map(r => r.split(''))
    if (t < 110 && Math.floor(t / 4) % 2 === 0) for (const c of [3, 5, 12, 14]) grid[2][c] = '.'   // perninhas tremendo
    return grid
  }
  // lapide subindo do chao (a terra fica sempre embaixo)
  const shift = S.state === 'dead' ? Math.max(0, 9 - Math.floor((t - 170) / 2)) : 0
  const grid = []
  for (let r = 0; r < ROWS; r++) grid[r] = r - shift >= 0 ? GRAVE[r - shift].split('') : blankRow()
  grid[9] = GRAVE[9].split('')
  return grid
}

function Get_Sprite(force) {
  if (!force && !Test_Alive()) return Get_DeadSprite()
  let expr = force || Get_Expr()
  if (S.age >= 0.5 && expr === 'neutral') expr = 'sleepy'
  const grid = Array.from({ length: ROWS }, blankRow)
  for (let r = 0; r < 8; r++) for (let c = 2; c <= 15; c++) grid[r][c] = 'O'

  const held = S.drag && S.moved
  let armL = 4, armR = 4
  if (held || expr === 'excited' || expr === 'scared') { armL = 1; armR = 1 }
  else if (expr === 'sad' || expr === 'sleepy' || expr === 'sleep') { armL = 6; armR = 6 }
  if (S.state === 'dance') { if (S.frame === 0) { armL = 1; armR = 4 } else { armL = 4; armR = 1 } }
  if (S.state === 'wave') armR = [1, 3][S.frame]
  for (const c of [0, 1]) { grid[armL][c] = 'O'; grid[armL + 1][c] = 'O' }
  for (const c of [16, 17]) { grid[armR][c] = 'O'; grid[armR + 1][c] = 'O' }

  let pat = EYES[expr] || EYES.neutral
  if (S.blink > 0 && ['neutral', 'thinking', 'sad', 'angry', 'happy'].includes(expr)) pat = EYES.closed
  let lx = 0, ly = 0
  if (['neutral', 'sad', 'angry', 'happy', 'surprised', 'sleepy', 'scared'].includes(expr)) { lx = S.look; ly = S.lookY }
  if (expr === 'thinking') { lx = 1; ly = -1 }
  for (let i = 0; i < 3; i++) {
    for (let j = 0; j < 3; j++) {
      let ch = pat[i][j]; if (ch !== '.') grid[2 + ly + i][4 + lx + j] = ch
      ch = pat[i][2 - j]; if (ch !== '.') grid[2 + ly + i][11 + lx + j] = ch
    }
  }
  if (['love', 'happy', 'excited'].includes(expr)) { grid[5][3] = 'P'; grid[5][14] = 'P' }

  // velhice: cabelo branco, depois sobrancelhas, bigode e bengala
  if (S.age >= 0.3) for (const c of [4, 6, 7, 10, 11, 13]) grid[0][c] = 'W'
  if (S.age >= 0.6) {
    for (const c of [3, 4, 5, 6, 7, 10, 11, 12, 13, 14]) grid[0][c] = 'W'
    for (const c of [4, 5, 6, 11, 12, 13]) grid[1][c] = 'W'
    for (const c of [6, 7, 8, 9, 10, 11]) grid[5][c] = 'W'
    const cc = S.look < 0 ? 0 : 17, hc = S.look < 0 ? 1 : 16
    for (let r = 3; r < ROWS; r++) grid[r][cc] = 'C'
    grid[3][hc] = 'C'
  }

  let lifted = []
  if (!held && ['walk', 'run', 'seek', 'dance'].includes(S.state)) lifted = S.frame === 0 ? [5, 14] : [3, 12]
  for (const c of [3, 5, 12, 14]) {
    grid[8][c] = 'O'
    if (!lifted.includes(c)) grid[9][c] = 'O'
  }
  if (S.state === 'sleep' || S.state === 'crouch' || S.squash > 0 || S.age >= 0.6) {
    for (let r = ROWS - 1; r > 0; r--) grid[r] = grid[r - 1]
    grid[0] = blankRow()
  }
  return grid
}

// desenha um padrao em celulas (x, y) relativas ao quadro do Clawd
function Draw_Pattern(ctx, pat, x, y, ox, oy, px = PX) {
  const bx = Math.round(x), by = Math.round(y)
  for (let i = 0; i < pat.length; i++) {
    const row = pat[i]
    for (let j = 0; j < row.length; j++) {
      const ch = row[j]
      if (ch !== '.') { ctx.fillStyle = BR[ch]; ctx.fillRect(ox + (bx + j) * px, oy + (by + i) * px, px, px) }
    }
  }
}

function Draw() {
  G.clearRect(0, 0, area.w, area.h)
  const fx = Math.round(S.sx - OX * PX), fy = Math.round(S.sy - OY * PX)
  const grid = Get_Sprite()
  const body = AGEBR[Math.round(S.age * 10)]
  let shx = OX
  if ((S.state === 'dead' && S.deadT < 30) || (S.state === 'revive' && S.deadT >= 25)) shx += (S.tick % 2) * 2 - 1   // tremedeira
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const ch = grid[r][c]
      if (ch === '.') continue
      G.fillStyle = ch === 'O' ? body : BR[ch]
      G.fillRect(fx + (shx + c) * PX, fy + (OY + r) * PX, PX, PX)
    }
  }
  for (const p of Parts) Draw_Pattern(G, PAT[p.k], p.x, p.y, fx, fy)
  if (S.ghostOn) Draw_Pattern(G, PAT.ghost, S.gx, S.gy, fx, fy)
  if (Get_Expr() === 'dizzy') {
    const a = S.tick * 0.18
    for (const k of [0, 1]) {
      const ang = a + k * Math.PI
      Draw_Pattern(G, PAT.star, OX + 8 + 7 * Math.cos(ang), OY - 2 + 1.5 * Math.sin(ang), fx, fy)
    }
  }
  if (Balloon.active) Draw_Bubble()
}

// icone da bandeja: o proprio sprite feliz, sem borrar
function Make_TrayIcons() {
  const small = document.createElement('canvas'); small.width = small.height = 18
  Draw_Pattern(small.getContext('2d'), Get_Sprite('happy').map(r => r.join('')), 0, 4, 0, 0, 1)
  const big = document.createElement('canvas'); big.width = big.height = 32
  const ctx = big.getContext('2d')
  ctx.imageSmoothingEnabled = false
  ctx.drawImage(small, 0, 0, 32, 32)
  window.clawd.trayIcon(small.toDataURL('image/png'), big.toDataURL('image/png'))
}

// ---------- comportamento ----------
function Set_State(name) {
  S.state = name
  const t = { walk: rndr(60, 260), idle: rndr(40, 160), sleep: 999999, run: 70, seek: 300, dance: 160, wave: 45, crouch: 12 }[name]
  if (name === 'walk') S.dir = pick([-1, 1])
  if (t) S.stateT = t
}

function Invoke_Jump(v) { S.vy = v }
function Invoke_Hop() { Invoke_Jump(-11); S.vx = 0; if (S.state !== 'dance') Set_State('idle') }

function Pick_State() {
  if (S.age > 0.5) { Set_State(rnd(100) < 55 ? 'walk' : 'idle'); return }   // velhinho nao pula
  if (S.energy < 15) { Set_State('sleep'); Say(Line('sono')); return }
  if (S.social < 25 && rnd(100) < 45) {
    Set_State('seek')
    if (rnd(2) === 0) Say(Line('solitario'))
    return
  }
  const r = rnd(100)
  if (r < 48) Set_State('walk')
  else if (r < 72) Set_State('idle')
  else if (r < 82) Invoke_Hop()
  else if (r < 88) { Set_State('seek'); Emit('what') }
  else if (r < 94) Set_State('dance')
  else if (S.energy < 70) { Set_State('sleep'); Say(Line('sono')) }
  else Set_State('idle')
}

function Move_Walk(spd) {
  S.sx += S.dir * spd
  const every = spd > S.speed * 1.5 ? 3 : 5
  if (S.tick % every === 0) S.frame = 1 - S.frame
}

function Step_Behavior() {
  if (!Test_Alive()) return
  const cx = S.sx + SW / 2
  let spd = S.speed * (1 - 0.75 * S.age)
  if (Get_Expr() === 'sad') spd *= 0.6
  switch (S.state) {
    case 'walk': Move_Walk(spd); break
    case 'run': Move_Walk(S.speed * 2.6); break
    case 'seek': {
      const dx = cursor.x - cx
      if (Math.abs(dx) < 30) {
        Set_State('idle')
        if (S.social < 40) Say(Line('achou'))
      } else { S.dir = sign(dx); Move_Walk(spd * 1.3) }
      break
    }
    case 'dance':
      if (S.tick % 8 === 0) S.frame = 1 - S.frame
      if (S.tick % 24 === 0) Invoke_Jump(-4)
      break
    case 'wave': if (S.tick % 7 === 0) S.frame = 1 - S.frame; break
    case 'sleep':
      if (S.energy >= 100) { Set_State('idle'); Set_Mood('happy', 60); Say(Line('acordou')) }
      break
  }
  S.stateT--
  if (S.stateT <= 0) Pick_State()
}

function Land(impact) {
  S.vy = 0; S.vx *= 0.4
  if (impact > 6) S.squash = 4
  if (S.thrown) {
    S.thrown = false; S.moodT = 0
    if (impact > 12) { Set_Mood('dizzy', 120); Say(Line('tonto')) } else Set_Mood('happy', 40)
  }
}

function Invoke_Poke() {
  S.social = Math.min(100, S.social + 4)
  if (S.state === 'sleep') { Set_State('idle'); Set_Mood('angry', 70); Say(Line('acordado')); return }
  S.pokes.push(S.tick)
  while (S.pokes.length && S.pokes[0] < S.tick - 150) S.pokes.shift()
  const n = S.pokes.length
  if (n >= 6) {
    S.pokes = []; Set_Mood('angry', 150); Say(Line('chega'), 2)
    S.dir = -sign(cursor.x - (S.sx + SW / 2)) || 1
    S.state = 'run'; S.stateT = 80
    return
  }
  if (n >= 3) { Set_Mood('angry', 70); Say(Line('irritado')); return }
  switch (rnd(3)) {
    case 0: Invoke_Hop(); Set_Mood('happy', 50); break
    case 1: Set_Mood('surprised', 40); break
    case 2: Set_State('wave'); Set_Mood('happy', 50); break
  }
  Say(Line('cutucar'))
}

function Invoke_Pet() {
  S.social = Math.min(100, S.social + 8)
  Emit('heart', 2)
  if (S.state === 'sleep') return
  Set_Mood('love', 120)
  if (rnd(100) < 45) Say(Line('carinho'))
}

// ---------- mouse ----------
// a janela so recebe o mouse em cima destes retangulos (o main.js decide pelo cursor)
const petRect = () => [S.sx - 2 * PX, S.sy - 2 * PX, SW + 4 * PX, SH + 2 * PX]
const bubRect = () => [Balloon.x, Balloon.y, Balloon.w, Balloon.boxH + 3 * BB]
const inside = (r, x, y) => x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3]

C.addEventListener('contextmenu', e => { e.preventDefault(); window.clawd.menu() })
C.addEventListener('mousedown', e => {
  if (e.button !== 0) return
  if (Balloon.active && inside(bubRect(), e.clientX, e.clientY)) { Hide_Bubble(); return }
  if (!inside(petRect(), e.clientX, e.clientY) || !Test_Alive()) return
  if (e.detail >= 2) { S.drag = false; S.pendingClick = 0; Show_Input(); return }
  S.drag = true; S.moved = false
  S.dragMood = pick(['scared', 'excited', 'surprised'])
  S.offX = e.clientX - S.sx; S.offY = e.clientY - S.sy
  S.downX = S.lastX = e.clientX; S.downY = S.lastY = e.clientY
  S.dvx = 0; S.dvy = 0
})
addEventListener('mousemove', e => {
  const x = e.clientX, y = e.clientY
  if (!S.drag) {
    if (e.buttons || !Test_Alive() || !inside(petRect(), x, y)) return
    const d = Math.abs(x - S.lastHX) + Math.abs(y - S.lastHY)
    if (S.tick - S.hoverTick < 15) S.petAcc += d; else S.petAcc = 0
    S.lastHX = x; S.lastHY = y; S.hoverTick = S.tick
    if (S.petAcc > 400) { S.petAcc = 0; Invoke_Pet() }
    return
  }
  S.dvx = x - S.lastX; S.dvy = y - S.lastY
  S.lastX = x; S.lastY = y
  if (!S.moved && Math.abs(x - S.downX) + Math.abs(y - S.downY) > 4) {
    S.moved = true
    if (S.state === 'sleep') Set_State('idle')
    if (rnd(100) < 45) Say(Line('carregado'))
  }
  if (S.moved) { S.sx = x - S.offX; S.sy = y - S.offY; S.vx = 0; S.vy = 0; Update_Bubble() }
})
addEventListener('mouseup', e => {
  if (e.button !== 0 || !S.drag) return
  S.drag = false
  if (S.moved) {
    S.vx = clamp(S.dvx, -40, 40); S.vy = clamp(S.dvy, -40, 40)
    Set_State('idle')
    if (Math.hypot(S.dvx, S.dvy) > 18) {
      S.thrown = true; Set_Mood('scared', 999)
      if (rnd(2) === 0) Say(Line('arremessado'), 2)
    } else if (rnd(100) < 30) Say(Line('solto'))
  } else S.pendingClick = 18   // espera pra ver se e duplo clique
})

// ---------- velhice e morte (PC parado) ----------
function Step_Aging() {
  if (S.state === 'revive') {
    S.deadT++
    // o fantasminha mergulha de volta na cova, a lapide treme e ele pula pra fora
    if (S.ghostOn) {
      S.gx += ((OX + 4) - S.gx) * 0.2; S.gy += ((OY + 3) - S.gy) * 0.2
      if (S.deadT >= 25) S.ghostOn = false
    }
    if (S.deadT >= 50) {
      S.age = 0; S.wasOld = false
      Set_State('idle'); Invoke_Hop(); Set_Mood('surprised', 60)
      Say(Line('reviveu'), 2)
    }
    return
  }
  if (S.state === 'dead') {
    S.deadT++
    if (S.deadT === 30) Emit('sweat')
    if (S.deadT >= 50) {
      // fantasminha sai do corpo e fica assombrando a lapide
      const gt = S.deadT - 50
      const hx = OX + 4 + 7 * Math.sin(gt * 0.025), hy = OY - 9 + Math.sin(gt * 0.1)
      const k = Math.min(1, gt / 80)
      S.gx = (OX + 4) + (hx - (OX + 4)) * k
      S.gy = (OY + 2) + (hy - (OY + 2)) * k
      S.ghostOn = true
      if (gt === 90 || (gt > 90 && gt % 500 === 0 && rnd(100) < 70)) Say(Line('fantasma'))
    }
    if (idle < 2 && S.deadT > 30) { S.state = 'revive'; S.deadT = 0; Hide_Bubble() }
    return
  }
  if (!CFG.envelhecer) { S.age = 0; return }

  const total = CFG.morte_min * 60, start = total * 0.4
  if (idle < 2) {
    // voltou: rejuvenesce rapidinho
    if (S.age > 0) {
      S.age = Math.max(0, S.age - 0.03)
      if (S.wasOld && S.age === 0) { S.wasOld = false; Set_Mood('happy', 60); Say(Line('rejuvenesceu'), 2) }
    }
    return
  }
  const target = clamp((idle - start) / (total - start), 0, 1)
  if (target > S.age) S.age = target
  if (S.age >= 0.3) S.wasOld = true
  if (S.age >= 0.3 && S.state === 'sleep') Set_State('idle')
  if (S.age >= 0.3 && S.tick % 450 === 0 && !Balloon.active && rnd(100) < 60) Say(Line('velho'))
  if (S.age >= 1) {
    S.state = 'dead'; S.deadT = 0; S.vx = 0; S.drag = false; S.ghostOn = false
    Parts.length = 0
    Hide_Bubble(); Say(Line('morrendo'), 3)
  }
}

// ---------- loop principal ----------
function Step_Tick() {
  S.tick++
  const t = S.tick
  if (S.blink > 0) S.blink--; else if (rnd(110) === 0) S.blink = 4
  if (S.moodT > 0 && S.moodT < 999) S.moodT--
  if (S.squash > 0) S.squash--
  if (S.pendingClick > 0) { S.pendingClick--; if (S.pendingClick === 0) Invoke_Poke() }
  Step_Aging()

  // necessidades
  if (t % 100 === 0) {
    const h = new Date().getHours()
    if (S.state === 'sleep') S.energy += 2
    else { S.energy -= (h >= 23 || h < 6) ? 0.35 : 0.15; S.social -= 0.5 }
    S.energy = clamp(S.energy, 0, 100); S.social = clamp(S.social, 0, 100)
  }

  if (!S.drag) {
    const ground = area.h, maxX = area.w - SW
    const foot = S.sy + SH
    if (S.vy < 0 || foot < ground - 0.5) {
      // no ar
      S.vy = Math.min(S.vy + GRAV, 40)
      let nsy = S.sy + S.vy
      S.sx += S.vx; S.vx *= 0.99
      if (nsy < 0) { nsy = 0; if (S.vy < 0) S.vy = 0 }
      if (S.vy > 0 && nsy + SH >= ground) { S.sy = ground - SH; Land(S.vy) }
      else S.sy = nsy
    } else {
      S.sy = ground - SH
      if (Math.abs(S.vx) > 0.3) { S.sx += S.vx; S.vx *= 0.85 }
      else { S.vx = 0; Step_Behavior() }
    }
    if (S.sx < 0) { S.sx = 0; S.vx = -S.vx * 0.5; S.dir = 1 }
    if (S.sx > maxX) { S.sx = maxX; S.vx = -S.vx * 0.5; S.dir = -1 }
  }

  // para onde olhar
  if (['walk', 'run', 'seek'].includes(S.state)) { S.look = S.dir; S.lookY = 0 }
  else {
    const dx = cursor.x - (S.sx + SW / 2), dy = cursor.y - (S.sy + SH / 2)
    if (Math.abs(dx) < 600 && Math.abs(dy) < 500) {
      S.look = Math.abs(dx) > 25 ? sign(dx) : 0
      S.lookY = dy < -60 ? -1 : 0
    } else S.lookY = 0
  }

  // falas espontaneas
  if (t === 40) {
    const h = new Date().getHours()
    Say(Line(h < 5 ? 'madrugada' : h < 12 ? 'saudacao_manha' : h < 18 ? 'saudacao_tarde' : 'saudacao_noite'))
    Set_State('wave'); Set_Mood('happy', 60)
  }
  // espiada espontanea na tela (a cada 20-40 min)
  if (t >= S.nextPeek) {
    S.nextPeek = t + rndr(40000, 80000)
    if (CFG.espiar && !Balloon.active && !Chat.busy && S.state !== 'sleep' && Test_Alive()) Start_Peek()
  }
  if (t >= S.nextChatter) {
    S.nextChatter = t + rndr(3000, 7000)
    if (!Balloon.active && !Chat.busy && S.state !== 'sleep' && Test_Alive()) {
      const e = Get_Expr()
      let k = 'aleatorio_neutro'
      if (e === 'sad') k = pick(['triste', 'solitario'])
      else if (e === 'sleepy') k = 'sono'
      else if (e === 'happy' || e === 'love' || S.social > 70) k = 'aleatorio_feliz'
      if (new Date().getHours() < 5 && rnd(2) === 0) k = 'madrugada'
      Say(Line(k))
    }
  }

  Step_Particles()

  // balao
  if (Balloon.active) {
    if (Chat.busy && Chat.kind === 'chat' && Balloon.hold && t % 12 === 0) { Balloon.text = '.'.repeat(1 + (t / 12) % 3); Balloon.lines = [Balloon.text] }
    if (Balloon.shown < Balloon.text.length) Balloon.shown += 2
    else if (!Balloon.hold) { Balloon.life--; if (Balloon.life <= 0) Hide_Bubble() }
    Update_Bubble()
  }

  const inputOpen = inpBox.style.display === 'block'
  const rects = [petRect()]
  if (Balloon.active) rects.push(bubRect())
  if (inputOpen) rects.push([inpBox.offsetLeft, inpBox.offsetTop, inpBox.offsetWidth, inpBox.offsetHeight])
  window.clawd.hit({ rects: rects.map(r => r.map(Math.round)), capture: S.drag || inputOpen })
  Draw()
}

// ---------- comandos do menu e da bandeja ----------
window.clawd.onAction((a, v) => {
  switch (a) {
    case 'chat': if (Test_Alive()) Show_Input(); break
    case 'hop': if (Test_Alive()) Invoke_Hop(); break
    case 'dance': if (Test_Alive()) { Set_State('dance'); Set_Mood('happy', 100) } break
    case 'sleep': if (Test_Alive()) Set_State('sleep'); break
    case 'peek': Start_Peek(); break
    case 'forget': Chat.hist = []; Say(Line('esqueci')); break
    case 'config': CFG = v; break
    case 'called': if (Test_Alive()) { Invoke_Hop(); Say(Line('bandeja')) } break
    case 'update': {
      Balloon.prio = 0
      if (v === 'baixando' || v === 'instalando') { Say(Line('atualizando'), 3); Set_Mood('excited', 100) }
      else if (v === 'baixar') { Say(Line('versao_nova'), 2); Set_Mood('excited', 100) }
      else if (v === 'atualizado') { Say(Line('atualizado'), 2); Set_Mood('happy', 60) }
      else Say(Line('sem_atualizacao'), 2)
      break
    }
  }
})
window.clawd.onPump(p => { cursor.x = p.x; cursor.y = p.y; idle = p.idle })

function fitCanvas() {
  const dpr = devicePixelRatio || 1
  area = { w: innerWidth, h: innerHeight }
  C.width = Math.round(area.w * dpr); C.height = Math.round(area.h * dpr)
  C.style.width = area.w + 'px'; C.style.height = area.h + 'px'
  G.setTransform(dpr, 0, 0, dpr, 0, 0)
  G.imageSmoothingEnabled = false
}
addEventListener('resize', fitCanvas)

window.clawd.init().then(d => {
  Falas = d.falas; CFG = d.cfg; hasAI = d.hasAI; aiImg = d.aiImg
  Chat.hist = Array.isArray(d.hist) ? d.hist.filter(h => h && h.r && h.t) : []
  fitCanvas()
  S.sx = rnd(Math.max(1, area.w - SW)); S.sy = area.h - SH
  Make_TrayIcons()
  setInterval(() => {
    try { Step_Tick() } catch (e) {
      if (S.tick - S.lastErr > 100) { S.lastErr = S.tick; window.clawd.log(String(e && e.stack || e)) }
    }
  }, 30)
})
