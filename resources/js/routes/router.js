import { createRouter, createWebHistory } from 'vue-router';
// import { ROLES } from '../const';
// import { useAuthStore } from '../stores/auth';
import axios from 'axios';
import Login from '../pages/auth/login.vue'
// import MainLayout from '../pages/MainLayout.vue'
// import Home from '../pages/home/index.vue'
// import Graph from '../pages/graph/index.vue'
// import User from '../pages/user/index.vue'
// import DataMaintenance from '../pages/data-maintenance/index.vue'
// import NotFound from '../components/common/NotFound.vue';
// import EquipmentsManagement from '../pages/data-maintenance/tabs/EquipmentsManagement.vue';
// import TagsCalculation from '../pages/data-maintenance/tabs/TagsCalculation.vue';
// import ParametersSetting from '../pages/data-maintenance/tabs/ParametersSetting.vue';
// import DataRecovery from '../pages/data-maintenance/tabs/DataRecovery.vue';

const routes = [
    {
        path: '/login',
        name: 'login',
        component: Login,
    },
    // {
    //     path: '/',
    //     component: MainLayout,
    //     name:'MainLayout',
    //     meta: { requiresAuth: true },
    //     children: [
    //         {
    //             path: 'home',
    //             name: 'home',
    //             component: Home,
    //             meta: { title: 'ホーム' },
    //         },
    //         {
    //             path: 'graph',
    //             name: 'graph',
    //             component: Graph,
    //         },
    //         {
    //             path: 'user',
    //             name: 'user',
    //             component: User,
    //             meta: { role: [ROLES.ADMIN] }
    //         },
    //         {
    //             path: 'data-maintenance',
    //             name: 'data-maintenance',
    //             component: DataMaintenance,
    //             meta: { role: [ROLES.ADMIN] },
    //             children: [
    //                 {
    //                     path: 'equipments-management',
    //                     name: 'data-maintenance.equipments-management',
    //                     component: EquipmentsManagement
    //                 },
    //                 {
    //                     path: 'parameters-setting',
    //                     name: 'data-maintenance.parameters-setting',
    //                     component: ParametersSetting
    //                 },
    //                 {
    //                     path: 'tags-calculation',
    //                     name: 'data-maintenance.tags-calculation',
    //                     component: TagsCalculation
    //                 },
    //                 {
    //                     path: 'data-recovery',
    //                     name: 'data-maintenance.data-recovery',
    //                     component: DataRecovery
    //                 },
    //             ],
    //         },
    //     ]
    // },
    // {
    //     path: '/:pathMatch(.*)*',
    //     name: 'NotFound',
    //     component: NotFound,
    //     meta: { requiresAuth: true },
    // },
];

const router = createRouter({
    history: createWebHistory(),
    routes
});

export default router;