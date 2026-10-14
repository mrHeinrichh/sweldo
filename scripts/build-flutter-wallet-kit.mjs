import { build } from 'vite'
import { fileURLToPath } from 'node:url'

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
