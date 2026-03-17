import { defineConfig, loadEnv } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';
import path from 'path'

export default defineConfig(({ mode }) => {
    const env = loadEnv(mode, process.cwd(), '');

    return {
        plugins: [
            vue(),
            laravel({
                input: ['resources/css/app.css', 'resources/js/app.js'],
                refresh: true,
                buildDirectory: 'build',
            })
        ],
        server: {
            host: '0.0.0.0', // Listen on all interfaces
            port: 5173,
            strictPort: true,
            origin: env.VITE_DEV_SERVER_URL || 'http://localhost:5173',
            hmr: {
                // Use environment variable or auto-detect from request
                // For network access, set APP_VITE_HOST to your network IP (e.g., 192.84.10.179)
                host: env.VITE_APP_HOST || 'localhost',
                port: 5173,
                clientPort: env.VITE_APP_PORT || 5173,
                protocol: 'ws',
            },
            cors: {
                origin: true, // Allow all origins in development
                credentials: true,
            },
            watch: {
                usePolling: true,
                interval: 1000, // Polling interval for better file detection
            },
        },
        build: {
            outDir: 'public/build',
            emptyOutDir: true,
            manifest: 'manifest.json',
            sourcemap: false, // Disable in production for security
            rollupOptions: {
                output: {
                    manualChunks: {
                        'vendor': ['vue'],
                    },
                },
            },
            chunkSizeWarningLimit: 1000,
        },
        optimizeDeps: {
            include: ['vue'],
        },
        resolve: {
            alias: {
            '@': path.resolve(__dirname, 'resources/js'),
            },
        },
    };
});
