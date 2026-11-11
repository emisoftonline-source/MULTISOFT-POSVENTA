# MULTISOFT · Entrega 2 del modo nube: caja y ventas

Se activa SOLO al entrar con un usuario de Supabase (`andres` = administrador, `raul` = cajero).
Los usuarios del método anterior (Firebase) siguen funcionando igual que antes.

## Qué puedes probar (en este orden)
**Con el administrador (`andres`)**
1. **Abrir caja** con un monto inicial (por ejemplo 100). Solo el administrador puede abrirla.
2. **Vender en efectivo**: agrega productos, "paga con" un monto mayor y mira el cambio. Se imprime el ticket si está marcado.
3. **Vender por QR**.
4. **Vender a crédito**: elige un cliente, pon un anticipo menor al total, fecha de entrega y nota.
5. **Registrar un abono** a esa venta a crédito (botón de pago en el historial). La deuda baja.
6. **Anular una venta**: pide un motivo (mínimo 5 letras) y devuelve el stock.
7. Mira que el cuadro de la caja muestra el **efectivo real** (inicial + efectivo cobrado − egresos), no los QR ni los créditos sin cobrar.

**Con el cajero (`raul`) en otro navegador o en el celular**
8. Debe ver la caja abierta por el administrador y poder vender. NO puede abrir caja ni anular ventas.
9. **Cerrar caja**: cuenta el efectivo y lo escribe. El cajero NO ve cuánto debía haber (arqueo a ciegas); el administrador SÍ ve el sistema, lo contado y la diferencia.

**Tiempo real**
10. Con el administrador mirando el historial en la PC, el cajero vende desde el celular: la venta aparece sola en la PC en unos segundos.

**Corte de internet**
11. Apaga el wifi justo al pulsar "Registrar venta": aparece un aviso y el carrito se conserva. Enciende el wifi y vuelve a pulsar: se registra UNA sola venta (nunca dos).

## Reglas que aplica la base de datos (no solo la pantalla)
- Solo el administrador abre caja; cajero/administrador cierran; solo el administrador anula (con motivo y solo con la caja abierta).
- No se vende sin stock suficiente. El precio sale siempre del producto.
- El cambio (vuelto) solo puede salir de efectivo; un crédito siempre debe dejar saldo y necesita un cliente identificado.
- Las ventas no se borran: se anulan. Cada cambio de stock queda registrado.

## Límites de esta entrega
- El historial en pantalla muestra los **últimos 31 días** (máximo 1500 ventas). Los reportes de períodos largos vienen después.
- Los abonos se registran en efectivo. La nota de una venta ya hecha no se puede editar todavía.
- Cada usuario trabaja en UNA sucursal (la de su membresía). El administrador entra a la primera sucursal por orden alfabético.
- El campo de precio de la pantalla de venta está bloqueado (como antes): el cambio de precio por administrador/gerente existe en la base pero aún no tiene botón.
- Una venta de una caja ya cerrada no se puede anular.

## Comprobar en Supabase (SQL Editor, solo lectura)
```sql
-- Últimas ventas con quién las hizo y cómo se pagaron
select v.nro_venta, v.fecha, v.total, v.condicion, v.estado, p.nombre as vendedor, v.total_pagado, v.saldo
from public.ventas v join public.perfiles p on p.user_id = v.usuario_id
where v.negocio_id = (select id from public.negocios where codigo = 'far001')
order by v.fecha desc limit 20;

-- Resumen de cada caja
select nombre, estado, monto_inicial, ventas, total_vendido, cobrado_efectivo, cobrado_qr, egresos,
       monto_cierre_declarado, monto_cierre_sistema
from public.v_caja_resumen
where negocio_id = (select id from public.negocios where codigo = 'far001')
order by abierta_en desc limit 10;

-- Anulaciones y cambios de precio auditados
select creado_en, accion, entidad, despues
from public.auditoria
where negocio_id = (select id from public.negocios where codigo = 'far001')
  and (accion = 'PRECIO_MODIFICADO' or (entidad = 'ventas' and accion = 'UPDATE'))
order by creado_en desc limit 20;
```

## Si algo falla
Copia el texto EXACTO del aviso rojo (❌). Para más detalle, en Chrome pulsa F12 → pestaña **Console** y copia lo que salga en rojo.
