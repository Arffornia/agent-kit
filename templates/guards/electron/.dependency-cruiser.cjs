/**
 * Architecture guard for the Electron launcher (agent-kit template). Copy to the repo root.
 * Process boundaries: renderer (Vue, untrusted web content) <-> preload (window.api only) <-> main (Node).
 * Run: make arch   (see templates/guards/README.md). `err-long` prints each rule's comment = how to fix.
 * Existing offenders: .dependency-cruiser-known-violations.json (generated); new violations fail.
 * @type {import('dependency-cruiser').IConfiguration}
 */
module.exports = {
  forbidden: [
    {
      name: 'renderer-not-to-main',
      severity: 'error',
      comment:
        'The renderer must not import main-process code (it gets bundled into the web page and duplicates state). ' +
        'Fix: expose what you need through a window.api method in src/preload/index.js backed by an ipcMain.handle, ' +
        'or move pure constants/helpers to src/shared/ and import them from both sides.',
      from: { path: '^src/renderer/' },
      to: { path: '^src/main/' }
    },
    {
      name: 'renderer-not-to-preload',
      severity: 'error',
      comment:
        'The renderer reaches the preload only through window.api at run time. Fix: call window.api.<method>() instead of importing src/preload.',
      from: { path: '^src/renderer/' },
      to: { path: '^src/preload/' }
    },
    {
      name: 'renderer-no-node-or-electron',
      severity: 'error',
      comment:
        'The renderer is sandboxed web content: no Node built-ins and no electron module. ' +
        'Fix: do the file/OS/process work in src/main, expose it via a validated IPC handler and a window.api method.',
      from: { path: '^src/renderer/' },
      to: { dependencyTypes: ['core'] }
    },
    {
      name: 'renderer-no-electron-module',
      severity: 'error',
      comment:
        'Do not import "electron" in the renderer. Fix: go through window.api (preload) and ipcMain.handle (main).',
      from: { path: '^src/renderer/' },
      to: { path: '^(electron$|node_modules/electron/)' }
    },
    {
      name: 'main-not-to-renderer',
      severity: 'error',
      comment:
        'Main must not import renderer code (Vue components, stores). ' +
        'Fix: send data to the renderer with webContents.send / a preload subscription, or move shared code to src/shared/.',
      from: { path: '^src/main/' },
      to: { path: '^src/renderer/' }
    },
    {
      name: 'main-not-to-preload',
      severity: 'error',
      comment:
        'Main must not import the preload script. Fix: move shared channel names/types to src/shared/.',
      from: { path: '^src/main/' },
      to: { path: '^src/preload/' }
    },
    {
      name: 'preload-minimal-imports',
      severity: 'error',
      comment:
        'The preload may import only "electron" (contextBridge, ipcRenderer) and src/shared/. ' +
        '@electron-toolkit/preload exposes the raw ipcRenderer (any channel) to the page. ' +
        'Fix: expose one curated window.api with one method per channel; never expose ipcRenderer itself.',
      from: { path: '^src/preload/' },
      to: { pathNot: '^(electron$|node_modules/electron/|src/preload/|src/shared/)' }
    },
    {
      name: 'no-circular',
      severity: 'warn',
      comment:
        'Circular imports make module init order matter (e.g. main modules importing "." back for logger). ' +
        'Fix: move the shared thing (logger, settings, notify) into its own module that imports nothing back.',
      from: {},
      to: { circular: true }
    }
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    exclude: { path: '^(out|dist)/' },
    tsPreCompilationDeps: false,
    combinedDependencies: false,
    enhancedResolveOptions: {
      exportsFields: ['exports'],
      conditionNames: ['import', 'require', 'node', 'default'],
      extensions: ['.js', '.mjs', '.cjs', '.ts', '.vue', '.json']
    },
    // Path aliases (e.g. '@renderer') are not resolved; if code ever imports main/preload through an
    // alias, add a jsconfig.json with `paths` and point `tsConfig: { fileName: 'jsconfig.json' }` at it.
    reporterOptions: { text: { highlightFocused: true } }
  }
}
