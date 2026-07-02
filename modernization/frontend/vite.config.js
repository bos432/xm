import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    rolldownOptions: {
      checks: {
        invalidAnnotation: false
      },
      output: {
        codeSplitting: {
          groups: [
            {
              name: 'vendor-vue',
              test: /node_modules[\\/](vue|vue-router|pinia)[\\/]/,
              priority: 30
            },
            {
              name: 'vendor-vueuse',
              test: /node_modules[\\/]@vueuse[\\/]/,
              priority: 28
            },
            {
              name: 'vendor-popper',
              test: /node_modules[\\/]@popperjs[\\/]/,
              priority: 26
            },
            {
              name: 'vendor-element-utils',
              test: /node_modules[\\/](async-validator|dayjs|lodash-unified|memoize-one|normalize-wheel-es)[\\/]/,
              priority: 24
            },
            {
              name: 'vendor-element-plus',
              test: /node_modules[\\/]element-plus[\\/]/,
              priority: 20
            },
            {
              name: 'vendor-icons',
              test: /node_modules[\\/]@element-plus[\\/]icons-vue[\\/]/,
              priority: 10
            }
          ]
        }
      }
    }
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true
      }
    }
  }
})
