// MULTISOFT - Edge Function: multisoft-gestionar-usuarios (versión de UN SOLO ARCHIVO para pegar en el editor web de Supabase)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
const corsHeaders = {
 "Access-Control-Allow-Origin": "*",
 "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
 "Access-Control-Allow-Methods": "POST, OPTIONS",
};
// MULTISOFT - Edge Function: multisoft-gestionar-usuarios
// Quién puede usarla:
//   - Superadministrador activo: todos los usuarios.
//   - Administrador de negocio activo (negocio activo): SOLO los cajeros de su(s) negocio(s).
// Acciones:
//   { "accion": "listar" }
//   { "accion": "resetear_clave", "user_id": "...", "password": "..." }
//   { "accion": "cambiar_estado", "user_id": "...", "negocio_id": "...", "activo": true|false }
const leerClave=(simple:string,diccionario:string):string|undefined=>{
 const v=Deno.env.get(simple);if(v)return v;
 try{const raw=Deno.env.get(diccionario);if(raw){const o=JSON.parse(raw);if(o&&typeof o.default==="string")return o.default}}catch{}
 return undefined;
};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...corsHeaders,"Content-Type":"application/json"}});
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BAN_LARGO="876000h"; // ~100 años: la cuenta no puede iniciar sesión ni renovar su sesión
Deno.serve(async (req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:corsHeaders});
 if(req.method!=="POST")return json({error:"Método no permitido"},405);
 const url=Deno.env.get("SUPABASE_URL"), anon=leerClave("SUPABASE_ANON_KEY","SUPABASE_PUBLISHABLE_KEYS"), service=leerClave("SUPABASE_SERVICE_ROLE_KEY","SUPABASE_SECRET_KEYS");
 if(!url||!anon||!service)return json({error:"Faltan secretos de Supabase en la función"},500);
 const authHeader=req.headers.get("Authorization");if(!authHeader)return json({error:"Sesión requerida"},401);
 const callerClient=createClient(url,anon,{global:{headers:{Authorization:authHeader}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data:{user:caller},error:authErr}=await callerClient.auth.getUser();if(authErr||!caller)return json({error:"Sesión no válida"},401);
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});

 // ---- Quién llama
 const {data:yo,error:yoErr}=await admin.from("perfiles").select("user_id,es_superadmin,activo").eq("user_id",caller.id).maybeSingle();
 if(yoErr||!yo||!yo.activo)return json({error:"Tu cuenta no está activa"},403);
 const esSuper=!!yo.es_superadmin;
 let misNegocios:string[]=[];
 if(!esSuper){
  const {data:ms,error:msErr}=await admin.from("membresias").select("negocio_id").eq("user_id",caller.id).eq("rol","admin_negocio").eq("activo",true);
  if(msErr)return json({error:`No se pudo verificar tu rol: ${msErr.message}`},500);
  const ids=[...new Set((ms||[]).map((m:any)=>m.negocio_id))];
  if(ids.length){
   const {data:ns,error:nsErr}=await admin.from("negocios").select("id").in("id",ids).eq("activo",true);
   if(nsErr)return json({error:`No se pudo verificar tu negocio: ${nsErr.message}`},500);
   misNegocios=(ns||[]).map((n:any)=>n.id);
  }
  if(!misNegocios.length)return json({error:"Solo un superadministrador o un administrador de negocio activo puede gestionar usuarios"},403);
 }

 let b:any;try{b=await req.json()}catch{return json({error:"JSON no válido"},400)}
 const accion=b?.accion;

 // ¿Puede quien llama gestionar a este usuario? Devuelve el perfil y sus membresías, o un error.
 async function objetivo(uid:string){
  if(!UUID.test(uid))return {error:"Usuario no válido",status:400};
  const [p,m]=await Promise.all([
   admin.from("perfiles").select("user_id,login_id,nombre,es_superadmin").eq("user_id",uid).maybeSingle(),
   admin.from("membresias").select("negocio_id,sucursal_id,rol,activo").eq("user_id",uid),
  ]);
  if(p.error||m.error)return {error:"No se pudo leer el usuario",status:500};
  if(!p.data)return {error:"El usuario no existe en MULTISOFT",status:404};
  const mems=m.data||[];
  if(!esSuper){
   if(uid===caller!.id)return {error:"No puedes gestionar tu propia cuenta desde aquí",status:403};
   if(p.data.es_superadmin||mems.some((x:any)=>x.rol!=="cajero"))return {error:"Solo puedes gestionar a los cajeros de tu negocio",status:403};
   if(!mems.some((x:any)=>misNegocios.includes(x.negocio_id)))return {error:"Ese cajero no pertenece a tu negocio",status:403};
  }
  return {perfil:p.data,mems};
 }

 if(accion==="listar"){
  const [p,m,n,s]=await Promise.all([
   esSuper?admin.from("perfiles").select("user_id,login_id,nombre,telefono,email_contacto,es_superadmin,activo")
          :Promise.resolve({data:null,error:null}),
   esSuper?admin.from("membresias").select("user_id,negocio_id,sucursal_id,rol,activo")
          :admin.from("membresias").select("user_id,negocio_id,sucursal_id,rol,activo").in("negocio_id",misNegocios).eq("rol","cajero"),
   admin.from("negocios").select("id,nombre,codigo"),
   admin.from("sucursales").select("id,nombre"),
  ]);
  let perfiles:any[]=p.data||[];
  const err=p.error||m.error||n.error||s.error;if(err)return json({error:`No se pudo leer la base de datos: ${err.message}`},500);
  if(!esSuper){
   const ids=[...new Set((m.data||[]).map((x:any)=>x.user_id))];
   const r=ids.length?await admin.from("perfiles").select("user_id,login_id,nombre,telefono,email_contacto,es_superadmin,activo").in("user_id",ids):{data:[],error:null};
   if(r.error)return json({error:`No se pudo leer la base de datos: ${r.error.message}`},500);
   perfiles=(r.data||[]).filter((x:any)=>!x.es_superadmin&&x.user_id!==caller.id);
  }
  // Fechas de registro y último ingreso: las guarda Supabase Auth automáticamente.
  const fechas:Record<string,{creado:string|null,ultimo:string|null}>={};
  if(esSuper){
   for(let page=1;page<=50;page++){
    const {data,error}=await admin.auth.admin.listUsers({page,perPage:1000});
    if(error)return json({error:`No se pudo leer Auth: ${error.message}`},500);
    for(const u of data.users)fechas[u.id]={creado:u.created_at??null,ultimo:u.last_sign_in_at??null};
    if(data.users.length<1000)break;
   }
  } else {
   await Promise.all(perfiles.map(async(pf:any)=>{
    const {data}=await admin.auth.admin.getUserById(pf.user_id);
    if(data?.user)fechas[pf.user_id]={creado:data.user.created_at??null,ultimo:data.user.last_sign_in_at??null};
   }));
  }
  const neg=Object.fromEntries((n.data||[]).map((x:any)=>[x.id,x])), suc=Object.fromEntries((s.data||[]).map((x:any)=>[x.id,x.nombre]));
  const usuarios=perfiles.map((pf:any)=>{
   const mems=(m.data||[]).filter((x:any)=>x.user_id===pf.user_id);
   const mem=mems.find((x:any)=>x.activo)||mems[0]||null;
   return {user_id:pf.user_id,login_id:pf.login_id,nombre:pf.nombre,telefono:pf.telefono,email_contacto:pf.email_contacto,
    es_superadmin:!!pf.es_superadmin,activo:!!pf.activo&&(pf.es_superadmin||!!mem?.activo),
    rol:pf.es_superadmin?"superadmin":(mem?.rol||null),
    negocio_id:mem?.negocio_id||null,
    negocio:mem?(neg[mem.negocio_id]?.nombre||null):null, negocio_codigo:mem?(neg[mem.negocio_id]?.codigo||null):null,
    sucursal:mem?.sucursal_id?(suc[mem.sucursal_id]||null):null,
    creado_en:fechas[pf.user_id]?.creado||null, ultimo_ingreso:fechas[pf.user_id]?.ultimo||null};
  }).sort((a:any,b:any)=>String(b.creado_en||"").localeCompare(String(a.creado_en||"")));
  return json({ok:true,usuarios,alcance:esSuper?"todos":"cajeros_de_mi_negocio"});
 }

 if(accion==="resetear_clave"){
  const uid=String(b?.user_id||""), password=b?.password;
  if(typeof password!=="string"||password.length<10||password.length>128)return json({error:"La contraseña debe tener entre 10 y 128 caracteres"},400);
  const t:any=await objetivo(uid);if(t.error)return json({error:t.error},t.status);
  const {error:upErr}=await admin.auth.admin.updateUserById(uid,{password});
  if(upErr)return json({error:`No se pudo cambiar la contraseña: ${upErr.message}`},400);
  const negAud=(esSuper?t.mems[0]?.negocio_id:t.mems.find((x:any)=>misNegocios.includes(x.negocio_id))?.negocio_id)??null;
  // Se registra quién y cuándo; la contraseña nunca se guarda.
  const {error:audErr}=await admin.from("auditoria").insert({negocio_id:negAud,usuario_id:caller.id,accion:"RESETEAR_CLAVE",entidad:"responsables",entidad_id:uid,despues:{login_id:t.perfil.login_id,por:esSuper?"superadmin":"admin_negocio"}});
  if(audErr)console.error("No se pudo registrar la auditoría:",audErr.message);
  return json({ok:true,login_id:t.perfil.login_id});
 }

 if(accion==="cambiar_estado"){
  const uid=String(b?.user_id||""), negocioId=String(b?.negocio_id||""), activo=b?.activo;
  if(typeof activo!=="boolean"||!UUID.test(negocioId))return json({error:"Datos no válidos"},400);
  if(!esSuper&&!misNegocios.includes(negocioId))return json({error:"Ese negocio no es tuyo"},403);
  const t:any=await objetivo(uid);if(t.error)return json({error:t.error},t.status);
  if(t.perfil.es_superadmin)return json({error:"Un superadministrador no se desactiva desde aquí"},400);
  if(uid===caller.id)return json({error:"No puedes desactivar tu propia cuenta"},400);
  if(!t.mems.some((x:any)=>x.negocio_id===negocioId))return json({error:"El usuario no pertenece a ese negocio"},400);
  const {error:upErr}=await admin.from("membresias").update({activo}).eq("user_id",uid).eq("negocio_id",negocioId);
  if(upErr)return json({error:`No se pudo cambiar el estado: ${upErr.message}`},400);
  // Sin ninguna membresía activa la cuenta queda bloqueada en Auth (cierra el acceso aunque tuviera una sesión abierta).
  const quedanActivas=t.mems.some((x:any)=>x.negocio_id!==negocioId&&x.activo)||activo;
  const {error:banErr}=await admin.auth.admin.updateUserById(uid,{ban_duration:quedanActivas?"none":BAN_LARGO} as any);
  if(banErr)console.error("No se pudo actualizar el bloqueo en Auth:",banErr.message);
  const {error:audErr}=await admin.from("auditoria").insert({negocio_id:negocioId,usuario_id:caller.id,accion:activo?"ACTIVAR_RESPONSABLE":"DESACTIVAR_RESPONSABLE",entidad:"responsables",entidad_id:uid,despues:{login_id:t.perfil.login_id,activo,por:esSuper?"superadmin":"admin_negocio"}});
  if(audErr)console.error("No se pudo registrar la auditoría:",audErr.message);
  return json({ok:true,login_id:t.perfil.login_id,activo});
 }

 return json({error:"Acción no válida"},400);
});
