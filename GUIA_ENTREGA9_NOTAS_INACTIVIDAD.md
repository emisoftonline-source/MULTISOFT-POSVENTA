# MULTISOFT · Entrega 9: notas por producto y cierre de sesión por inactividad

## Paso obligatorio en Supabase (una sola vez)
1. Supabase (proyecto **multisoft-staging**) → **SQL Editor** → **New query**.
2. Pega TODO el contenido de `sql/13_notas_e_inactividad.sql` → **Run**.
3. Al final debe mostrar 2 filas: `venta_items.nota` y `negocios.minutos_inactividad`.

El script redefine `registrar_venta` y `ventas_detalle` partiendo EXACTAMENTE de tus versiones actuales
(scripts 09 y 11); solo se agrega la nota. Precios, permisos, stock, pagos e idempotencia no cambian.
Se puede volver a ejecutar sin problema. No borra datos.

## 1. Nota por producto
- En el carrito, cada línea tiene **📝 Nota**: atajos rápidos (Sin cebolla, Sin papas, Sin picante, Para llevar...)
  y texto libre (máx. 200 caracteres).
- Si la línea tiene varias unidades, eliges **cuántas** llevan la nota: p. ej. 3 hamburguesas → 2 normales y
  1 "sin cebolla" quedan en líneas separadas.
- **Orden de cocina**: la nota sale en MAYÚSCULAS y en un recuadro debajo del plato.
- **Ticket del cliente y orden de entrega**: la nota sale debajo del producto.
- **Historial**: las ventas con notas muestran 📝 (pasa el ratón sobre el producto para verlas).
  Al reimprimir un ticket, las notas siguen saliendo.
- **Excel**: columna "Nota" en la hoja "Detalle de ventas".

## 2. Cierre de sesión por inactividad
- El administrador del negocio lo elige en **CONFIG**: 15 min, 30 min (por defecto), 1 hora, 2 horas o Nunca.
  Se aplica a todo el personal del negocio. Superadministrador: 30 minutos fijos.
- Un minuto antes aparece "¿Sigues ahí?" con cuenta regresiva y el botón **SEGUIR TRABAJANDO**.
- Cuenta como actividad mover el ratón, teclear, tocar la pantalla o desplazarse.
- **No se cierra si hay productos en el carrito** (no se pierde una venta a medio armar).
- Con varias pestañas abiertas cuenta la actividad de cualquiera; si una se cierra por inactividad, las demás también.
- Cerrar sesión **no cierra la caja** ni pierde datos: al volver a entrar todo sigue igual.
- En la pantalla de ingreso aparece: "Tu sesión se cerró por inactividad".

## Cómo probarlo
1. Ejecuta el script 13.
2. Entra como `andres`, abre caja, agrega 3 unidades de un producto, pulsa 📝 Nota, elige "Sin cebolla",
   pon 1 unidad y guarda: deben quedar 2 líneas.
3. Registra la venta marcando ticket de cliente y orden de cocina: revisa que la nota salga en ambos.
4. Reimprime la venta desde el Historial: la nota debe seguir saliendo.
5. En CONFIG elige "15 minutos", guarda y deja el sistema sin tocar: a los 14 min sale el aviso y a los 15 se cierra.

## Si no ejecutas el script 13
- Las ventas se registran igual, pero **las notas no se guardan** (no saldrán en el ticket).
- Al guardar el tiempo de inactividad aparecerá "Falta ejecutar en Supabase el script 13_notas_e_inactividad.sql".
