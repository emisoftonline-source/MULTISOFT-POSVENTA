-- =====================================================================
-- MULTISOFT POS · FASE 2 · SCRIPT 13 · NOTAS POR PRODUCTO E INACTIVIDAD
-- Requiere 01 a 12. Se puede ejecutar más de una vez. No borra ni cambia datos existentes.
--
-- A) Nota por producto vendido ("sin cebolla", "sin papas", "cortar a 2 m"):
--    * venta_items.nota (opcional, máx. 200 caracteres)
--    * registrar_venta: cada ítem acepta {"producto_id","cantidad","precio","nota"}.
--      El mismo producto con notas distintas queda en líneas separadas. Todo lo demás
--      (precios, permisos, stock, pagos, idempotencia, auditoría) es IDÉNTICO al script 09.
--    * ventas_detalle: cada ítem devuelve también su "nota". Todo lo demás idéntico al script 11.
-- B) Cierre de sesión por inactividad, configurable por negocio:
--    * negocios.minutos_inactividad: 0 (nunca), 15, 30 (por defecto), 60 o 120
--    * guardar_inactividad_negocio(): solo admin_negocio activo de ese negocio
-- =====================================================================
begin;

-- ---------------------------------------------------------------- A) NOTAS
alter table public.venta_items add column if not exists nota text;
alter table public.venta_items drop constraint if exists venta_items_nota_largo;
alter table public.venta_items add constraint venta_items_nota_largo
  check (nota is null or char_length(nota) <= 200);

create or replace function public.registrar_venta(
  p_caja uuid,
  p_items jsonb,
  p_pagos jsonb default '[]'::jsonb,
  p_condicion public.condicion_venta default 'contado',
  p_cliente uuid default null,
  p_tipo_venta text default 'local',
  p_nota text default null,
  p_fecha_entrega date default null,
  p_idempotency_key uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  c public.cajas%rowtype;
  v_neg uuid; v_uid uuid := (select auth.uid());
  v_dup record; r record; pago record;
  v_permite_neg boolean;
  v_total numeric(14,2); v_n_items int; v_n_ok int;
  v_pagado numeric(14,2); v_efectivo numeric(14,2); v_vuelto numeric(14,2) := 0;
  v_cliente uuid; v_venta uuid; v_nro bigint;
  v_mods jsonb;
  v_stock numeric(14,3); v_resto numeric(14,2); v_take numeric(14,2); v_monto numeric(14,2);
begin
  if v_uid is null then raise exception 'Sesión requerida' using errcode = '42501'; end if;

  select * into c from public.cajas where id = p_caja for share;   -- bloquea contra un cierre simultáneo
  if not found then
    raise exception 'No tienes permiso para esta operación en esa sucursal' using errcode = '42501';
  end if;
  v_neg := private.exigir_rol_suc(c.sucursal_id,
             array['admin_negocio','gerente_sucursal','cajero','vendedor']::public.rol_tipo[]);
  if c.estado <> 'abierta' then raise exception 'La caja está cerrada' using errcode = '55000'; end if;

  -- reintento con la misma clave: devuelve la venta ya registrada (sin tocar nada)
  if p_idempotency_key is not null then
    select v.id, v.nro_venta, v.total, v.vuelto into v_dup
      from public.ventas v where v.sucursal_id = c.sucursal_id and v.idempotency_key = p_idempotency_key;
    if found then
      return jsonb_build_object('venta_id', v_dup.id, 'nro_venta', v_dup.nro_venta,
                                'total', v_dup.total, 'vuelto', coalesce(v_dup.vuelto, 0), 'duplicada', true);
    end if;
  end if;

  -- ---- validar ítems ----
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 200 then
    raise exception 'La venta necesita entre 1 y 200 ítems' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_to_recordset(p_items) as x(producto_id uuid, cantidad numeric, precio numeric)
              where x.producto_id is null or x.cantidad is null or round(x.cantidad, 3) <= 0
                 or (x.precio is not null and round(x.precio, 2) < 0)) then
    raise exception 'Cada ítem necesita un producto, una cantidad mayor a cero y un precio no negativo' using errcode = '22023';
  end if;
  -- NUEVO (13): nota opcional por línea, p. ej. "sin cebolla" (máx. 200 caracteres)
  if exists (select 1 from jsonb_to_recordset(p_items) as x(nota text)
              where x.nota is not null and length(btrim(x.nota)) > 200) then
    raise exception 'La nota de un producto no puede tener más de 200 caracteres' using errcode = '22023';
  end if;

  -- 'precio' es opcional por línea. Si coincide con el de lista no cuenta como cambio.
  select count(distinct it.producto_id), coalesce(sum(round(coalesce(it.precio, p.precio_venta) * it.cant, 2)), 0)
    into v_n_ok, v_total
    from (select x.producto_id, round(x.precio, 2) as precio, sum(round(x.cantidad, 3)) as cant
            from jsonb_to_recordset(p_items) as x(producto_id uuid, cantidad numeric, precio numeric)
           group by x.producto_id, round(x.precio, 2)) it
    join public.productos p on p.id = it.producto_id and p.negocio_id = v_neg and p.activo;
  select count(distinct x.producto_id) into v_n_items
    from jsonb_to_recordset(p_items) as x(producto_id uuid, cantidad numeric, precio numeric);
  if v_n_ok <> v_n_items then
    raise exception 'Hay productos que no existen o están inactivos en este negocio' using errcode = '22023';
  end if;
  if v_total <= 0 then raise exception 'El total debe ser mayor a cero' using errcode = '22023'; end if;

  -- cambio de precio: SOLO administrador o gerente de la sucursal; queda registrado en auditoría
  select jsonb_agg(jsonb_build_object('producto_id', it.producto_id, 'precio_lista', p.precio_venta,
                                      'precio_aplicado', it.precio, 'cantidad', it.cant))
    into v_mods
    from (select x.producto_id, round(x.precio, 2) as precio, sum(round(x.cantidad, 3)) as cant
            from jsonb_to_recordset(p_items) as x(producto_id uuid, cantidad numeric, precio numeric)
           group by x.producto_id, round(x.precio, 2)) it
    join public.productos p on p.id = it.producto_id and p.negocio_id = v_neg
   where it.precio is not null and it.precio <> p.precio_venta;
  if v_mods is not null and not private.tiene_rol_suc(v_neg, c.sucursal_id,
       array['admin_negocio','gerente_sucursal']::public.rol_tipo[]) then
    raise exception 'Solo el administrador o el gerente pueden cambiar el precio de un producto' using errcode = '42501';
  end if;

  -- ---- validar pagos ----
  p_pagos := coalesce(p_pagos, '[]'::jsonb);
  if jsonb_typeof(p_pagos) <> 'array' then
    raise exception 'El formato de pagos no es válido' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_to_recordset(p_pagos) as x(metodo text, monto numeric)
              where x.metodo is null or x.monto is null or round(x.monto, 2) <= 0) then
    raise exception 'Cada pago necesita método y un monto mayor a cero' using errcode = '22023';
  end if;
  perform (x.metodo::public.metodo_pago) from jsonb_to_recordset(p_pagos) as x(metodo text, monto numeric);
  select coalesce(sum(round(x.monto, 2)), 0),
         coalesce(sum(round(x.monto, 2)) filter (where x.metodo = 'efectivo'), 0)
    into v_pagado, v_efectivo
    from jsonb_to_recordset(p_pagos) as x(metodo text, monto numeric);

  if p_condicion = 'contado' then
    if v_pagado < v_total then raise exception 'El pago no cubre el total de la venta' using errcode = '22023'; end if;
    v_vuelto := v_pagado - v_total;
    if v_vuelto > v_efectivo then
      raise exception 'El exceso solo puede devolverse en efectivo' using errcode = '22023';
    end if;
  else
    if v_pagado >= v_total then
      raise exception 'Una venta a crédito debe quedar con saldo pendiente' using errcode = '22023';
    end if;
  end if;

  -- ---- cliente ----
  if p_cliente is not null then
    select cl.id into v_cliente from public.clientes cl where cl.id = p_cliente and cl.negocio_id = v_neg and cl.activo;
    if v_cliente is null then raise exception 'Cliente no válido para este negocio' using errcode = '22023'; end if;
  end if;
  if p_condicion = 'credito' then
    if v_cliente is null or exists (select 1 from public.clientes cl where cl.id = v_cliente and cl.es_general) then
      raise exception 'Una venta a crédito necesita un cliente identificado' using errcode = '22023';
    end if;
  elsif v_cliente is null then
    select cl.id into v_cliente from public.clientes cl where cl.negocio_id = v_neg and cl.es_general limit 1;
  end if;

  p_tipo_venta := coalesce(nullif(btrim(p_tipo_venta), ''), 'local');
  if length(p_tipo_venta) > 30 then raise exception 'Tipo de venta no válido' using errcode = '22023'; end if;

  -- ---- cabecera (número correlativo + idempotencia en un bloque: si choca, se deshace el número) ----
  begin
    v_nro := private.siguiente_numero(v_neg, c.sucursal_id, 'venta');
    insert into public.ventas (negocio_id, sucursal_id, caja_id, nro_venta, cliente_id, usuario_id,
                               tipo_venta, condicion, total, paga_con, vuelto, nota, fecha_entrega, idempotency_key)
    values (v_neg, c.sucursal_id, c.id, v_nro, v_cliente, v_uid, p_tipo_venta, p_condicion, v_total,
            case when p_condicion = 'contado' then v_pagado end,
            case when p_condicion = 'contado' then v_vuelto end,
            p_nota, p_fecha_entrega, p_idempotency_key)
    returning id into v_venta;
  exception when unique_violation then
    select v.id, v.nro_venta, v.total, v.vuelto into v_dup
      from public.ventas v where v.sucursal_id = c.sucursal_id and v.idempotency_key = p_idempotency_key;
    if found then
      return jsonb_build_object('venta_id', v_dup.id, 'nro_venta', v_dup.nro_venta,
                                'total', v_dup.total, 'vuelto', coalesce(v_dup.vuelto, 0), 'duplicada', true);
    end if;
    raise;
  end;

  -- ---- ítems + stock (filas de inventario bloqueadas en orden fijo para evitar bloqueos cruzados) ----
  v_permite_neg := coalesce((select lower(n.config->>'permitir_stock_negativo') = 'true'
                               from public.negocios n where n.id = v_neg), false);
  -- NUEVO (13): el mismo producto con notas distintas se guarda en líneas separadas.
  for r in
    select it.producto_id, it.cant, it.precio, it.nota, p.nombre, p.codigo, p.controla_stock, p.precio_venta, p.precio_costo
      from (select x.producto_id, round(x.precio, 2) as precio, nullif(btrim(x.nota), '') as nota,
                   sum(round(x.cantidad, 3)) as cant
              from jsonb_to_recordset(p_items) as x(producto_id uuid, cantidad numeric, precio numeric, nota text)
             group by x.producto_id, round(x.precio, 2), nullif(btrim(x.nota), '')) it
      join public.productos p on p.id = it.producto_id and p.negocio_id = v_neg
     order by it.producto_id, it.precio nulls first, it.nota nulls first
  loop
    if r.controla_stock then
      select i.stock into v_stock from public.inventario i
       where i.sucursal_id = c.sucursal_id and i.producto_id = r.producto_id for update;
      if not found then
        raise exception 'El producto "%" no tiene inventario en esta sucursal', r.nombre using errcode = '22023';
      end if;
      if v_stock < r.cant and not v_permite_neg then
        raise exception 'Stock insuficiente de "%": disponible %, solicitado %', r.nombre, v_stock, r.cant
          using errcode = 'MS001';
      end if;
      update public.inventario set stock = stock - r.cant
       where sucursal_id = c.sucursal_id and producto_id = r.producto_id
      returning stock into v_stock;
      insert into public.movimientos_inventario
        (negocio_id, sucursal_id, producto_id, tipo, cantidad, stock_resultante, referencia_tipo, referencia_id, usuario_id)
      values (v_neg, c.sucursal_id, r.producto_id, 'venta', -r.cant, v_stock, 'venta', v_venta, v_uid);
    end if;
    insert into public.venta_items
      (negocio_id, sucursal_id, venta_id, producto_id, nombre_snapshot, codigo_snapshot,
       cantidad, precio_unitario, costo_unitario, total, nota)
    values (v_neg, c.sucursal_id, v_venta, r.producto_id, r.nombre, r.codigo,
            r.cant, coalesce(r.precio, r.precio_venta), r.precio_costo,
            round(coalesce(r.precio, r.precio_venta) * r.cant, 2), r.nota);
  end loop;

  if v_mods is not null then
    insert into public.auditoria (negocio_id, usuario_id, accion, entidad, entidad_id, despues)
    values (v_neg, v_uid, 'PRECIO_MODIFICADO', 'ventas', v_venta::text,
            jsonb_build_object('nro_venta', v_nro, 'lineas', v_mods));
  end if;

  -- ---- pagos (el vuelto se descarta del efectivo para que lo guardado sea lo realmente cobrado) ----
  v_resto := v_vuelto;
  for pago in
    select x.metodo::public.metodo_pago as metodo, round(x.monto, 2) as monto
      from jsonb_to_recordset(p_pagos) as x(metodo text, monto numeric)
     order by (x.metodo = 'efectivo') desc, x.monto desc
  loop
    v_monto := pago.monto;
    if pago.metodo = 'efectivo' and v_resto > 0 then
      v_take := least(pago.monto, v_resto);
      v_monto := pago.monto - v_take;
      v_resto := v_resto - v_take;
    end if;
    if v_monto > 0 then
      insert into public.venta_pagos (negocio_id, sucursal_id, venta_id, caja_id, metodo, monto, usuario_id)
      values (v_neg, c.sucursal_id, v_venta, c.id, pago.metodo, v_monto, v_uid);
    end if;
  end loop;

  return jsonb_build_object('venta_id', v_venta, 'nro_venta', v_nro, 'total', v_total,
                            'vuelto', v_vuelto, 'saldo', v_total - least(v_pagado, v_total), 'duplicada', false);
end $$;

create or replace function public.ventas_detalle(
  p_sucursal   uuid,
  p_desde      timestamptz default null,
  p_hasta      timestamptz default null,
  p_limite     int         default 2000,
  p_antes      timestamptz default null,
  p_solo_deuda boolean     default false,
  p_ids        uuid[]      default null,
  p_antes_nro  bigint      default null)
returns jsonb language plpgsql stable set search_path = '' as $$
declare v_res jsonb;
begin
  if p_ids is null and not coalesce(p_solo_deuda, false) and (p_desde is null or p_hasta is null) then
    raise exception 'Indica el rango de fechas (desde y hasta)' using errcode = '22023';
  end if;
  if p_ids is not null and coalesce(array_length(p_ids, 1), 0) > 500 then
    raise exception 'Máximo 500 ventas por consulta' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.fecha desc, x.nro_venta desc), '[]'::jsonb)
    into v_res
    from (
      select v.id, v.caja_id, ca.monto_inicial as caja_inicial, v.nro_venta, v.fecha,
             v.cliente_id, cl.nombre as cliente, v.usuario_id, pf.nombre as vendedor,
             v.tipo_venta, v.condicion, v.estado, v.total, v.paga_con, v.vuelto,
             v.total_pagado, v.saldo, v.nota, v.fecha_entrega,
             coalesce((select jsonb_agg(jsonb_build_object(
                          'producto_id', i.producto_id, 'nombre', i.nombre_snapshot, 'cantidad', i.cantidad,
                          'precio', i.precio_unitario, 'costo', i.costo_unitario, 'total', i.total,
                          'nota', i.nota)
                        order by i.nombre_snapshot, i.id)
                         from public.venta_items i where i.venta_id = v.id), '[]'::jsonb) as items,
             coalesce((select jsonb_agg(jsonb_build_object(
                          'metodo', p.metodo, 'monto', p.monto, 'fecha', p.fecha) order by p.fecha, p.id)
                         from public.venta_pagos p where p.venta_id = v.id), '[]'::jsonb) as pagos
        from public.ventas v
        left join public.cajas    ca on ca.id = v.caja_id
        left join public.clientes cl on cl.id = v.cliente_id and cl.negocio_id = v.negocio_id
        left join public.perfiles pf on pf.user_id = v.usuario_id
       where v.sucursal_id = p_sucursal
         and case
               when p_ids is not null           then v.id = any (p_ids)
               when coalesce(p_solo_deuda, false) then (v.condicion = 'credito' and v.estado = 'completada' and v.saldo > 0)
               else (v.fecha >= p_desde and v.fecha < p_hasta)
             end
         -- paginación: "las que vienen después de la última recibida" (fecha y, si se indica, número de venta)
         and (p_antes is null
              or case when p_antes_nro is null then v.fecha < p_antes
                      else (v.fecha, v.nro_venta) < (p_antes, p_antes_nro) end)
       order by v.fecha desc, v.nro_venta desc
       limit least(greatest(coalesce(p_limite, 2000), 1), 5000)
    ) x;
  return v_res;
end $$;

-- ---------------------------------------------------------------- B) INACTIVIDAD
alter table public.negocios add column if not exists minutos_inactividad smallint not null default 30;
alter table public.negocios drop constraint if exists negocios_minutos_inactividad_valores;
alter table public.negocios add constraint negocios_minutos_inactividad_valores
  check (minutos_inactividad in (0, 15, 30, 60, 120));

create or replace function public.guardar_inactividad_negocio(p_negocio uuid, p_minutos int)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then raise exception 'Sesión requerida' using errcode = '42501'; end if;
  if not exists (
    select 1 from public.membresias m join public.negocios n on n.id = m.negocio_id
     where m.user_id = (select auth.uid()) and m.negocio_id = p_negocio
       and m.rol = 'admin_negocio' and m.activo and n.activo) then
    raise exception 'No tienes permiso para cambiar la configuración de este negocio' using errcode = '42501';
  end if;
  if p_minutos is null or p_minutos not in (0, 15, 30, 60, 120) then
    raise exception 'Tiempo de inactividad no válido' using errcode = '22023';
  end if;
  update public.negocios set minutos_inactividad = p_minutos where id = p_negocio;
end $$;

-- ---------------------------------------------------------------- PERMISOS
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname in ('registrar_venta', 'ventas_detalle', 'guardar_inactividad_negocio')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;

commit;

-- Comprobación: debe mostrar 2 filas (venta_items.nota y negocios.minutos_inactividad).
select table_name, column_name, data_type
  from information_schema.columns
 where table_schema = 'public'
   and ((table_name = 'venta_items' and column_name = 'nota')
     or (table_name = 'negocios' and column_name = 'minutos_inactividad'));
