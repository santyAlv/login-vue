-- =====================================================================
-- ABM de productos
-- Ejecutar en: Supabase > SQL Editor > New query > Run
-- (después de schema.sql). Se puede volver a ejecutar sin errores.
-- =====================================================================

-- 1. Tabla productos ---------------------------------------------------
create table if not exists public.productos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  nombre text not null,
  descripcion text,
  precio numeric(12, 2) not null check (precio >= 0),
  stock integer not null default 0 check (stock >= 0),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

comment on table public.productos is 'Productos cargados por cada usuario (ABM)';

create index if not exists productos_usuario_id_idx on public.productos (usuario_id);

alter table public.productos enable row level security;

grant select, insert, update, delete
  on table public.productos
  to authenticated;

-- 2. Políticas RLS: cada usuario solo ve y modifica sus productos ------
drop policy if exists "Usuarios leen sus productos" on public.productos;
create policy "Usuarios leen sus productos"
  on public.productos
  for select
  to authenticated
  using ((select auth.uid()) = usuario_id);

drop policy if exists "Usuarios crean sus productos" on public.productos;
create policy "Usuarios crean sus productos"
  on public.productos
  for insert
  to authenticated
  with check ((select auth.uid()) = usuario_id);

drop policy if exists "Usuarios modifican sus productos" on public.productos;
create policy "Usuarios modifican sus productos"
  on public.productos
  for update
  to authenticated
  using ((select auth.uid()) = usuario_id)
  with check ((select auth.uid()) = usuario_id);

drop policy if exists "Usuarios eliminan sus productos" on public.productos;
create policy "Usuarios eliminan sus productos"
  on public.productos
  for delete
  to authenticated
  using ((select auth.uid()) = usuario_id);

-- 3. Columnas de imagen ------------------------------------------------
alter table public.productos
  add column if not exists imagen_url text;

alter table public.productos
  add column if not exists imagen_ruta text;

-- 4. Bucket "productos" (público, hasta 5 MB, solo imágenes) -----------
-- Público para que <img> pueda mostrar las fotos por URL. Subir y borrar
-- archivos sigue protegido por las políticas de Storage de abajo.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'productos',
  'productos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = true,
    file_size_limit = 5242880,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- 5. Políticas de Storage: cada archivo va en una carpeta con el id del
-- usuario y solo su dueño puede verlo en la API o borrarlo -------------
drop policy if exists "Usuarios suben imagenes de productos" on storage.objects;
create policy "Usuarios suben imagenes de productos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'productos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Usuarios ven sus imagenes de productos" on storage.objects;
create policy "Usuarios ven sus imagenes de productos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'productos'
    and owner_id = (select auth.uid())::text
  );

drop policy if exists "Usuarios eliminan sus imagenes de productos" on storage.objects;
create policy "Usuarios eliminan sus imagenes de productos"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'productos'
    and owner_id = (select auth.uid())::text
  );
