# MULTISOFT · Entrega 5: nombre y logo del negocio en la nube + "Descargar mis datos (Excel)"

## Qué cambió
1. **CONFIG guarda de verdad el nombre comercial y el logo** del negocio en Supabase. Antes, con una cuenta de la nube,
   decía "guardada" pero no se guardaba en ningún lado. Ahora lo ve todo el personal del negocio en cualquier
   computadora o celular (al volver a entrar), en la cabecera y en los tickets/reportes impresos.
   - Solo el **administrador del negocio** puede cambiarlo; queda en `auditoria` como `CONFIG_NEGOCIO`.
   - El nombre oficial del negocio (el que pone el superadministrador) no cambia: es un nombre comercial aparte.
2. **Descargar mis datos (Excel)**: en CONFIG, el administrador del negocio elige un período y descarga un archivo con
   7 hojas: Resumen (totales, ganancia, deudas), Productos, Clientes, Ventas, Detalle de ventas, Abonos y Deudas pendientes.
   - Productos, clientes y deudas pendientes van completos; ventas y abonos, del período (sin fechas = mes actual).
   - Las ventas anuladas aparecen marcadas como ANULADA y no suman en el resumen.
3. El superadministrador ya no ve CONFIG (lo que guardaba ahí solo quedaba en su navegador).

## Paso obligatorio en Supabase (una sola vez)
1. Supabase (proyecto **multisoft-staging**) → **SQL Editor** → **New query**.
2. Pega TODO el contenido de `sql/12_config_negocio.sql` → **Run**.
3. Al final debe mostrar 2 filas: `nombre_comercial` y `logo`.
   El script se puede volver a ejecutar sin problema y no borra datos.

Si no lo ejecutas, el sistema sigue funcionando con el nombre oficial, pero al guardar en CONFIG aparecerá:
"Falta ejecutar en Supabase el script 12_config_negocio.sql".

## Cómo probarlo
1. Entra con un **administrador de negocio** (por ejemplo `andres`) → **CONFIG**.
2. Cambia el nombre comercial, elige un logo y pulsa **Guardar**: la cabecera cambia al instante.
3. Cierra sesión y entra con un **cajero** del mismo negocio: debe ver el mismo nombre y logo.
4. En **Descargar mis datos (Excel)** pulsa **DESCARGAR EXCEL** sin fechas (mes actual) y abre el archivo.
   Compara el "Total vendido" del Resumen con GANANCIAS del mismo período.
5. Prueba un período antiguo (por ejemplo los últimos 3 meses).

## Límites
- El Excel incluye la **sucursal con la que entraste** (si el negocio tiene varias, se descarga una por sesión).
- Los días se cuentan en hora UTC, igual que el resto de los reportes (una venta de la noche puede caer en el día siguiente).
- Más de 20 000 ventas en el período: se incluyen las más recientes (con aviso). Acorta el rango.
- El generador de Excel (SheetJS) se descarga de internet la primera vez que pulsas el botón.
