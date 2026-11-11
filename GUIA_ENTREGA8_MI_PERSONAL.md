# MULTISOFT · Entrega 8: el administrador de negocio gestiona a sus cajeros

## Qué cambió
1. **CONFIG → "Mi personal"** (solo administrador de negocio): lista sus cajeros con fecha de registro y último
   ingreso, y por cada uno:
   - 🔑 **Contraseña**: pone una contraseña nueva (propone una segura).
   - ⛔ **Desactivar** / ✅ **Activar**: un cajero desactivado no puede entrar; si estaba conectado se le cierra
     el acceso. Sus ventas se conservan.
2. **RESPONSABLES** (superadministrador): cada usuario de negocio tiene también ⛔ Desactivar / ✅ Activar.
3. Si un cajero desactivado intenta entrar ve: "Tu cuenta está desactivada. Consulta al administrador de tu negocio."
4. Todo queda en `auditoria`: `RESETEAR_CLAVE`, `ACTIVAR_RESPONSABLE`, `DESACTIVAR_RESPONSABLE` (indica si lo hizo
   el superadmin o el admin_negocio).

## Reglas de seguridad (las aplica el servidor, no la pantalla)
- El administrador de negocio solo ve y gestiona **cajeros de su propio negocio** (negocio activo).
- No puede tocar a otros administradores, a superadministradores ni su propia cuenta.
- El superadministrador puede gestionar a cualquier usuario (los superadministradores no se desactivan desde aquí).
- Crear cuentas nuevas sigue siendo solo del superadministrador.

## Paso obligatorio: actualizar la función (no hay SQL nuevo)
1. Supabase (proyecto **multisoft-staging**) → **Edge Functions** → `multisoft-gestionar-usuarios` → **Code**.
2. Borra todo y pega el contenido de `multisoft-gestionar-usuarios_para_pegar.ts` → **Deploy**.
3. Deja *Verify JWT with legacy secret* **desactivado** (como antes).

## Cómo probarlo
1. Entra como `andres` (administrador) → **CONFIG** → "Mi personal": deben aparecer solo tus cajeros.
2. 🔑 a un cajero de prueba → entra con él usando la nueva contraseña.
3. ⛔ Desactívalo → intenta entrar con él: debe salir el aviso de cuenta desactivada.
4. ✅ Actívalo de nuevo → debe poder entrar.
5. Como superadministrador, en RESPONSABLES comprueba que también puedes activar/desactivar.
6. Revisa en `auditoria` las acciones registradas.
