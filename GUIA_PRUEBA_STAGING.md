# MULTISOFT · Guía de prueba en staging (paso a paso)

Todo se hace desde el navegador. No hace falta instalar nada.
Proyecto: **multisoft-staging**. No usar el proyecto con datos reales.

## Parte A · Instalar la función (una sola)
1. Supabase → **Edge Functions** → **Deploy a new function** → **Via Editor**.
2. Nombre exacto: `multisoft-crear-responsable`
3. Pega TODO el contenido de `multisoft-crear-responsable_para_pegar.ts`.
4. **Deploy**. Debe decir "Successfully updated edge function".
5. En **Settings** de esa función: *Verify JWT with legacy secret* → **desactivado**
   (la función verifica la sesión y el perfil de superadmin en su propio código).
6. No borres `multisoft-crear-usuario` hasta terminar la Parte C.

## Parte B · Prueba que NO crea nada
1. En la función → **Test** → método **POST** → cuerpo `{}` → enviar.
2. Resultado esperado: **401** (sesión requerida o no válida).
   - Si responde 200 o dice que creó algo → STOP, avisar.
   - Si responde 500 "Faltan secretos" → abrir **Logs** y copiar el mensaje.

## Parte C · Prueba real en el panel
1. Abre el `index.html` de `MULTISOFT_v2.zip` en Chrome (con internet).
2. Entra como superadmin con tu correo de Supabase Auth.
3. Pestaña **NEGOCIOS** → crea un negocio de prueba (código `prueba-ferre01`).
4. Pestaña **RESPONSABLES** → crea un **cajero** para ese negocio (contraseña de 10+ caracteres).
5. Comprueba con `verificacion_staging.sql` (BLOQUES 2, 3 y 4):
   - el negocio aparece con UNA sola sucursal,
   - el cajero aparece con su rol y sucursal,
   - la auditoría muestra `CREAR_RESPONSABLE`.
6. Si todo está bien → borra `multisoft-crear-usuario`.

## Qué reportar si algo falla
- El texto EXACTO del error que se ve en pantalla.
- El mensaje de **Logs** de la función (Edge Functions → la función → Logs).
- En qué paso (A, B o C) ocurrió.
- NUNCA pegues claves, contraseñas ni la service_role.

## Limitaciones conocidas
- Los cajeros todavía no inician sesión contra Supabase: el login operativo sigue en Firebase.
- Las ventas, caja, productos e inventario todavía NO están en Supabase.
- Staging no es producción.
