import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { localTestFaucetPlugin } from './scripts/local-test-faucet.mjs'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), localTestFaucetPlugin()],
  server: {
    fs: { deny: ['.env', '.env.*', '*.{crt,pem}', '**/.git/**', '**/.sweldo-local/**'] },
  },
})
