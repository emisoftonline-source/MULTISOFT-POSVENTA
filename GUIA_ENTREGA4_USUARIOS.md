# MULTISOFT · Entrega 4: usuarios solo en Supabase, fecha de registro y restablecer contraseñas

## Qué cambió
1. **Se eliminó por completo el registro de usuarios del sistema anterior** (Firebase `config/usuarios_globales` + IndexedDB):
   formulario "Responsables locales", tabla con contraseñas visibles, editar/eliminar, reporte, selector "Negocio / Sede"
   del login y el usuario por defecto `Admin / 1234` que se creaba solo. Al abrir el sistema se borra la copia local
   que quedara en el navegador.
   Ahora solo se entra con Supabase: el superadministrador con su **correo** y los responsables con su **usuario**.
2. **Fecha de registro automática**: la tabla "Usuarios registrados" muestra la fecha y hora en que se creó cada cuenta
   (la guarda Supabase al crearla) y el **último ingreso**. Se puede buscar y filtrar por rango de fechas de registro.
3. **Restablecer contraseña de cualquier usuario** (botón 🔑 en cada fila, solo superadministrador). Propone una
   contraseña segura (🎲) que puedes cambiar; queda registrado en `auditoria` como `RESETEAR_CLAVE` (sin la contraseña).
4. **Login con Enter**: usuario y contraseña ahora están en un formulario; Enter (en el teclado de la PC o "Ir" en el
   celular) ingresa igual que el botón. Mientras verifica, el botón dice "⏳ Verificando..." y no se puede pulsar dos veces.
5. La pestaña **RESPONSABLES** solo la ve el superadministrador (el administrador de negocio ya no la ve).
6. **Ajustes (CONFIG)**: se quitaron *Ajuste de Inventario*, *Migración Total* y *Respaldo y Restauración*.
   Para aumentar stock o cambiar el vencimiento usa el botón **AUMENTAR** de **PRODUCTOS**; para nombre y código, el ✏️ del producto.
   CONFIG queda solo con el nombre y el logo del negocio, y solo la ven los administradores.

## Paso obligatorio: instalar la nueva función (una sola vez)
Igual que hiciste con `multisoft-crear-responsable`:
1. Supabase (proyecto **multisoft-staging**) → **Edge Functions** → **Deploy a new function** → **Via Editor**.
2. Nombre exacto: `multisoft-gestionar-usuarios`
3. Pega TODO el contenido de `multisoft-gestionar-usuarios_para_pegar.ts` → **Deploy**.
4. En **Settings** de esa función: *Verify JWT with legacy secret* → **desactivado** (igual que la otra función;
   la función comprueba la sesión y que seas superadministrador en su propio código).
5. Prueba sin riesgo: en la función → **Test** → POST con cuerpo `{}` → debe responder **401**.

No hay que ejecutar ningún SQL nuevo.

## Cómo probarlo
1. Abre `index.html`, escribe tu correo y contraseña y pulsa **Enter** (sin usar el ratón): debe entrar.
2. Pestaña **RESPONSABLES** → la tabla muestra a todos los usuarios con su fecha de registro.
3. Crea un cajero de prueba: debe aparecer arriba con la fecha y hora de ahora.
4. Pulsa 🔑 en ese cajero → guarda una contraseña nueva → cierra sesión → entra como ese cajero con la nueva
   contraseña (la anterior ya no debe funcionar).
5. Comprueba en `auditoria` que aparecen `CREAR_RESPONSABLE` y `RESETEAR_CLAVE`.

## Pendiente tuyo (no se puede hacer desde el HTML)
- Borrar en la consola de Firebase el documento `config/usuarios_globales`: guardaba las contraseñas de los usuarios
  antiguos **sin cifrar** y el sistema ya no lo usa.

## Si algo falla
- "La función multisoft-gestionar-usuarios no está desplegada" → falta el paso obligatorio de arriba.
- Cualquier otro aviso rojo: copia el texto exacto y el mensaje de **Logs** de la función. Nunca pegues claves.
