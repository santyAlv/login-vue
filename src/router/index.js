import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from '@/supabase'
import InicioView from '@/views/InicioView.vue'
import LoginView from '@/views/LoginView.vue'
import RegistroView from '@/views/RegistroView.vue'
import RecuperarView from '@/views/RecuperarView.vue'
import NuevaContrasenaView from '@/views/NuevaContrasenaView.vue'

// Rutas que solo tienen sentido sin sesión iniciada
const rutasPublicas = ['/login', '/registro', '/recuperar']

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      redirect: '/login',
    },
    {
      path: '/login',
      name: 'login',
      component: LoginView,
    },
    {
      path: '/registro',
      name: 'registro',
      component: RegistroView,
    },
    {
      path: '/recuperar',
      name: 'recuperar',
      component: RecuperarView,
    },
    {
      // Destino del enlace que llega por correo para restablecer la contraseña
      path: '/nueva-contrasena',
      name: 'nueva-contrasena',
      component: NuevaContrasenaView,
    },
    {
      path: '/inicio',
      name: 'inicio',
      component: InicioView,
      meta: {
        requiereAutenticacion: true,
      },
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/login',
    },
  ],
})

router.beforeEach(async (destino) => {
  const {
    data: { session },
  } = await supabase.auth.getSession()

  if (destino.meta.requiereAutenticacion && !session) {
    return '/login'
  }

  if (session && rutasPublicas.includes(destino.path)) {
    return '/inicio'
  }
})

export default router
