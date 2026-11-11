# MULTISOFT — Fase 2: panel inicial de negocios conectado a Supabase

## Qué se añadió
- Nueva pestaña **NEGOCIOS**, visible solo para el superadministrador autenticado por Supabase.
- Carga de rubros activos desde `public.rubros`.
- Formulario para registrar un negocio en `public.negocios` y su sucursal inicial en `public.sucursales`.
- Tabla de negocios con código, rubro, plan y estado.
- Activar/desactivar negocios sin borrar sus datos.
- Validación del código de negocio antes de guardarlo.
- Se conserva Firebase/Firestore e IndexedDB para los módulos operativos existentes; esta entrega no migra ventas ni inventario.

## Cómo probar
1. Descomprime el ZIP en una carpeta nueva, sin reemplazar la copia original.
2. Abre `SISTEMA MULTISERVICIOS/index.html` con conexión a Internet.
3. Inicia sesión con la cuenta de superadministrador de Supabase.
4. Debe abrir la pestaña **NEGOCIOS**. Confirma que cargue los rubros y negocios.
5. Crea primero un negocio de prueba con código único (por ejemplo `prueba-ferre01`). Comprueba que aparezca en la tabla.
6. Prueba desactivarlo y volverlo a activar.

## Límites importantes de esta entrega
- No crea todavía el usuario administrador de cada negocio. La tabla `perfiles` está protegida para que solo el servidor pueda crear perfiles; el paso correcto siguiente es desplegar una Supabase Edge Function segura que cree la cuenta Auth, el perfil y la membresía sin exponer `service_role` en el navegador.
- Los usuarios no-superadmin y los módulos actuales siguen usando temporalmente el mecanismo anterior/Firebase. La migración de ventas, caja, productos e inventario a Supabase no está incluida.
- La conexión y el código se revisaron localmente, pero no se ha realizado una prueba real de navegador contra el proyecto Supabase desde este entorno. La prueba de crear un negocio debe hacerse en el staging.
- No ejecutar de nuevo los SQL de esquema, seguridad o pruebas: ya fueron aplicados en el proyecto de staging según el historial.


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
