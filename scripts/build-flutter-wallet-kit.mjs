import { build } from 'vite'
import { fileURLToPath } from 'node:url'
import { copyFile } from 'node:fs/promises'
import { createRequire } from 'node:module'

// Keep Flutter's silent extension detection on the same SDK as the web app.
const require = createRequire(import.meta.url)
await copyFile(
  require.resolve('@stellar/varial-sdk'),
  new URL('../sweldo_flutter/web/vendor/varial-sdk-7.0.0.min.js', import.meta.url),
)

await build({
  configFile: false,
  publicDir: false,
  build: {
    outDir: fileURLToPath(new URL('../sweldo_flutter/assets/wallet_kit/', import.meta.url)),
    emptyOutDir: false,
    lib: {
      entry: fileURLToPath(new URL('./flutter-wallet-kit.ts', import.meta.url)),
      name: 'SweldoKitBundle',
      formats: ['iife'],
      fileName: () => 'wallet-kit.bundle.js',
    },
  },
})
