# Login con Vue 3 y Supabase

Aplicación Vue 3 + Vite + Vue Router con autenticación de Supabase:

- **Login**: `/login`
- **Registro**: `/registro` (con confirmación por correo)
- **Recuperar contraseña**: `/recuperar` envía el enlace y `/nueva-contrasena` guarda la nueva
- **Cerrar sesión**: botón en la barra de navegación de las páginas privadas
- **ABM de productos**: `/productos` (alta, baja y modificación con imagen en Supabase Storage)
- **Desde el celular**: el servidor de desarrollo se publica en la red local

## Estructura

```
login-vue/
├── supabase/
│   ├── schema.sql              # Base de datos: tabla perfiles + RLS + triggers
│   └── productos.sql           # Tabla productos + RLS + bucket de imágenes
├── src/
│   ├── assets/main.css         # Estilos compartidos
│   ├── router/index.js         # Rutas y guard de sesión
│   ├── components/
│   │   └── BarraNavegacion.vue # Menú Inicio / Productos / Cerrar sesión
│   ├── views/
│   │   ├── InicioView.vue      # Página privada con resumen y acceso al ABM
│   │   ├── ProductosView.vue   # ABM de productos
│   │   ├── LoginView.vue
│   │   ├── RegistroView.vue
│   │   ├── RecuperarView.vue   # Pide el enlace de recuperación
│   │   └── NuevaContrasenaView.vue
│   ├── App.vue
│   ├── main.js
│   └── supabase.js             # Cliente de Supabase
├── .env                        # URL y Publishable Key del proyecto
├── package.json
└── vite.config.js
```

## 1. Crear la base de datos en Supabase

1. Entrá a tu proyecto en [supabase.com](https://supabase.com/dashboard) y abrí **SQL Editor → New query**.
2. Pegá el contenido de [`supabase/schema.sql`](supabase/schema.sql) y hacé clic en **Run**.

El script crea:

| Objeto | Para qué sirve |
| --- | --- |
| `public.perfiles` | Una fila por usuario (`id`, `correo`, `creado_en`, `actualizado_en`), enlazada a `auth.users` |
| Row Level Security | Cada usuario solo puede leer y editar **su propio** perfil |
| Trigger `al_crear_usuario` | Crea el perfil automáticamente cuando alguien se registra |
| Trigger `al_cambiar_correo` | Mantiene el correo del perfil sincronizado con `auth.users` |

Las contraseñas **no** se guardan en esta tabla: Supabase Auth las almacena cifradas en `auth.users`.

3. En otra consulta nueva pegá [`supabase/productos.sql`](supabase/productos.sql) y hacé clic en **Run**.

| Objeto | Para qué sirve |
| --- | --- |
| `public.productos` | `nombre`, `descripcion`, `precio`, `stock`, `activo`, `imagen_url`, `imagen_ruta`, dueño en `usuario_id` |
| Row Level Security | Cada usuario solo ve, crea, modifica y elimina **sus** productos |
| Bucket `productos` | Imágenes JPG/PNG/WEBP de hasta 5 MB, guardadas en `<id-usuario>/<archivo>` |
| Políticas de Storage | Solo el dueño puede subir y borrar sus imágenes |

## 2. Configurar las URLs de redirección

Los correos de confirmación y de recuperación de contraseña tienen un enlace que vuelve a la app.
Supabase solo permite redirigir a direcciones autorizadas:

1. En Supabase abrí **Authentication → URL Configuration**.
2. **Site URL**: `http://localhost:5173`
3. En **Redirect URLs** agregá: `http://localhost:5173/**`

Si más adelante publicás la app (Vercel, Netlify, etc.), agregá también la URL de producción.

Para registrarte y confirmar el correo **desde el celular** agregá también la dirección de la red
local, por ejemplo `http://192.168.0.10:5173/**` (ver la sección *Usar la app desde el celular*).

> El servicio de correo que incluye Supabase envía pocos correos por hora. Si al registrarte o
> recuperar la contraseña aparece un error de límite, esperá unos minutos o configurá un SMTP propio
> en **Authentication → Emails → SMTP Settings**.

## 3. Variables de entorno

El archivo `.env` ya está incluido con los datos del proyecto:

```
VITE_SUPABASE_URL=https://npzhtjrmacuobmnlcmat.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Vite solo expone al navegador las variables que empiezan con `VITE_`. La **Publishable Key** está
pensada para usarse en el navegador. **Nunca** pongas en este proyecto la contraseña de la base de
datos ni las claves `secret` o `service_role`.

## 4. Instalar y ejecutar

Requiere Node.js 22.18 o superior.

```sh
npm install
npm run dev
```

Abrí <http://localhost:5173>.

### Usar la app desde el celular

1. Conectá la PC y el celular a la **misma red Wi-Fi**.
2. Ejecutá `npm run dev`. Vite muestra dos direcciones:
   ```
   ➜  Local:   http://localhost:5173/
   ➜  Network: http://192.168.0.10:5173/
   ```
3. En Supabase (**Authentication → URL Configuration → Redirect URLs**) agregá la dirección
   *Network* con `/**` al final, por ejemplo `http://192.168.0.10:5173/**`.
4. Abrí la dirección *Network* en el navegador del celular: podés registrarte, confirmar el correo
   desde el celular, iniciar sesión y crear o editar productos (al elegir la imagen podés sacar una
   foto con la cámara).

Si el celular no carga la página, Windows puede estar bloqueando el puerto: al ejecutar
`npm run dev` por primera vez aceptá el aviso del Firewall para **redes privadas**.

Otros comandos:

```sh
npm run build    # compilar para producción (carpeta dist/)
npm run lint     # revisar el código con oxlint y ESLint
npm run format   # formatear con Prettier
```

## Cómo funciona cada flujo

- **Registro**: `supabase.auth.signUp()` crea la cuenta y Supabase envía un correo de confirmación.
  El trigger de la base de datos crea la fila en `perfiles`.
- **Login**: `supabase.auth.signInWithPassword()` valida las credenciales y crea la sesión.
  El guard del router (`router.beforeEach`) protege `/inicio` y redirige a `/login` si no hay sesión.
- **Recuperar contraseña**: `supabase.auth.resetPasswordForEmail()` envía un enlace a
  `/nueva-contrasena`. Al abrirlo, supabase-js crea una sesión temporal y
  `supabase.auth.updateUser({ password })` guarda la contraseña nueva.
- **Cerrar sesión**: `supabase.auth.signOut()` elimina la sesión y vuelve al login.
- **ABM de productos** (`/productos`, protegida con `meta.requiereAutenticacion`):
  - **Alta**: sube la imagen a Storage (`storage.from('productos').upload()`) y luego
    `from('productos').insert()`. Si el insert falla se borra la imagen subida.
  - **Modificación**: el botón *Editar* carga el producto en el formulario y se guarda con
    `update().eq('id', ...)`. Si se elige una imagen nueva, la anterior se borra de Storage.
  - **Baja**: `delete().eq('id', ...)` previa confirmación, y se borra también su imagen.
  - **Listado**: `select('*').order('creado_en')`. Gracias a RLS cada usuario ve solo lo suyo.
  - En pantallas chicas la tabla se muestra como tarjetas para usarla cómodamente en el celular.
