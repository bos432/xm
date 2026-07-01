import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import './styles.css'
import App from './App.vue'
import router from './router.js'
import { loadConfiguredFavicon } from './favicon.js'

createApp(App).use(createPinia()).use(router).use(ElementPlus).mount('#app')
loadConfiguredFavicon()
