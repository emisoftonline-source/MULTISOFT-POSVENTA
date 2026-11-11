-- =============================================================================
-- MULTISOFT · 12_config_negocio.sql
-- Nombre comercial y logo de cada negocio (pestaña CONFIG del administrador de negocio).
-- Se puede ejecutar más de una vez sin problema. No borra ni modifica datos existentes.
-- Ejecutar en: Supabase → SQL Editor (proyecto multisoft-staging primero).
-- =============================================================================

-- 1) Dos columnas nuevas en negocios (el "nombre" oficial no se toca).
alter table public.negocios add column if not exists nombre_comercial text;
alter table public.negocios add column if not exists logo text;   -- imagen pequeña (máx. 120 px) en formato data:image/...

alter table public.negocios drop constraint if exists negocios_nombre_comercial_largo;
alter table public.negocios add constraint negocios_nombre_comercial_largo
  check (nombre_comercial is null or char_length(nombre_comercial) <= 120);

alter table public.negocios drop constraint if exists negocios_logo_formato;
alter table public.negocios add constraint negocios_logo_formato
  check (logo is null or (logo like 'data:image/%' and char_length(logo) <= 300000));

-- 2) Única forma de cambiarlas desde la app: solo un admin_negocio ACTIVO de ese negocio (negocio activo).
create or replace function public.guardar_config_negocio(
  p_negocio uuid,
  p_nombre_comercial text,
  p_logo text default null,          -- null = conservar el logo actual
  p_quitar_logo boolean default false
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nombre text := nullif(btrim(coalesce(p_nombre_comercial, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Sesión requerida' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.membresias m
    join public.negocios n on n.id = m.negocio_id
    where m.user_id = auth.uid()
      and m.negocio_id = p_negocio
      and m.rol = 'admin_negocio'
      and m.activo
      and n.activo
  ) then
    raise exception 'No tienes permiso para cambiar la configuración de este negocio' using errcode = '42501';
  end if;

  if v_nombre is not null and char_length(v_nombre) > 120 then
    raise exception 'El nombre comercial no puede tener más de 120 caracteres';
  end if;
  if p_logo is not null and (p_logo not like 'data:image/%' or char_length(p_logo) > 300000) then
    raise exception 'El logo no es una imagen válida o es demasiado grande';
  end if;

  update public.negocios
     set nombre_comercial = v_nombre,
         logo = case when p_quitar_logo then null
                     when p_logo is not null then p_logo
                     else logo end
   where id = p_negocio;

  -- Auditoría (si la tabla tiene otra forma, no impide guardar).
  begin
    insert into public.auditoria (negocio_id, usuario_id, accion, entidad, entidad_id, despues)
    values (p_negocio, auth.uid(), 'CONFIG_NEGOCIO', 'negocios', p_negocio,
            jsonb_build_object('nombre_comercial', v_nombre, 'logo_cambiado', (p_logo is not null or p_quitar_logo)));
  exception when others then
    raise warning 'No se pudo registrar la auditoría: %', sqlerrm;
  end;
end;
$$;

revoke all on function public.guardar_config_negocio(uuid, text, text, boolean) from public, anon;
grant execute on function public.guardar_config_negocio(uuid, text, text, boolean) to authenticated;

-- 3) Comprobación: debe mostrar las dos columnas nuevas.
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'negocios' and column_name in ('nombre_comercial', 'logo');
