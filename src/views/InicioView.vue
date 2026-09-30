<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/supabase'

const router = useRouter()

const correoUsuario = ref('')
const miembroDesde = ref('')
const cerrandoSesion = ref(false)

onMounted(async () => {
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    return
  }

  correoUsuario.value = user.email

  // Datos guardados en la tabla public.perfiles (ver supabase/schema.sql).
  // Row Level Security solo permite leer el perfil propio.
  const { data: perfil } = await supabase
    .from('perfiles')
    .select('creado_en')
    .eq('id', user.id)
    .maybeSingle()

  if (perfil) {
    miembroDesde.value = new Date(perfil.creado_en).toLocaleDateString('es-AR', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    })
  }
})

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
  <main class="pagina pagina-inicio">
    <section class="tarjeta tarjeta-inicio">
      <div class="icono">✓</div>
      <h1>¡Bienvenido!</h1>
      <p class="descripcion">Iniciaste sesión correctamente.</p>

      <div class="datos-usuario">
        <span>Usuario autenticado</span>
        <strong>{{ correoUsuario }}</strong>
        <small v-if="miembroDesde">Miembro desde el {{ miembroDesde }}</small>
      </div>

      <button type="button" :disabled="cerrandoSesion" @click="cerrarSesion">
        {{ cerrandoSesion ? 'Cerrando...' : 'Cerrar sesión' }}
      </button>
    </section>
  </main>
</template>
