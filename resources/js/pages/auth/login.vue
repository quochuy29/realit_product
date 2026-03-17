<template>
    <div class="min-h-screen flex items-center justify-center bg-gray-50">
        <div class="bg-white p-8 rounded-xl shadow-lg w-full max-w-md border border-gray-100">

            <div class="text-center mb-8">
                <div class="inline-flex items-center justify-center rounded-full bg-zinc-900 text-white mb-4">
                    <img :src="`/images/logo.png`" class="h-24 w-auto" alt="Logo">
                </div>
                <h1 class="text-2xl font-bold text-gray-900">エネルギーモニター</h1>
                <span class="text-sm text-red-500" v-if="sessionExpired">セッションの有効期限が切れました。<br>再度ログインしてください。</span>
            </div>

            <form @submit.prevent="login" class="space-y-5">
                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">ユーザーID:</label>
                    <input v-model="userId" ref="input" autofocus type="text" @blur="markTouched('user_id')" @input="clearError('user_id')" :class="inputClass('user_id')"
                        class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-zinc-900 focus:border-transparent outline-none transition-all">
                </div>

                <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">パスワード:</label>
                    <div class="relative">
                        <input
                            v-model="password"
                            :type="showPassword ? 'text' : 'password'"
                            @blur="markTouched('password')"
                            @input="clearError('password')"
                            :class="inputClass('password')"
                            class="w-full pl-4 py-2 pr-8 border border-gray-300 rounded-lg focus:ring-2 focus:ring-zinc-900 focus:border-transparent outline-none transition-all"
                        >
                    </div>
                </div>

                <button type="submit" :disabled="disabled"
                    class="w-full bg-primary hover:bg-primary/90 text-white font-bold py-2.5 rounded-lg transition-colors shadow-sm">
                    ログイン
                </button>
            </form>

            <div class="mt-8 text-center text-xs text-gray-400">
                © {{ currentYear }} Toyota Motor Kyushu
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import axios from 'axios';

const currentYear = new Date().getFullYear()

const userId = ref('');
const password = ref('');
const router = useRouter();
const disabled = ref(false);
const showPassword = ref(false)

const sessionExpired = ref(false);
// Check for session expiration flag on mount
onMounted(() => {
  try {
    if (localStorage.getItem('session_expired') === 'true') {
      sessionExpired.value = true;
      localStorage.removeItem('session_expired')
    }
  } catch (e) {
    // localStorage not available, continue without checking
    console.warn('localStorage not available:', e);
  }
})

const errors = ref({
    user_id: '',
    password: ''
});

const touched = ref({
    user_id: false,
    password: false
});
const input = ref(null);
onMounted(() => {
    if (input.value.hasAttribute('autofocus')) {
        input.value.focus();
    }
});

const inputClass = (field) => {
    const value = field === 'user_id' ? userId.value : password.value;
    const hasError = errors.value[field] || (touched.value[field] && !value);

    return hasError
        ? 'border-red-500 bg-red-50'
        : 'border-gray-300';
};

const markTouched = (field) => {
    touched.value[field] = true;
};

const clearError = (field) => {
    errors.value[field] = '';
};

const login = async () => {
    // try {
    //     disabled.value = true;
    //     errors.value = { user_id: '', password: '' };
    //     await axios.get('/sanctum/csrf-cookie');
    //     const response = await axios.post('/api/login', {
    //         user_id: userId.value,
    //         password: password.value
    //     });

    //     // Check if login was successful
    //     if (response.data.status === 200) {
    //         // Clear graph axis settings from localStorage on login
    //         try {
    //             localStorage.removeItem('graph_axis_settings');
    //             // Also clear session expiration flag if it exists
    //             localStorage.removeItem('session_expired');
    //         } catch (error) {
    //             console.error('Failed to clear localStorage on login:', error);
    //         }
            
    //         // Navigate to home page
    //         router.push({ name: 'home' });
    //     }
    // } catch (error) {
    //     if (error.response) {
    //         if (error.response.data.status == 400) {
    //             const responseErrors = error.response.data.errors;
    //             if (responseErrors) {
    //                 if (responseErrors.user_id) {
    //                     errors.value.user_id = responseErrors.user_id;
    //                 }
    //                 if (responseErrors.password) {
    //                     errors.value.password = responseErrors.password;
    //                 }
    //                 const allMessages = Object.values(responseErrors).flat();
    //             } else {
    //             }

    //         } else {
    //             const responseErrors = error.response.data.message;
    //         }
    //     }
    // } finally {
    //     disabled.value = false;
    // }
};
</script>