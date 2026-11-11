# MULTISOFT · Entrega 1 del modo nube: productos, fotos, stock y clientes

Se activa SOLO al entrar con un usuario creado en Supabase (por ejemplo `andres`, administrador de Farmacia Ucg).
Los usuarios del método anterior (Firebase) siguen funcionando igual que antes.

## Qué puedes probar
1. **Entrar** con `andres` y su contraseña. La lista empieza vacía (los datos vienen de Supabase, no de Firebase).
2. **Crear un producto** con nombre, código, precios, categoría, stock inicial, vencimiento y **foto**.
3. **Editar** un producto (en el formulario o en la fila de la tabla): cambiar precio, stock, nombre o foto.
4. **Ajustar stock**: sumar mercadería y cambiar el vencimiento (botones de ajuste).
5. **Eliminar** un producto: desaparece de la lista (en la base queda desactivado, no borrado).
6. **Clientes**: crear, editar y eliminar.
7. **Tiempo real**: abre el sistema en OTRO navegador o en el celular, entra con el mismo usuario, cambia el stock
   en uno y mira cómo se actualiza el otro solo (puede tardar un par de segundos).
8. Entra con un **cajero** (por ejemplo `raul`): debe ver los productos y clientes pero NO poder crear/editar/eliminar productos.

## Qué NO está todavía (siguiente entrega)
- Caja (abrir/cerrar), ventas, anulaciones, abonos de crédito, historial y reportes.
  Con una cuenta de la nube esos botones muestran un aviso; NO escriben nada en Firebase.
- Logo del negocio y creación de usuarios desde el administrador del negocio.

## Cómo comprobar que se guardó en Supabase (SQL Editor, solo lectura)
```sql
-- Productos del negocio con su stock en la sucursal
select p.codigo, p.nombre, p.precio_venta, p.activo, p.imagen_path, i.stock, i.vencimiento
from public.productos p
left join public.inventario i on i.producto_id = p.id
where p.negocio_id = (select id from public.negocios where codigo = 'far001')
order by p.creado_en desc;

-- Quién cambió el stock y por qué
select m.creado_en, p.nombre, m.tipo, m.cantidad, m.stock_resultante, m.nota
from public.movimientos_inventario m join public.productos p on p.id = m.producto_id
where m.negocio_id = (select id from public.negocios where codigo = 'far001')
order by m.creado_en desc limit 20;

-- Historial automático de precios
select p.nombre, h.precio_costo, h.precio_venta, h.vigente_desde
from public.precios_historial h join public.productos p on p.id = h.producto_id
where h.negocio_id = (select id from public.negocios where codigo = 'far001')
order by h.vigente_desde desc limit 20;
```

## Si algo falla
Copia el texto EXACTO del aviso rojo (❌). Para más detalle, en Chrome pulsa F12 → pestaña **Console** y copia lo que salga en rojo.
