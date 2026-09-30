<script setup>
import { onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/supabase'

const router = useRouter()

const contrasena = ref('')
const repetirContrasena = ref('')
const verificando = ref(true)
const enlaceValido = ref(false)
const cargando = ref(false)
const mensaje = ref('')
const cambioExitoso = ref(false)

// Al abrir el enlace del correo, supabase-js lee el token de la URL y crea una
// sesión temporal de recuperación. Sin esa sesión no se puede cambiar la contraseña.
onMounted(async () => {
  const {
    data: { session },
  } = await supabase.auth.getSession()

  enlaceValido.value = Boolean(session)
  verificando.value = false
})

async function guardarContrasena() {
  mensaje.value = ''
  cambioExitoso.value = false

  if (contrasena.value !== repetirContrasena.value) {
    mensaje.value = 'Las contraseñas no coinciden.'
    return
  }

  if (contrasena.value.length < 6) {
    mensaje.value = 'La contraseña debe tener al menos 6 caracteres.'
    return
  }

  try {
    cargando.value = true

    const { error } = await supabase.auth.updateUser({
      password: contrasena.value,
    })

    if (error) {
      throw error
    }

    cambioExitoso.value = true
    mensaje.value = 'Contraseña actualizada. Te llevamos a tu cuenta...'
    contrasena.value = ''
    repetirContrasena.value = ''
    setTimeout(() => router.push('/inicio'), 1500)
  } catch (error) {
    if (error.code === 'same_password') {
      mensaje.value = 'La contraseña nueva tiene que ser distinta de la anterior.'
    } else {
      mensaje.value = error.message
    }
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <main class="pagina pagina-nueva-contrasena">
    <section class="tarjeta tarjeta-nueva-contrasena">
      <h1>Nueva contraseña</h1>

      <p v-if="verificando" class="descripcion">Verificando el enlace...</p>

      <template v-else-if="enlaceValido">
        <p class="descripcion">Elegí una contraseña nueva para tu cuenta.</p>

        <form @submit.prevent="guardarContrasena">
          <div class="campo">
            <label for="contrasena">Contraseña nueva</label>
            <input
              id="contrasena"
              v-model="contrasena"
              type="password"
              placeholder="Mínimo 6 caracteres"
              autocomplete="new-password"
              required
            />
          </div>

          <div class="campo">
            <label for="repetir-contrasena">Repetir contraseña</label>
            <input
              id="repetir-contrasena"
              v-model="repetirContrasena"
              type="password"
              placeholder="Volvé a escribir la contraseña"
              autocomplete="new-password"
              required
            />
          </div>

          <button type="submit" :disabled="cargando || cambioExitoso">
            {{ cargando ? 'Guardando...' : 'Guardar contraseña' }}
          </button>
        </form>

        <p v-if="mensaje" class="mensaje" :class="{ exito: cambioExitoso, error: !cambioExitoso }">
          {{ mensaje }}
        </p>
      </template>

      <template v-else>
        <p class="mensaje error">
          El enlace no es válido o ya expiró. Pedí uno nuevo para restablecer la contraseña.
        </p>
        <p class="enlace">
          <RouterLink to="/recuperar">Solicitar un enlace nuevo</RouterLink>
        </p>
      </template>
    </section>
  </main>
</template>
