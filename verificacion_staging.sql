-- =====================================================================
-- MULTISOFT · VERIFICACIÓN DE ESTADO DE STAGING  (SOLO LECTURA)
-- Ejecutar en Supabase > SQL Editor del proyecto multisoft-staging.
-- No modifica nada: son únicamente SELECT.
-- Cada BLOQUE se ejecuta por separado: selecciona solo el bloque y pulsa Run
-- (el editor muestra el resultado de lo último que se ejecuta).
-- =====================================================================

-- ---------- BLOQUE 1: resumen general ----------
select '1. Rubros cargados (esperado: 11)' as verificacion, count(*)::text as resultado
  from public.rubros
union all
select '2. Superadmins activos (esperado: 1 o mas)', count(*)::text
  from public.perfiles where es_superadmin and activo
union all
select '3. Tablas de public SIN RLS (esperado: 0)', count(*)::text
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
union all
select '4. Funciones private ejecutables por authenticated (esperado: 11)', count(*)::text
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private' and has_function_privilege('authenticated', p.oid, 'execute')
union all
select '5. Negocios registrados', count(*)::text from public.negocios
union all
select '6. Negocios con MAS de 1 sucursal (revisar si hay duplicadas)', count(*)::text
  from (select negocio_id from public.sucursales group by negocio_id having count(*) > 1) x
union all
select '7. Usuarios de negocio creados (perfiles que no son superadmin)', count(*)::text
  from public.perfiles where not es_superadmin
union all
select '8. Registros de auditoria CREAR_RESPONSABLE', count(*)::text
  from public.auditoria where accion = 'CREAR_RESPONSABLE';

-- ---------- BLOQUE 2: negocios y sus sucursales ----------
select n.codigo, n.nombre, n.activo as negocio_activo,
       coalesce(string_agg(s.nombre, ', ' order by s.nombre), '(sin sucursales)') as sucursales
from public.negocios n
left join public.sucursales s on s.negocio_id = n.id
group by n.id, n.codigo, n.nombre, n.activo
order by n.creado_en desc;

-- ---------- BLOQUE 3: usuarios, roles y a que negocio pertenecen ----------
select p.login_id, p.nombre, p.es_superadmin, p.activo as perfil_activo,
       m.rol, n.codigo as negocio, s.nombre as sucursal, m.activo as membresia_activa
from public.perfiles p
left join public.membresias m on m.user_id = p.user_id
left join public.negocios   n on n.id = m.negocio_id
left join public.sucursales s on s.id = m.sucursal_id
order by p.creado_en desc;

-- ---------- BLOQUE 4: ultimas acciones auditadas ----------
select creado_en, accion, entidad, entidad_id, usuario_id, negocio_id
from public.auditoria
order by creado_en desc
limit 20;
