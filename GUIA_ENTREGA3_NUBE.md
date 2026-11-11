# MULTISOFT · Entrega 3 del modo nube: reportes de cualquier período y abonos por QR

Se activa SOLO con usuarios de Supabase. Requiere haber ejecutado en Supabase el script `11_reportes.sql`
(ver `LEEME_ORDEN.md` en la carpeta de scripts).

## Qué cambió
1. **Historial y reportes de cualquier período.** Al entrar se cargan los últimos 31 días. Cuando eliges fechas
   en el **Historial**, **Ganancias**, **Más vendidos** o **Créditos**, el sistema descarga ese período de la nube
   (unos segundos si es largo) y recién entonces muestra el reporte. Lo ya descargado no se vuelve a pedir.
2. **Las deudas pendientes se cargan SIEMPRE**, sin importar su antigüedad: el reporte de créditos ya no pierde
   deudas viejas.
3. **Entrar es más rápido**: antes eran muchas consultas por cada 100 ventas; ahora son 2 en total.
4. **Abonos en efectivo o QR.** Al pagar una deuda el sistema pregunta: `1 = Efectivo`, `2 = QR`.
   El abono por QR no suma al efectivo de la caja (sí a lo cobrado por QR).
5. Corregido: una venta a crédito reciente podía aparecer dos veces en el historial.

## Cómo probarlo
1. Entra con `andres`. Abre el **Historial** y elige un período antiguo con ventas (por ejemplo, desde hace 2 meses):
   debe tardar un instante y mostrar esas ventas.
2. Vuelve a elegir el mismo período: ahora debe ser inmediato.
3. Abre **Ganancias**, **Más vendidos** y **Créditos** con fechas distintas y comprueba que los totales coincidan con el historial.
4. Registra una venta a crédito, y abónale una parte **por QR** y otra **en efectivo**. Comprueba que el cuadro de la caja
   solo sube con el efectivo.
5. Imprime un reporte de un período largo: se imprime después de descargar los datos.

## Límites
- Un período con más de 20 000 ventas se carga parcialmente (con aviso): acorta el rango.
- Si solo eliges "Hasta" (sin "Desde") se muestran los 31 días anteriores a esa fecha.
- Los filtros de fecha usan el día en hora UTC, igual que el sistema anterior (una venta de la noche puede caer en el día siguiente).
- Una venta de una caja ya cerrada no se puede anular.

## Si algo falla
Copia el texto exacto del aviso rojo (❌); para más detalle, en Chrome pulsa F12 → pestaña Console y copia lo que salga en rojo.
