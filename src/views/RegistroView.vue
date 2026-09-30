<script setup>
import { ref } from 'vue'
import { supabase } from '@/supabase'

const correo = ref('')
const contrasena = ref('')
const repetirContrasena = ref('')
const cargando = ref(false)
const mensaje = ref('')
const registroExitoso = ref(false)

async function registrarUsuario() {
  mensaje.value = ''
  registroExitoso.value = false

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

    const { data, error } = await supabase.auth.signUp({
      email: correo.value,
      password: contrasena.value,
      options: {
        // Página a la que vuelve el usuario al confirmar el correo
        emailRedirectTo: `${window.location.origin}/inicio`,
      },
    })

    if (error) {
      throw error
    }

    // Con la confirmación por correo activa, Supabase no informa error si el
    // correo ya existe: devuelve un usuario sin identidades.
    if (data.user && data.user.identities?.length === 0) {
      mensaje.value = 'Ese correo ya está registrado. Iniciá sesión o recuperá tu contraseña.'
      return
    }

    registroExitoso.value = true
    mensaje.value = 'Registro realizado. Revisá tu correo electrónico para confirmar la cuenta.'
    correo.value = ''
    contrasena.value = ''
    repetirContrasena.value = ''
  } catch (error) {
    if (error.status === 429) {
      mensaje.value = 'Se enviaron demasiados correos. Esperá unos minutos y volvé a intentar.'
    } else {
      mensaje.value = error.message
    }
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <main class="pagina pagina-registro">
    <section class="tarjeta tarjeta-registro">
      <h1>Crear una cuenta</h1>
      <p class="descripcion">Registrate utilizando tu correo electrónico.</p>

      <form @submit.prevent="registrarUsuario">
        <div class="campo">
          <label for="correo">Correo electrónico</label>
          <input
            id="correo"
            v-model="correo"
            type="email"
            placeholder="nombre@correo.com"
            autocomplete="email"
            required
          />
        </div>

        <div class="campo">
          <label for="contrasena">Contraseña</label>
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

        <button type="submit" :disabled="cargando">
          {{ cargando ? 'Registrando...' : 'Registrarme' }}
        </button>
      </form>

      <p
        v-if="mensaje"
        class="mensaje"
        :class="{ exito: registroExitoso, error: !registroExitoso }"
      >
        {{ mensaje }}
      </p>

      <p class="enlace">
        ¿Ya tenés una cuenta?
        <RouterLink to="/login">Iniciá sesión</RouterLink>
      </p>
    </section>
  </main>
</template>
