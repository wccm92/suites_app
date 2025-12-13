import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  server: {
    proxy: {
      '/suites_app': {
        target: 'http://localhost:8083',
        changeOrigin: true
      }
    }
  }
});
