# MULTISOFT — Fase 2: prueba inicial de Supabase Auth

- Añade el SDK de Supabase JS v2 y carga `supabase-config.js`.
- El correo `info@emisoft-online.com` inicia sesión mediante Supabase Auth.
- Luego consulta `public.perfiles` y solo continúa si `activo=true` y `es_superadmin=true`.
- Al cerrar sesión, cierra la sesión Supabase.
- Firebase/Firestore e IndexedDB se conservan para los módulos actuales; los datos operativos aún no se han migrado.

## Prueba
1. Extrae este ZIP en una carpeta nueva; no reemplaces el original.
2. Abre `SISTEMA MULTISERVICIOS/index.html` con Internet.
3. Usuario: `info@emisoft-online.com`.
4. Contraseña: la contraseña de ese usuario en Supabase Authentication (no la clave publishable).
5. Si falla, comparte el mensaje exacto. No ejecutes SQL ni desactives RLS sin revisar el error.

Esta es una integración inicial para staging, no una versión lista para producción. No se ha podido probar el login en el navegador desde este entorno. No incluir nunca claves `service_role` o `secret` en el navegador.


Actualización de seguridad: se eliminó el acceso de superadministrador con contraseña fija `superadmin / godmode`. Usa la cuenta de Supabase Auth `info@emisoft-online.com`. Los usuarios de negocio todavía usan el método anterior mientras se migra el sistema. El panel de administración de negocios aún no está implementado.


## Panel de negocios añadido
La pestaña NEGOCIOS permite al superadministrador listar rubros y negocios, crear negocios con una sucursal inicial y activar/desactivar registros. Consulta `README_FASE2_PANEL.md` incluido en la carpeta raíz del ZIP para los pasos y límites de esta entrega.


# MULTISOFT Fase 2 — Responsables cloud (preparado)

## Qué incluye
- Pestaña RESPONSABLES con un panel centrado para crear responsables cloud.
- Selector de negocio y sucursal, nombre, usuario, rol, contraseña temporal, correo y teléfono.
- Fuente de Supabase Edge Function `multisoft-crear-responsable` para crear Auth user + `perfiles` + `membresias` de forma servidor-side.
- La clave `service_role` nunca se pone en el HTML.
- Se conserva debajo el módulo local anterior, rotulado para no confundirlo con cuentas cloud.

## IMPORTANTE: un ZIP no puede desplegar la función en tu proyecto automáticamente
Antes de usar el botón de creación, debes desplegar la función en el proyecto `multisoft-staging` y configurar sus secretos. Si no lo haces, la pantalla mostrará un error de función no disponible. No vuelvas a ejecutar los SQL del esquema/seguridad.

## Despliegue recomendado
1. Instala e inicia sesión con Supabase CLI en tu computadora.
2. En una copia de trabajo, coloca la carpeta `supabase/functions/multisoft-crear-responsable` y `supabase/functions/_shared/cors.ts` en la raíz del proyecto Supabase.
3. Vincula el proyecto correcto con `supabase link --project-ref ydsjmrhphpdccleykslu`.
4. Despliega con `supabase functions deploy multisoft-crear-responsable`.
5. Verifica en Supabase Dashboard > Edge Functions que aparezca la función desplegada. Las variables estándar `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` deben estar disponibles como secretos del entorno de la función. Si la plataforma no las inyecta automáticamente, configura las correspondientes en Secrets del proyecto; la service role solo en servidor.
6. Abre MULTISOFT, inicia sesión como superadministrador y entra a RESPONSABLES.
7. Crea primero un usuario de prueba para el negocio de prueba y comprueba el resultado en Auth, `perfiles` y `membresias`.

## Login de responsables: limitación que debes conocer
La función crea credenciales de Supabase Auth usando un correo técnico derivado del usuario, por ejemplo `maria.ferre001@acceso.multisoft.app`. La pantalla actual de login del sistema antiguo aún no está completamente migrada para autenticar responsables de negocio contra Supabase Auth ni para filtrar todos los módulos operativos por `negocio_id`. Por eso, la creación de cuenta no significa que el POS operativo multiempresa ya esté terminado. No uses todavía estas cuentas para operar ventas reales; el siguiente paso es adaptar login y aislamiento de los módulos.

## Seguridad y pruebas
- La función valida que quien llama sea superadministrador activo, y valida negocio y sucursal en servidor.
- No se guardan contraseñas en `perfiles` ni se devuelven al navegador después de crear.
- Revisa políticas RLS antes de publicar; la lectura de la lista cloud desde el panel puede estar bloqueada por políticas actuales y mostrar error. Eso no impide que el servidor aplique su validación.
- El código incluido no se ha desplegado ni probado contra tu proyecto desde este entorno. Prueba primero en staging y nunca pegues aquí tu `service_role`.
