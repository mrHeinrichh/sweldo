import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { localTestFaucetPlugin } from './scripts/local-test-faucet.mjs'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), localTestFaucetPlugin()],
  server: {
    fs: { deny: ['.env', '.env.*', '*.{crt,pem}', '**/.git/**', '**/.sweldo-local/**'] },
    // The Flutter app, the Soroban contract and generated media sit beside
    // the web client in this repo. Watching them costs thousands of file
    // handles, and a Flutter build would reload the web page for assets it
    // has nothing to do with.
    watch: {
      ignored: [
        '**/sweldo_flutter/build/**',
        '**/sweldo_flutter/.dart_tool/**',
        '**/target/**',
        '**/tmp/**',
        '**/output/**',
        '**/outputs/**',
        '**/dist/**',
        '**/.playwright-cli/**',
        '**/.sweldo-local/**',
      ],
    },
  },
})
