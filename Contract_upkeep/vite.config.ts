/// <reference types="vitest" />
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';
import environment from 'vite-plugin-environment';
import dotenv from 'dotenv';

dotenv.config();

export default defineConfig({
  root: 'src',
  build: {
    outDir: '../dist',
    emptyOutDir: true,
  },
  optimizeDeps: {
    esbuildOptions: {
      define: {
        global: 'globalThis',
      },
    },
  },
  server: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:4943',
        changeOrigin: true,
      },
    },
  },
  plugins: [
    react(),
    environment('all', { prefix: 'CANISTER_' }),
    environment('all', { prefix: 'DFX_' }),
    environment({ BACKEND_CANISTER_ID: '' }),
  ],
  test: {
    environment: 'jsdom',
    setupFiles: 'setupTests.ts',
    cache: { dir: '../node_modules/.vitest' },
  },
  define: {
    'import.meta.env.CONTRACT_ID': JSON.stringify(process.env.CANISTER_ID),
    'import.meta.env.CANISTER_ID_ICP_LEDGER_CANISTER': JSON.stringify(process.env.CANISTER_ID_ICP_LEDGER_CANISTER),
    'import.meta.env.DFX_NETWORK' : JSON.stringify(process.env.DFX_NETWORK),
    'import.meta.env.PRODUCTION': false,
    'import.meta.env.CANISTER_ID_INTERNET_IDENTITY': JSON.stringify(process.env.CANISTER_ID_INTERNET_IDENTITY)
  },
});
