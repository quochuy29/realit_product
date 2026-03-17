import './bootstrap';
import {createApp} from 'vue';

import App from './pages/App.vue';
import Router from './routes/router';

const app = createApp(App).use(Router);
// Expose router globally for axios interceptor to use
window.__router__ = Router;

app.mount("#app");
