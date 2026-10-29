#!/usr/bin/env node
// Guard: the preload exposes exactly one object to the page, window.api (agent-kit template).
// Fails on contextBridge.exposeInMainWorld('<anything but api>') and on window.<x> = ... in the preload.
// Usage: node tools/check-preload-exposure.mjs [preload dir]   (default src/preload)
// Temporary exceptions (pre-existing only): tools/preload-exposure-known.json, e.g. ["electron"].
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'

const dir = process.argv[2] || 'src/preload'
const knownFile = new URL('./preload-exposure-known.json', import.meta.url)
const known = existsSync(knownFile) ? JSON.parse(readFileSync(knownFile, 'utf8')) : []
const files = []
const walk = (d) => {
  for (const name of readdirSync(d)) {
    const p = join(d, name)
    if (statSync(p).isDirectory()) walk(p)
    else if (/\.(c|m)?[jt]s$/.test(name)) files.push(p)
  }
}
if (!existsSync(dir)) {
  console.log(`preload-exposure: ${dir} not found, nothing to check.`)
  process.exit(0)
}
walk(dir)

const problems = []
const seenKnown = new Set()
for (const f of files) {
  const src = readFileSync(f, 'utf8')
  src.split('\n').forEach((line, i) => {
    const at = `${relative(process.cwd(), f)}:${i + 1}`
    for (const m of line.matchAll(/exposeInMainWorld\(\s*(['"`])([^'"`]+)\1/g)) {
      if (m[2] === 'api') continue
      if (known.includes(m[2])) { seenKnown.add(m[2]); continue }
      problems.push(`${at}: exposes window.${m[2]}.`)
    }
    if (/exposeInMainWorld\(\s*[^'"`\s]/.test(line)) problems.push(`${at}: exposeInMainWorld with a computed key; use the literal 'api'.`)
    for (const m of line.matchAll(/\bwindow\.(\w+)\s*=[^=]/g)) {
      if (m[1] === 'api') continue
      if (known.includes(m[1])) { seenKnown.add(m[1]); continue }
      problems.push(`${at}: assigns window.${m[1]}.`)
    }
  })
}
for (const k of known) {
  if (!seenKnown.has(k)) console.log(`preload-exposure: "${k}" is no longer exposed; remove it from tools/preload-exposure-known.json.`)
}
if (problems.length) {
  console.error(problems.join('\n'))
  console.error(
    'fix: the page may only see window.api. Add a method to the api object in src/preload/index.js that calls ' +
      'ipcRenderer.invoke(<one channel>) and validate its arguments in the matching ipcMain.handle. Never expose ipcRenderer, ' +
      'electronAPI or webFrame. Do not add entries to preload-exposure-known.json: it only lists pre-existing debt.',
  )
  process.exit(1)
}
console.log(`preload-exposure: ok (${files.length} file(s), only window.api${known.length ? `; known debt: ${known.join(', ')}` : ''}).`)
