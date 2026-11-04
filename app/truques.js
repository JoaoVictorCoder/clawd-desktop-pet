// 32 truques aleatorios do Clawd (porte do truques.ps1). Cada um e um objeto com:
//   init(k)        ao comecar
//   step(k)        todo tick (inclusive no ar)
//   pose(grid, k)  mexe no sprite (bracos, rosto)
//   draw(k, grid)  desenha objetos por cima
// k guarda o estado do truque: t (ticks), dur, sit, flip, hide, dark, walk, expr, look, d (dados livres)
// Carregado pelo index.html depois do pet.js.
'use strict'

Object.assign(BR, {
  F: 'rgb(255,105,180)',  // rosa chiclete
  E: 'rgb(60,60,72)',     // plastico escuro / tostado pelo raio
  H: 'rgb(205,210,220)',  // linha / vapor / moldura
  Q: 'rgb(150,40,50)',    // vaso
  V: 'rgb(50,120,55)',    // folha escura
  S: 'rgb(180,220,255)'   // vidro
})
EYES.zen = EYES.closed
EYES.focused = EYES.angry   // cara de concentrado, sem os simbolos de raiva

Object.assign(PAT, {
  drop: ['B', 'B'], gum: ['F'], smoke: ['GG', 'GG'], speed: ['HH'], flame: ['Y', 'R'], rocket: ['Y', 'R'],
  bubble: ['.H.', 'H.H', '.H.'], bubble2: ['.HH.', 'H..H', 'H..H', '.HH.'],
  spR: ['R'], spB: ['B'], spY: ['Y'], spN: ['N'], spL: ['L'], spF: ['F']
})

const TP = {
  gum1: ['FF', 'FF'],
  gum2: ['.FF.', 'FFFF', 'FFFF', '.FF.'],
  gum3: ['..FFF..', '.FFFFF.', 'FFWFFFF', 'FFFFFFF', 'FFFFFFF', '.FFFFF.', '..FFF..'],
  guitar: ['CCCCCCC.RRR.', 'HHHHHHHRRKRR', 'CCCCCCC.RRR.'],
  yoyo: ['.R.', 'RWR', '.R.'],
  kite: ['..R..', '.RYR.', 'RYYYR', '.RYR.', '..R..'],
  cloud: ['...HHHH.......', '.HHHHHHHHH.HH.', 'HHHHHHHHHHHHHH', '.GGGGGGGGGGGG.'],
  stormcloud: ['...GGGG.......', '.GGGGGGGGG.GG.', 'GGGGGGGGGGGGGG', '.DDDDDDDDDDDD.'],
  umbrella: ['.....RRRRRR.....', '...RRRRRRRRRR...', '.RRRRRRRRRRRRRR.', 'R.R.R.R.R.R.R.R.'],
  bolt: ['..YY', '.YY.', 'YYYY', '..YY', '.YY.', 'YY..'],
  phone: ['EEE', 'ESE', 'ESE', 'EEE'],
  flash: ['W.W.W', '.WWW.', 'WWWWW', '.WWW.', 'W.W.W'],
  pizza: ['MMMMM', 'YRYRY', '.YRY.', '..Y..'],
  icecream: ['.FFF.', 'FFFFF', 'FWFFF', '.MMM.', '.MMM.', '..M..'],
  jR: ['RR', 'RR'], jB: ['BB', 'BB'], jY: ['YY', 'YY'],
  shades: ['KKKKKKKKKKKK', '.KKKK..KKKK.'],
  hat: ['.EEE.', '.EEE.', '.RRR.', 'EEEEE'],
  rabbit: ['W.W', 'W.W', 'WWW', 'WKW', 'WWW'],
  skate: ['.MMMMMMMMMMMMMM.', '..E..........E..'],
  jetpack: ['GG', 'GG', 'GG', 'RR'],
  chute: ['....RRRRRRRR....', '..RRWWRRRRWWRR..', '.RRRRRRRRRRRRRR.', 'R..............R'],
  lens: ['.HHH.', 'HSSSH', 'HSWSH', 'HSSSH', '.HHH.'],
  can: ['HHHH.', 'HHHHH', 'HHHH.'],
  pot: ['QQQQQ', '.QQQ.', '.QQQ.'],
  flower: ['.R.', 'RYR', '.R.'],
  decks: ['.EEEEE..EEEEE.', 'EEKKKEEEEKKKEE', 'EEEEEEEEEEEEEE'],
  cell: ['EE', 'ES', 'ES', 'EE'],
  spikes: ['..L...L...L...', '.LLL.LLL.LLL..'],
  tail: ['L...', 'LLLL'],
  crack: ['..H..', '.H.H.', 'H...H', '.H...', '..H..']
}

// ---------- ajudantes ----------
// origem do quadro do Clawd no frame atual (o Draw do pet.js preenche antes de chamar draw)
const Frame = { x: 0, y: 0 }
function Seq(key, i) { const l = [].concat(Falas[key] || []); return i < l.length ? String(l[i]) : '' }
function Fill_Cell(ch, x, y) { G.fillStyle = BR[ch]; G.fillRect(Frame.x + Math.round(x) * PX, Frame.y + Math.round(y) * PX, PX, PX) }
function Pattern(pat, x, y) { Draw_Pattern(G, pat, x, y, Frame.x, Frame.y) }
function Draw_Line(ch, x0, y0, x1, y1) {
  const n = Math.ceil(Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)))
  for (let i = 0; i <= n; i++) { const q = n > 0 ? i / n : 0; Fill_Cell(ch, x0 + (x1 - x0) * q, y0 + (y1 - y0) * q) }
}
function Set_Arms(grid, aL, aR) {
  for (let r = 0; r < 8; r++) for (const c of [0, 1, 16, 17]) if (grid[r][c] === 'O') grid[r][c] = '.'
  if (aL >= 0) for (const c of [0, 1]) { grid[aL][c] = 'O'; grid[aL + 1][c] = 'O' }
  if (aR >= 0) for (const c of [16, 17]) { grid[aR][c] = 'O'; grid[aR + 1][c] = 'O' }
}
function Emit_At(k, x, y, vx, vy, life) { if (Parts.length < 25) Parts.push({ k, x, y, vx, vy, life }) }
// controla o voo: a fisica soma a gravidade depois, entao compensa aqui
function Fly(vx, vy) { S.vx = vx; S.vy = vy - GRAV }
function Burst(kind, x, y, n, spd, life) {
  for (let i = 0; i < n; i++) { const a = i * 2 * Math.PI / n; Emit_At(kind, x, y, Math.cos(a) * spd, Math.sin(a) * spd, life) }
}
const floor = Math.floor

// ---------- os 32 truques ----------
const TRK = {}

TRK.chiclete = { dur: 170,
  step(k) { if (k.t === 100) { Say('POP!', 2); Set_Mood('surprised', 50); Burst('gum', OX + 9, OY + 5, 8, 0.3, 10) } },
  draw(k) {
    if (k.t < 100) {
      const g = TP['gum' + Math.min(3, 1 + floor(k.t / 33))]
      Pattern(g, OX + 9 - g[0].length / 2, OY + 5 - g.length / 2)
    } else {
      for (const c of [[5, 4], [7, 5], [8, 4], [10, 6], [11, 4], [12, 5], [9, 6], [6, 6]]) Fill_Cell('F', OX + c[0], OY + c[1])
    }
  }
}

TRK.espirro = { dur: 130,
  init(k) { k.expr = 'sleepy' },
  step(k) {
    if (k.t === 40) Say('A... a...')
    if (k.t === 85) {
      Say('ATCHIM!', 2); k.expr = 'surprised'
      S.vx = -S.dir * 9
      for (let i = 0; i < 5; i++) Emit_At('drop', OX + 9 + S.dir * 6, OY + 5, S.dir * (0.3 + Math.random() * 0.3), (Math.random() - 0.5) * 0.2, 12)
    }
  }
}

TRK.soluco = { dur: 260,
  step(k) {
    if (k.t % 45 === 20) { Invoke_Jump(-4); Say('hic!'); k.expr = 'surprised' }
    else if (k.t % 45 === 35) k.expr = null
  }
}

TRK.guitarra = { dur: 280,
  init(k) { k.expr = 'excited' },
  step(k) { if (k.t % 18 === 0) Emit('note'); if (k.t % 36 === 0) Invoke_Jump(-3) },
  pose(grid, k) { Set_Arms(grid, 5, 4 + floor(k.t / 4) % 3) },
  draw() { Pattern(TP.guitar, OX + 2, OY + 5) }
}

TRK.ioio = { dur: 240,
  draw(k) {
    const len = Math.trunc(5 + 5 * Math.sin(k.t * 0.12))
    for (let i = 0; i < len; i++) Fill_Cell('H', OX + 17, OY + 6 + i)
    Pattern(TP.yoyo, OX + 16, OY + 6 + len)
  }
}

TRK.pipa = { above: 12, dur: 320,
  init(k) { k.expr = 'happy'; k.look = 1 },
  pose(grid) { Set_Arms(grid, 4, 2) },
  draw(k) {
    const kx = OX + 18 + 1.5 * Math.sin(k.t * 0.05), ky = OY - 11 + Math.sin(k.t * 0.08)
    Draw_Line('H', OX + 17, OY + 2, kx + 2, ky + 4)
    Pattern(TP.kite, kx, ky)
    for (let i = 1; i <= 3; i++) Fill_Cell(['Y', 'R'][i % 2], kx + 2 + Math.sin(k.t * 0.2 + i), ky + 4 + i)
  }
}

TRK.chuva = { above: 10, dur: 320,
  init(k) { k.expr = 'sad' },
  step(k) {
    if (k.t % 3 === 0) Emit_At('drop', OX + 3 + rnd(12), OY - 6, 0, 0.5, k.t > 110 ? 4 : 14)
    if (k.t === 60) Say(Seq('tr_chuva_seq', 0))
    if (k.t === 110) { k.expr = 'happy'; Say(Seq('tr_chuva_seq', 1)) }
  },
  pose(grid, k) { if (k.t > 110) Set_Arms(grid, 4, 2) },
  draw(k) {
    Pattern(TP.cloud, OX + 2, OY - 10)
    if (k.t > 110) { Pattern(TP.umbrella, OX + 1, OY - 4); Draw_Line('C', OX + 16, OY - 1, OX + 16, OY + 2) }
  }
}

TRK.raio = { above: 10, dur: 240,
  init(k) { k.expr = 'thinking' },
  step(k) {
    if (k.t === 50) { k.dark = true; k.expr = 'dizzy'; Say('...', 2) }
    if (k.t > 50 && k.t < 170 && k.t % 10 === 0) Emit_At('smoke', OX + 5 + rnd(8), OY - 1, 0, -0.08, 20)
    if (k.t === 170) { k.dark = false; k.expr = 'happy'; Say(Seq('tr_raio_seq', 0)) }
  },
  draw(k) {
    if (k.t < 190) Pattern(TP.stormcloud, OX + 2, OY - 10)
    if (k.t >= 46 && k.t < 56) Pattern(TP.bolt, OX + 8, OY - 6)
  }
}

TRK.meditar = { dur: 330,
  init(k) { k.expr = 'zen'; k.sit = true },
  step(k) {
    if (k.t < 30) Fly(0, -1.2)
    else if (k.t < 280) {
      Fly(0, 0.4 * Math.sin(k.t * 0.08))
      if (k.t % 20 === 0) Emit_At('star', OX + 2 + rnd(14), OY + rnd(6), 0, -0.05, 15)
    }
  },
  pose(grid) { Set_Arms(grid, 3, 3) }
}

TRK.flexoes = { dur: 240,
  init(k) { k.expr = 'focused'; k.d.n = 0 },
  step(k) {
    k.sit = floor(k.t / 20) % 2 === 1
    if (k.t > 0 && k.t % 40 === 0) { k.d.n++; Say(String(k.d.n)) }
    if (k.t % 60 === 30) Emit('sweat')
  },
  pose(grid, k) { if (k.sit) Set_Arms(grid, 6, 6); else Set_Arms(grid, 5, 5) }
}

TRK.corda = { above: 4, dur: 290,
  init(k) { k.expr = 'happy' },
  step(k) { if (k.t % 24 === 0) Invoke_Jump(-6.5) },
  draw(k) {
    const depth = (k.t % 24) < 12 ? 6 : -8
    for (let x = 0; x <= 17; x++) Fill_Cell('M', OX + x, OY + 5 + depth * Math.sin(Math.PI * x / 17))
  }
}

TRK.malabares = { above: 8, dur: 280,
  pose(grid, k) { const u = floor(k.t / 8) % 2; Set_Arms(grid, 2 + 2 * u, 4 - 2 * u) },
  draw(k) {
    const jcol = ['jR', 'jB', 'jY']
    for (let i = 0; i < 3; i++) {
      const a = k.t * 0.15 + i * 2.094
      Pattern(TP[jcol[i]], OX + 8 + 7 * Math.cos(a), OY - 4 + 3 * Math.sin(a))
    }
  }
}

TRK.selfie = { above: 6, dur: 170,
  init(k) { k.expr = 'happy'; k.look = 1 },
  step(k) { if (k.t === 70) Say('Xis!'); if (k.t === 120) Say(Seq('tr_selfie_seq', 0)) },
  pose(grid) { Set_Arms(grid, 4, 1) },
  draw(k) {
    Pattern(TP.phone, OX + 17, OY - 4)
    if (k.t >= 90 && k.t < 96) Pattern(TP.flash, OX + 16, OY - 5)
  }
}

TRK.pizza = { dur: 200,
  init(k) { k.look = 1 },
  step(k) { if (k.t % 45 === 30) { Say('Nham!'); k.expr = 'happy' } },
  pose(grid, k) { Set_Arms(grid, 4, (k.t % 45) >= 22 ? 2 : 4) },
  draw(k) {
    const left = 4 - floor(k.t / 45)
    if (left > 0) {
      let x = OX + 16, y = OY + 3
      if ((k.t % 45) >= 22) { x = OX + 13; y = OY + 2 }   // levando a boca
      Pattern(TP.pizza.slice(0, left), x, y)
    }
  }
}

TRK.sorvete = { above: 2, dur: 230,
  init(k) { k.look = 1; k.expr = 'happy' },
  step(k) {
    if (k.t % 30 === 0) Emit_At('gum', OX + 17, OY + 5, 0, 0.25, 10)
    if (k.t === 140) { Say('Brain freeze!', 2); Set_Mood('dizzy', 50) }
  },
  pose(grid) { Set_Arms(grid, 4, 3) },
  draw() { Pattern(TP.icecream, OX + 15, OY - 1) }
}

TRK.bolhas = { above: 6, dur: 260,
  init(k) { k.expr = 'happy'; k.look = 1 },
  step(k) {
    if (k.t % 12 === 0) Emit_At(pick(['bubble', 'bubble2']), OX + 18, OY - 2, 0.08 + Math.random() * 0.12, -0.05 - Math.random() * 0.06, 70)
  },
  pose(grid) { Set_Arms(grid, 4, 3) },
  draw() { Draw_Line('C', OX + 17, OY + 3, OX + 18, OY + 1); Pattern(PAT.bubble, OX + 18, OY - 2) }
}

TRK.fogos = { above: 12, dur: 230,
  init(k) { k.expr = 'excited'; k.d.boom = [] },
  step(k) {
    if (k.t === 20 || k.t === 80 || k.t === 140) { Emit_At('rocket', OX + 9, OY - 1, 0, -0.45, 18); k.d.boom.push(k.t + 18) }
    if (k.d.boom.includes(k.t)) {
      Burst(pick(['spR', 'spB', 'spY', 'spN', 'spL', 'spF']), OX + 9 + rndr(-3, 4), OY - 9, 12, 0.25, 18)
      if (k.t < 100) Say(Seq('tr_fogos_seq', 0))
    }
  }
}

TRK.oculos = { dur: 230,
  step(k) { if (k.t === 110) Say(Seq('tr_oculos_seq', 0)) },
  draw(k) {
    const dy = k.t < 15 ? -(15 - k.t) / 2 : 0   // oculos descendo
    Pattern(TP.shades, OX + 3, OY + 2 + dy)
    const gx = OX + 4 + floor(k.t / 3) % 14
    if (gx <= OX + 14) Fill_Cell('W', gx, OY + 2 + dy)   // brilho passando
  }
}

TRK.magica = { above: 2, dur: 260,
  init(k) { k.look = 1 },
  step(k) {
    if (k.t === 60) { Say('Abracadabra!'); for (let i = 0; i < 6; i++) Emit_At('star', OX + 19 + rnd(5), OY + 3 + rnd(3), (Math.random() - 0.5) * 0.2, -0.1, 15) }
    if (k.t === 95) { Say('Tcharam!', 2); k.expr = 'excited' }
  },
  pose(grid, k) { Set_Arms(grid, 4, k.t >= 50 && k.t < 70 && (k.t % 6) < 3 ? 1 : 2) },
  draw(k) {
    if (k.t >= 70) {
      let rx = OX + 20, ry = Math.max(OY + 1, OY + 6 - (k.t - 70) * 0.3)
      if (k.t >= 140) { rx += (k.t - 140) * 0.12; ry = OY + 5 - Math.abs(Math.sin((k.t - 140) * 0.2)) * 2 }   // sai pulando
      if (rx < 30) Pattern(TP.rabbit, rx, ry)
    }
    Pattern(TP.hat, OX + 19, OY + 6)
    Draw_Line('K', OX + 17, OY + 2, OX + 19, OY); Fill_Cell('W', OX + 19, OY - 1)
  }
}

TRK.teleporte = { dur: 110,
  step(k) {
    if (k.t < 60 && k.t % 3 === 0) Emit_At('star', OX + 2 + rnd(14), OY + rnd(10), 0, -0.05, 10)
    if (k.t === 20) k.hide = true
    if (k.t === 40) { S.vx = 0; S.vy = 0; S.sx = rnd(Math.max(1, area.w - SW)); S.sy = area.h - SH }
    if (k.t === 60) { k.hide = false; Say(Seq('tr_teleporte_seq', 0)) }
  }
}

TRK.clone = { above: 11, dur: 210,
  step(k) {
    if (k.t === 10 || k.t === 185) for (let i = 0; i < 6; i++) Emit_At('star', OX + 2 + rnd(14), OY - 10 + rnd(10), 0, -0.05, 12)
    if (k.t === 25) { k.expr = 'surprised'; Say(Seq('tr_clone_seq', 0)) }
    if (k.t === 100) { k.expr = 'happy'; Say(Seq('tr_clone_seq', 1)) }
  },
  draw(k, grid) {
    if (k.t < 12 || k.t >= 188) return
    // um clone espelhado em pe na cabeca dele
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const ch = grid[r][COLS - 1 - c]
        if (ch === '.') continue
        G.fillStyle = ch === 'O' ? AGEBR[0] : BR[ch]
        G.fillRect(Frame.x + (OX + c) * PX, Frame.y + (OY - 10 + r) * PX, PX, PX)
      }
    }
  }
}

TRK.skate = { dur: 280,
  init(k) { k.expr = 'excited'; S.dir = pick([-1, 1]) },
  step(k) {
    k.look = S.dir
    if (S.vy === 0) Move_Walk(S.speed * 3.5)
    if (k.t % 3 === 0) Emit_At('speed', OX + 9 - S.dir * 10, OY + 4 + rnd(4), -S.dir * 0.2, 0, 6)
  },
  draw() { Pattern(TP.skate, OX + 1, OY + 9) }
}

TRK.jetpack = { dur: 360,
  init(k) { k.expr = 'excited' },
  step(k) {
    if (k.t < 260) {
      if (k.t % 2 === 0) Emit_At('flame', OX - 1.5, OY + 7, 0, 0.25, 6)
      if (k.t < 50) Fly(0, -3)
      else Fly(3 * Math.cos((k.t - 50) * 0.03), 1.2 * Math.sin((k.t - 50) * 0.06))
      if (k.t === 60) Say(Seq('tr_jetpack_seq', 0))
    } else if (k.t > 265 && S.vy === 0) End_Trick('tr_jetpack_fim')
  },
  draw() { Pattern(TP.jetpack, OX - 2, OY + 3) }
}

TRK.paraquedas = { above: 10, dur: 1500,
  init(k) { S.sy = 5; S.vy = 0; k.expr = 'happy' },
  step(k) {
    if (k.t > 15 && S.sy + SH >= area.h - 1) { End_Trick('tr_paraquedas_fim'); return }
    Fly(1.2 * Math.sin(k.t * 0.04), 1.3)
  },
  pose(grid) { Set_Arms(grid, 2, 2) },
  draw() {
    Pattern(TP.chute, OX + 1, OY - 9)
    Draw_Line('H', OX + 1, OY - 5, OX + 1, OY + 1)
    Draw_Line('H', OX + 16, OY - 5, OX + 16, OY + 1)
  }
}

TRK.lupa = { dur: 300,
  init(k) { k.walk = true; S.dir = pick([-1, 1]) },
  step(k) {
    k.look = S.dir
    if (S.vy === 0) Move_Walk(S.speed * 0.5)
    if (k.t % 80 === 40) Say(Line('tr_lupa_meio'))
  },
  draw() {
    if (S.dir >= 0) { Pattern(TP.lens, OX + 16, OY + 1); Draw_Line('C', OX + 18, OY + 6, OX + 17, OY + 8) }
    else { Pattern(TP.lens, OX - 3, OY + 1); Draw_Line('C', OX - 1, OY + 6, OX, OY + 8) }
  }
}

TRK.planta = { dur: 340,
  init(k) { k.look = 1 },
  step(k) { if (k.t < 260 && k.t % 6 === 0) Emit_At('drop', OX + 21 + Math.random(), OY + 5, 0.05, 0.3, 6) },
  pose(grid) { Set_Arms(grid, 4, 3) },
  draw(k) {
    Pattern(TP.can, OX + 16, OY + 2)
    const h = Math.min(6, floor(k.t / 40))
    for (let i = 1; i <= h; i++) Fill_Cell('L', OX + 23, OY + 7 - i)
    if (h >= 3) { Fill_Cell('V', OX + 22, OY + 4); Fill_Cell('V', OX + 24, OY + 5) }
    if (h >= 6) Pattern(TP.flower, OX + 22, OY - 1)
    Pattern(TP.pot, OX + 21, OY + 7)
  }
}

TRK.pintar = { dur: 340,
  init(k) { k.look = 1; k.d.cv = Array(48).fill('W') },
  step(k) { if (k.t % 8 === 0 && k.t < 300) k.d.cv[rnd(48)] = pick(['R', 'B', 'Y', 'L', 'N', 'F']) },
  pose(grid, k) { Set_Arms(grid, 4, 2 + floor(k.t / 5) % 3) },
  draw(k) {
    const ex = OX + 20, ey = OY + 1
    Draw_Line('C', ex + 1, ey + 6, ex, OY + 9); Draw_Line('C', ex + 6, ey + 6, ex + 7, OY + 9)
    for (let i = 0; i < 48; i++) Fill_Cell(k.d.cv[i], ex + (i % 8), ey + floor(i / 8))
    Draw_Line('M', ex - 1, ey - 1, ex + 8, ey - 1); Draw_Line('M', ex - 1, ey + 6, ex + 8, ey + 6)
    Fill_Cell('C', OX + 18, OY + 2); Fill_Cell('R', OX + 19, OY + 2)   // pincel
  }
}

TRK.dj = { above: 2, dur: 320,
  init(k) { k.expr = 'happy'; k.look = 0 },
  step(k) {
    if (k.t % 16 === 0) Emit('note')
    if (k.t % 24 === 0) Invoke_Jump(-3)
    if (k.t === 120) Say(Seq('tr_dj_seq', 0))
  },
  pose(grid, k) { const u = floor(k.t / 6) % 2; Set_Arms(grid, 5 + u, 6 - u) },
  draw(k) {
    Pattern(TP.decks, OX + 2, OY + 6)
    const sp = floor(k.t / 3) % 3   // discos girando
    Fill_Cell('W', OX + 4 + sp, OY + 7); Fill_Cell('W', OX + 13 - sp, OY + 7)
    Draw_Line('E', OX + 2, OY - 1, OX + 15, OY - 1)   // fone
    for (const hx of [OX + 1, OX + 16]) { Fill_Cell('R', hx, OY + 2); Fill_Cell('R', hx, OY + 3) }
  }
}

TRK.telefone = { dur: 270,
  init(k) { k.look = -1 },
  step(k) {
    if (k.t < 40 && k.t % 8 === 0) Emit_At('bang', OX - 2, OY + 1, 0, -0.05, 6)
    for (const [t, i] of [[45, 0], [110, 1], [170, 2], [230, 3]]) if (k.t === t) Say(Seq('tr_telefone_seq', i))
    if (k.t === 230) k.expr = 'sad'
  },
  pose(grid, k) { if (k.t >= 40) Set_Arms(grid, 1, 4) },
  draw(k) {
    if (k.t < 40) Pattern(TP.cell, OX - 3 + (k.t % 2), OY + 6)   // tocando no chao
    else Pattern(TP.cell, OX + 1, OY + 1)
  }
}

TRK.dino = { above: 3, dur: 240,
  step(k) {
    if (k.t === 60) { Say('RAWR!', 2); k.expr = 'focused'; Invoke_Jump(-5); Emit('bang') }
    if (k.t === 100) k.expr = 'happy'
  },
  pose(grid, k) {
    for (let c = 2; c <= 15; c++) { grid[0][c] = 'L'; grid[1][c] = 'L' }   // capuz
    if (k.t >= 60 && k.t < 100) Set_Arms(grid, 1, 1)
  },
  draw(k) {
    Pattern(TP.spikes, OX + 2, OY - 2)
    Pattern(TP.tail, OX - 4, OY + 5 + floor(k.t / 10) % 2)
  }
}

TRK.toctoc = { above: 2, dur: 230,
  init(k) { k.look = 0 },
  step(k) {
    if (k.t < 120 && k.t % 20 === 0) Emit_At('bang', OX + 19, OY + 1, 0, -0.05, 8)
    if (k.t === 70) Say(Seq('tr_toctoc_seq', 0))
    if (k.t === 140) { k.expr = 'surprised'; Say(Seq('tr_toctoc_seq', 1)) }
  },
  pose(grid, k) { const knock = k.t < 120 && floor(k.t / 10) % 2 === 0; Set_Arms(grid, 4, knock ? 2 : 3) },
  draw(k) { if (k.t >= 130) Pattern(TP.crack, OX + 19, OY - 1) }
}

TRK.breakdance = { dur: 230,
  init(k) { k.flip = true; k.expr = 'excited' },
  step(k) {
    if (k.t % 15 === 0) Emit('note')
    if (k.t % 40 === 20) Invoke_Jump(-4)
    if (k.t === 225) Set_Mood('dizzy', 70)
  },
  pose(grid, k) { const u = floor(k.t / 6) % 2; Set_Arms(grid, 2 + 4 * u, 6 - 4 * u) }
}

// ---------- motor ----------
S.trk = null; S.nextTrick = 1200

function Start_Trick(name) {
  if (!Test_Alive() || S.age > 0.5 || S.drag || !TRK[name]) return false
  const def = TRK[name]
  const k = { name, t: 0, dur: def.dur, sit: false, flip: false, hide: false, dark: false, walk: false, expr: null, look: null, d: {} }
  S.trk = k; S.state = 'trick'
  S.nextTrick = S.tick + rndr(1800, 4500)
  if (def.init) def.init(k)
  Say(Line('tr_' + name))
  return true
}

function End_Trick(key) {
  if (key) Say(Line(key))
  S.trk = null
  if (S.state === 'trick') Set_State('idle')
}

// todo tick, antes da fisica (por isso os truques podem voar)
function Step_Trick() {
  const k = S.trk
  if (!k) { Set_State('idle'); return }
  const def = TRK[k.name]
  if (def.step) def.step(k)
  if (S.trk !== k) return
  k.t++
  if (k.t >= k.dur) End_Trick('tr_' + k.name + '_fim')
}

function Set_TrickPose(grid) {
  const k = S.trk
  if (k && TRK[k.name].pose) TRK[k.name].pose(grid, k)
}

function Draw_TrickProps(fx, fy, grid) {
  if (S.state !== 'trick' || !S.trk) return
  Frame.x = fx; Frame.y = fy
  const k = S.trk
  if (TRK[k.name].draw) TRK[k.name].draw(k, grid)
}

function Try_StartTrick() {
  if (S.tick < S.nextTrick || rnd(100) >= 20) return false
  return Start_Trick(pick(Object.keys(TRK)))
}

// nomes pro menu "Truques"
function Trick_Menu() {
  const labels = Falas.menu_truques || {}
  return Object.keys(TRK).map(name => [name, labels[name] || name])
}
