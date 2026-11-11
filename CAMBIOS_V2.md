# MULTISOFT v2 - Cambios respecto a la versión anterior

## Seguridad
1. Se eliminó el usuario semilla `superadmin` (clave maestra) de la lista de usuarios por defecto.
2. Al iniciar sesión se purga cualquier `SUPER_ADMIN` heredado guardado en IndexedDB/Firestore,
   y la rama de login antigua ya no acepta ese rol.
3. Cualquier usuario que contenga `@` inicia sesión con Supabase Auth; el permiso de superadmin
   se decide por `perfiles.es_superadmin` (ya no hay un correo escrito en el HTML).
4. El SDK de Supabase queda fijado en la versión exacta 2.45.4.
5. La Edge Function `multisoft-crear-responsable` registra en `auditoria` quién creó cada usuario.

## Corrección funcional
6. Al crear un negocio, la sucursal inicial que crea la base de datos se RENOMBRA
   (antes se insertaba una segunda sucursal duplicada).

## Pendiente tuyo
- Borrar a mano el usuario `godmode` del documento `config/usuarios_globales` en Firestore.
- Revisar las reglas de Firestore.
- Volver a desplegar la función (ver INSTRUCCIONES_DESPLIEGUE_FUNCION.txt).
- Probar solo en multisoft-staging; no usar todavía con ventas reales.
- No se añadió el atributo `integrity` al SDK (requiere calcular el hash con internet).

## Estructura
- index.html, supabase-config.js, logos e imagen de fondo: van en la MISMA carpeta.
- supabase/config.toml y supabase/functions/...: solo para desplegar la función con la CLI.

## Despliegue sin instalar nada
- Usa `multisoft-crear-responsable_para_pegar.ts` en el editor web de Supabase (ver GUIA_PRUEBA_STAGING.md).
- La carpeta supabase/ del ZIP solo sirve si algún día usas la CLI.

## Usuario sin código de negocio (decisión del 20-oct-2026)
- El usuario de acceso se guarda tal como se escribe (minúsculas) y es único en todo el sistema.
- Nombres reservados: superadmin, admin, administrador, root, soporte, multisoft, sistema.
- Los usuarios ya creados (p. ej. sbecerra.ferre001) conservan su nombre.

## Login de responsables con Supabase Auth (21-oct-2026)
- Un usuario sin '@' se prueba primero contra Supabase Auth (usuario + contraseña, sin código de negocio).
- Entran solo cuentas con perfil activo, membresía activa de rol admin_negocio o cajero, y negocio y sucursal activos.
- El negocio y la sucursal salen de la membresía del usuario, no del selector de la pantalla de login.
- Si las credenciales no son de una cuenta cloud, se usa el método anterior (usuarios locales/Firebase) para no romper lo existente.
- LIMITACIÓN: ventas, caja e inventario siguen en Firebase/IndexedDB; este login identifica al responsable pero no aísla esos datos todavía.

## Entrega 1 del modo nube (24-oct-2026)
- Nuevo bloque <script> al final de index.html (MODO NUBE). Solo actúa con cuentas de Supabase.
- Productos (con fotos en Storage), stock (por la función ajustar_inventario), clientes y actualización en tiempo real.
- En modo nube no se escribe nada en Firebase ni en IndexedDB. Caja y ventas quedan bloqueadas con un aviso hasta la siguiente entrega.
- Requiere haber ejecutado los scripts 01 a 03, 05, 07 y 09 en Supabase.

## Entrega 2 del modo nube (25-oct-2026)
- El bloque MODO NUBE ahora incluye caja y ventas: abrir/cerrar caja, venta en efectivo/QR/crédito, abonos, anulaciones, historial y tiempo real.
- Las reglas las aplican las funciones de la base de datos (scripts 05, 07 y 09); el HTML solo las llama.
- Reintentos seguros ante cortes de internet (clave de idempotencia): nunca se duplica una venta.
- Bloqueados en modo nube: eliminar ventas, limpiar ventas y editar notas (las ventas se anulan, no se borran).
- Requiere haber ejecutado en Supabase los scripts 01 a 03, 05, 07 y 09.

## Entrega 3 del modo nube (27-oct-2026)
- Historial y reportes de cualquier período: se descargan bajo demanda; las deudas pendientes se cargan siempre.
- Carga inicial en 2 consultas (función ventas_detalle) en vez de una por cada 100 ventas.
- Abonos en efectivo o QR. Corregida una venta a crédito que aparecía duplicada.
- Requiere el script 11_reportes.sql en Supabase.

## Entrega 4: usuarios (10-nov-2026)
- Eliminado el registro de usuarios del sistema anterior (Firebase/IndexedDB), el selector Negocio/Sede del login
  y el usuario por defecto Admin/1234. Solo se inicia sesión con Supabase.
- Tabla "Usuarios registrados" con fecha de registro automática y último ingreso, búsqueda y filtro por fechas.
- Restablecer la contraseña de cualquier usuario (nueva función `multisoft-gestionar-usuarios`, auditada).
- El login funciona con Enter (formulario) y evita dobles envíos.
- La pestaña RESPONSABLES es solo para el superadministrador.
- Requiere desplegar `multisoft-gestionar-usuarios` (ver GUIA_ENTREGA4_USUARIOS.md). No hay SQL nuevo.
- Ajustes (CONFIG): se quitaron "Ajuste de Inventario", "Migración Total (Respaldo Maestro)" y
  "Respaldo y Restauración de Datos". El stock, vencimiento, nombre y código se cambian desde PRODUCTOS.
  CONFIG queda solo con nombre y logo del negocio, y ya no la ven cajeros ni almacén.

## Entrega 5: configuración del negocio y Excel (10-nov-2026)
- CONFIG guarda el nombre comercial y el logo en Supabase (función `guardar_config_negocio`, solo admin_negocio, auditada).
- Nuevo botón "Descargar mis datos (Excel)" para el administrador del negocio: 7 hojas, solo datos de su negocio.
- El superadministrador ya no ve CONFIG.
- Requiere ejecutar `sql/12_config_negocio.sql` (ver GUIA_ENTREGA5_CONFIG_EXCEL.md).

## Firebase eliminado (10-nov-2026)
- Se quitaron el SDK de Firebase, su configuración (proyecto multisoft-1c356) y toda la sincronización con Firestore.
- Se dejó de usar el almacenamiento local del navegador (IndexedDB). Todos los datos se leen y guardan en Supabase.
- Al abrir el sistema se borra de cada navegador la lista de usuarios antigua (contraseñas sin cifrar);
  el resto de la base local antigua `SistemaMultiserviciosDB` no se toca.
- No requiere cambios en Supabase.

## Ajustes de pantalla (10-nov-2026)
- Carrito de NUEVA VENTA: la foto del producto se ve completa (sin recortar), más grande (64 px) y se amplía con un clic.
- HISTORIAL, filtro "Cajero/Resp.": muestra a todo el personal activo del negocio (con su rol) y a cualquier
  persona que aparezca en las ventas cargadas (por ejemplo, un cajero que ya no está). Antes solo mostraba "Todos".

## Entrega 8: el administrador gestiona a sus cajeros (10-nov-2026)
- CONFIG → "Mi personal": el admin_negocio restablece contraseñas y activa/desactiva a SUS cajeros.
- El superadministrador también puede activar/desactivar usuarios desde RESPONSABLES.
- Desactivar = membresía inactiva + cuenta bloqueada en Auth (cierra el acceso). Las ventas se conservan.
- Requiere volver a desplegar `multisoft-gestionar-usuarios` (ver GUIA_ENTREGA8_MI_PERSONAL.md). Sin SQL nuevo.

## Entrega 9: notas por producto e inactividad (11-nov-2026)
- Nota por línea del carrito (atajos + texto libre); el mismo producto con notas distintas va en líneas separadas.
  Sale en orden de cocina (resaltada), ticket, orden de entrega, historial y Excel. Se guarda en venta_items.nota.
- Cierre de sesión por inactividad configurable por negocio (15/30/60/120 min o nunca), con aviso de 60 s,
  sin cerrar si hay productos en el carrito y sincronizado entre pestañas.
- Requiere `sql/13_notas_e_inactividad.sql` (ver GUIA_ENTREGA9_NOTAS_INACTIVIDAD.md).
