<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/supabase'

const router = useRouter()

const cerrandoSesion = ref(false)

async function cerrarSesion() {
  try {
    cerrandoSesion.value = true

    const { error } = await supabase.auth.signOut()

    if (error) {
      throw error
    }

    router.push('/login')
  } catch (error) {
    alert(error.message)
  } finally {
    cerrandoSesion.value = false
  }
}
</script>

<template>
  <header class="barra-navegacion">
    <nav>
      <RouterLink to="/inicio">Inicio</RouterLink>
      <RouterLink to="/productos">Productos</RouterLink>
    </nav>

    <button type="button" class="secundario" :disabled="cerrandoSesion" @click="cerrarSesion">
      {{ cerrandoSesion ? 'Cerrando...' : 'Cerrar sesión' }}
    </button>
  </header>
</template>
