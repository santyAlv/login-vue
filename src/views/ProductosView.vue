<script setup>
import { onMounted, ref } from 'vue'
import { supabase } from '@/supabase'
import BarraNavegacion from '@/components/BarraNavegacion.vue'

const productos = ref([])

const nombre = ref('')
const descripcion = ref('')
const precio = ref('')
const stock = ref(0)
const activo = ref(true)

const archivoImagen = ref(null)
const vistaPrevia = ref('')
const imagenUrlExistente = ref('')
const imagenRutaExistente = ref('')
const inputImagen = ref(null)

const productoEditandoId = ref(null)
const cargando = ref(false)
const mensaje = ref('')
const errorMensaje = ref('')

const formatoPrecio = new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS' })

// Baja: lista los productos del usuario. RLS devuelve solo los propios.
async function cargarProductos(limpiarMensaje = true) {
  cargando.value = true
  errorMensaje.value = ''
  if (limpiarMensaje) mensaje.value = ''

  const { data, error } = await supabase
    .from('productos')
    .select('*')
    .order('creado_en', { ascending: false })

  if (error) {
    errorMensaje.value = error.message
  } else {
    productos.value = data
  }

  cargando.value = false
}

function seleccionarImagen(evento) {
  errorMensaje.value = ''

  const archivo = evento.target.files?.[0]

  if (!archivo) {
    archivoImagen.value = null
    vistaPrevia.value = ''
    return
  }

  const tiposPermitidos = ['image/jpeg', 'image/png', 'image/webp']

  if (!tiposPermitidos.includes(archivo.type)) {
    errorMensaje.value = 'La imagen debe ser JPG, PNG o WEBP.'
    evento.target.value = ''
    return
  }

  if (archivo.size > 5 * 1024 * 1024) {
    errorMensaje.value = 'La imagen no puede superar los 5 MB.'
    evento.target.value = ''
    return
  }

  if (vistaPrevia.value) URL.revokeObjectURL(vistaPrevia.value)

  archivoImagen.value = archivo
  vistaPrevia.value = URL.createObjectURL(archivo)
}

// Sube la imagen a Storage dentro de la carpeta del usuario: <id-usuario>/<uuid>.<ext>
async function subirImagen() {
  if (!archivoImagen.value) return null

  const {
    data: { user },
    error: errorUsuario,
  } = await supabase.auth.getUser()

  if (errorUsuario || !user) {
    throw new Error('No hay un usuario autenticado.')
  }

  const extension = archivoImagen.value.name.split('.').pop().toLowerCase()
  const ruta = `${user.id}/${crypto.randomUUID()}.${extension}`

  const { error: errorSubida } = await supabase.storage
    .from('productos')
    .upload(ruta, archivoImagen.value, {
      cacheControl: '3600',
      upsert: false,
    })

  if (errorSubida) throw errorSubida

  const { data } = supabase.storage.from('productos').getPublicUrl(ruta)

  return {
    url: data.publicUrl,
    ruta,
  }
}

// Alta y modificación
async function guardarProducto() {
  errorMensaje.value = ''
  mensaje.value = ''

  if (!nombre.value.trim()) {
    errorMensaje.value = 'El nombre es obligatorio.'
    return
  }

  if (precio.value === '' || Number(precio.value) < 0) {
    errorMensaje.value = 'Ingresá un precio válido.'
    return
  }

  if (Number(stock.value) < 0) {
    errorMensaje.value = 'El stock no puede ser negativo.'
    return
  }

  if (!productoEditandoId.value && !archivoImagen.value) {
    errorMensaje.value = 'Seleccioná una imagen para el producto.'
    return
  }

  cargando.value = true

  let nuevaImagen

  try {
    nuevaImagen = await subirImagen()

    const datosProducto = {
      nombre: nombre.value.trim(),
      descripcion: descripcion.value.trim() || null,
      precio: Number(precio.value),
      stock: Number(stock.value),
      activo: activo.value,
      imagen_url: nuevaImagen?.url ?? imagenUrlExistente.value,
      imagen_ruta: nuevaImagen?.ruta ?? imagenRutaExistente.value,
    }

    let error

    if (productoEditandoId.value) {
      ;({ error } = await supabase
        .from('productos')
        .update(datosProducto)
        .eq('id', productoEditandoId.value))
    } else {
      ;({ error } = await supabase.from('productos').insert(datosProducto))
    }

    if (error) {
      // Si falla la base de datos, no dejamos la imagen nueva huérfana
      if (nuevaImagen?.ruta) {
        await supabase.storage.from('productos').remove([nuevaImagen.ruta])
      }
      throw error
    }

    // Al reemplazar la imagen de un producto, se borra la anterior
    if (productoEditandoId.value && nuevaImagen?.ruta && imagenRutaExistente.value) {
      await supabase.storage.from('productos').remove([imagenRutaExistente.value])
    }

    mensaje.value = productoEditandoId.value
      ? 'Producto actualizado correctamente.'
      : 'Producto creado correctamente.'

    limpiarFormulario()
    await cargarProductos(false)
  } catch (error) {
    errorMensaje.value = error.message
  } finally {
    cargando.value = false
  }
}

function editarProducto(producto) {
  productoEditandoId.value = producto.id
  nombre.value = producto.nombre
  descripcion.value = producto.descripcion ?? ''
  precio.value = producto.precio
  stock.value = producto.stock
  activo.value = producto.activo
  imagenUrlExistente.value = producto.imagen_url ?? ''
  imagenRutaExistente.value = producto.imagen_ruta ?? ''
  archivoImagen.value = null
  if (vistaPrevia.value) URL.revokeObjectURL(vistaPrevia.value)
  vistaPrevia.value = ''
  mensaje.value = ''
  errorMensaje.value = ''

  if (inputImagen.value) inputImagen.value.value = ''

  window.scrollTo({ top: 0, behavior: 'smooth' })
}

// Baja
async function eliminarProducto(producto) {
  const confirmado = window.confirm(`¿Querés eliminar el producto "${producto.nombre}"?`)

  if (!confirmado) return

  cargando.value = true
  errorMensaje.value = ''
  mensaje.value = ''

  const { error } = await supabase.from('productos').delete().eq('id', producto.id)

  if (error) {
    errorMensaje.value = error.message
    cargando.value = false
    return
  }

  if (producto.imagen_ruta) {
    const { error: errorImagen } = await supabase.storage
      .from('productos')
      .remove([producto.imagen_ruta])

    if (errorImagen) {
      errorMensaje.value = 'El producto se eliminó, pero no se pudo borrar su imagen.'
    }
  }

  if (!errorMensaje.value) mensaje.value = 'Producto eliminado correctamente.'
  if (productoEditandoId.value === producto.id) limpiarFormulario()

  await cargarProductos(false)
  cargando.value = false
}

function limpiarFormulario() {
  nombre.value = ''
  descripcion.value = ''
  precio.value = ''
  stock.value = 0
  activo.value = true
  productoEditandoId.value = null
  archivoImagen.value = null
  imagenUrlExistente.value = ''
  imagenRutaExistente.value = ''

  if (vistaPrevia.value) URL.revokeObjectURL(vistaPrevia.value)
  vistaPrevia.value = ''

  if (inputImagen.value) inputImagen.value.value = ''
}

function cancelarEdicion() {
  limpiarFormulario()
  mensaje.value = ''
  errorMensaje.value = ''
}

onMounted(cargarProductos)
</script>

<template>
  <div class="contenedor-app">
    <BarraNavegacion />

    <main class="pagina-productos">
      <section class="panel formulario-panel">
        <p class="etiqueta">Administración</p>
        <h1>{{ productoEditandoId ? 'Editar producto' : 'Nuevo producto' }}</h1>
        <p class="descripcion">Completá los datos y guardá una imagen JPG, PNG o WEBP.</p>

        <form @submit.prevent="guardarProducto">
          <div class="campo">
            <label for="nombre">Nombre</label>
            <input id="nombre" v-model="nombre" type="text" maxlength="120" required />
          </div>

          <div class="campo">
            <label for="descripcion">Descripción</label>
            <textarea id="descripcion" v-model="descripcion" rows="3"></textarea>
          </div>

          <div class="fila">
            <div class="campo">
              <label for="precio">Precio</label>
              <input
                id="precio"
                v-model="precio"
                type="number"
                inputmode="decimal"
                min="0"
                step="0.01"
                required
              />
            </div>

            <div class="campo">
              <label for="stock">Stock</label>
              <input
                id="stock"
                v-model="stock"
                type="number"
                inputmode="numeric"
                min="0"
                step="1"
                required
              />
            </div>
          </div>

          <div class="campo">
            <label for="imagen">Imagen del producto</label>
            <input
              id="imagen"
              ref="inputImagen"
              type="file"
              accept="image/jpeg,image/png,image/webp"
              @change="seleccionarImagen"
            />
            <small>Máximo 5 MB. Desde el celular podés sacar la foto en el momento.</small>
          </div>

          <div v-if="vistaPrevia || imagenUrlExistente" class="contenedor-vista-previa">
            <img
              :src="vistaPrevia || imagenUrlExistente"
              alt="Vista previa del producto"
              class="vista-previa"
            />
            <span>{{ vistaPrevia ? 'Nueva imagen seleccionada' : 'Imagen actual' }}</span>
          </div>

          <label class="check">
            <input v-model="activo" type="checkbox" />
            Producto activo
          </label>

          <div class="acciones-formulario">
            <button type="submit" :disabled="cargando">
              {{
                cargando
                  ? 'Guardando...'
                  : productoEditandoId
                    ? 'Actualizar producto'
                    : 'Crear producto'
              }}
            </button>

            <button
              v-if="productoEditandoId"
              type="button"
              class="secundario"
              @click="cancelarEdicion"
            >
              Cancelar
            </button>
          </div>
        </form>

        <p v-if="errorMensaje" class="mensaje error">{{ errorMensaje }}</p>
        <p v-if="mensaje" class="mensaje exito">{{ mensaje }}</p>
      </section>

      <section class="panel listado-panel">
        <div class="cabecera-listado">
          <div>
            <p class="etiqueta">Inventario</p>
            <h2>Mis productos</h2>
          </div>

          <button
            type="button"
            class="secundario"
            :disabled="cargando"
            @click="cargarProductos()"
          >
            Actualizar
          </button>
        </div>

        <p v-if="cargando && !productos.length" class="vacio">Cargando productos...</p>
        <p v-else-if="!productos.length" class="vacio">Todavía no creaste productos.</p>

        <div v-else class="tabla-contenedor">
          <table>
            <thead>
              <tr>
                <th>Imagen</th>
                <th>Producto</th>
                <th>Precio</th>
                <th>Stock</th>
                <th>Estado</th>
                <th>Acciones</th>
              </tr>
            </thead>

            <tbody>
              <tr v-for="producto in productos" :key="producto.id">
                <td>
                  <img
                    v-if="producto.imagen_url"
                    :src="producto.imagen_url"
                    :alt="producto.nombre"
                    class="miniatura"
                  />
                  <span v-else class="sin-imagen">Sin imagen</span>
                </td>
                <td class="celda-producto">
                  <strong>{{ producto.nombre }}</strong>
                  <small>{{ producto.descripcion || 'Sin descripción' }}</small>
                </td>
                <td data-titulo="Precio">{{ formatoPrecio.format(producto.precio) }}</td>
                <td data-titulo="Stock">{{ producto.stock }}</td>
                <td data-titulo="Estado">
                  <span :class="['estado', producto.activo ? 'activo' : 'inactivo']">
                    {{ producto.activo ? 'Activo' : 'Inactivo' }}
                  </span>
                </td>
                <td>
                  <div class="acciones-tabla">
                    <button type="button" class="editar" @click="editarProducto(producto)">
                      Editar
                    </button>
                    <button type="button" class="eliminar" @click="eliminarProducto(producto)">
                      Eliminar
                    </button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </main>
  </div>
</template>
