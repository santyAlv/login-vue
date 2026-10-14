<script setup>
import { onMounted, ref } from 'vue'
import { supabase } from '@/supabase'
import BarraNavegacion from '@/components/BarraNavegacion.vue'

const correoUsuario = ref('')
const miembroDesde = ref('')
const cantidadProductos = ref(null)

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

  // Cantidad de productos propios (ver supabase/productos.sql)
  const { count, error } = await supabase
    .from('productos')
    .select('id', { count: 'exact', head: true })

  if (!error) {
    cantidadProductos.value = count
  }
})
</script>

<template>
  <div class="contenedor-app">
    <BarraNavegacion />

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

        <div class="datos-usuario">
          <span>Productos cargados</span>
          <strong>{{ cantidadProductos ?? '—' }}</strong>
        </div>

        <RouterLink to="/productos" class="boton">Administrar productos</RouterLink>
      </section>
    </main>
  </div>
</template>
