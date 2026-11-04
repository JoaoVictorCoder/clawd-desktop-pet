// ponte entre a pagina (pet.js) e o processo principal (main.js)
const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('clawd', {
  init: () => ipcRenderer.invoke('init'),
  ai: (prompt, img) => ipcRenderer.invoke('ai', prompt, img),
  snapshot: maxSide => ipcRenderer.invoke('snapshot', maxSide),
  saveHist: hist => ipcRenderer.send('save-hist', hist),
  log: m => ipcRenderer.send('log', m),
  hit: h => ipcRenderer.send('hit', h),
  focusInput: () => ipcRenderer.send('focus-input'),
  blurInput: () => ipcRenderer.send('blur-input'),
  menu: () => ipcRenderer.send('menu'),
  trayIcon: (small, big) => ipcRenderer.send('tray-icon', small, big),
  tricks: list => ipcRenderer.send('tricks', list),
  onPump: f => ipcRenderer.on('pump', (_e, p) => f(p)),
  onArea: f => ipcRenderer.on('area', (_e, a) => f(a)),
  onAction: f => ipcRenderer.on('action', (_e, a, v) => f(a, v))
})
