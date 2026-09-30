-- =====================================================================
-- Base de datos del proyecto login-supabase
-- Ejecutar una sola vez en: Supabase > SQL Editor > New query > Run
--
-- Supabase Auth ya guarda las cuentas en auth.users (correo, contraseña
-- cifrada, confirmación, etc.). Este script agrega una tabla pública
-- "perfiles" con una fila por usuario, creada automáticamente al registrarse.
-- =====================================================================

-- 1. Tabla de perfiles -------------------------------------------------
create table if not exists public.perfiles (
  id uuid primary key references auth.users (id) on delete cascade,
  correo text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

comment on table public.perfiles is 'Un perfil por cada usuario registrado en auth.users';

-- 2. Row Level Security ------------------------------------------------
-- Con RLS activo nadie puede leer ni modificar filas salvo lo que
-- permitan las políticas de abajo.
alter table public.perfiles enable row level security;

drop policy if exists "Cada usuario ve su propio perfil" on public.perfiles;
create policy "Cada usuario ve su propio perfil"
  on public.perfiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "Cada usuario edita su propio perfil" on public.perfiles;
create policy "Cada usuario edita su propio perfil"
  on public.perfiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- 3. Crear el perfil automáticamente al registrarse --------------------
create or replace function public.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.perfiles (id, correo)
  values (new.id, new.email);
  return new;
end;
$$;

-- La función solo la ejecuta el trigger, no los clientes de la API.
revoke execute on function public.crear_perfil_nuevo_usuario() from public, anon, authenticated;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil_nuevo_usuario();

-- 4. Mantener actualizado_en y el correo sincronizados -----------------
create or replace function public.sincronizar_correo_perfil()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.perfiles
  set correo = new.email,
      actualizado_en = now()
  where id = new.id;
  return new;
end;
$$;

revoke execute on function public.sincronizar_correo_perfil() from public, anon, authenticated;

drop trigger if exists al_cambiar_correo on auth.users;
create trigger al_cambiar_correo
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.sincronizar_correo_perfil();

-- 5. Perfiles para usuarios que ya existían antes de este script -------
insert into public.perfiles (id, correo, creado_en)
select id, email, created_at
from auth.users
where email is not null
on conflict (id) do nothing;
