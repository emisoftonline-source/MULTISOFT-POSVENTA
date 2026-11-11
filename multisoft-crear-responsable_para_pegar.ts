// MULTISOFT - Edge Function: multisoft-crear-responsable (versión de UN SOLO ARCHIVO para pegar en el editor web de Supabase)
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
const corsHeaders = {
 "Access-Control-Allow-Origin": "*",
 "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
 "Access-Control-Allow-Methods": "POST, OPTIONS",
};
// Lee la clave del entorno: primero la variable clásica; si no existe, el diccionario JSON de las claves nuevas de Supabase.
const leerClave=(simple:string,diccionario:string):string|undefined=>{
 const v=Deno.env.get(simple);if(v)return v;
 try{const raw=Deno.env.get(diccionario);if(raw){const o=JSON.parse(raw);if(o&&typeof o.default==="string")return o.default}}catch{}
 return undefined;
};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...corsHeaders,"Content-Type":"application/json"}});
Deno.serve(async (req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:corsHeaders});
 if(req.method!=="POST")return json({error:"Método no permitido"},405);
 const url=Deno.env.get("SUPABASE_URL"), anon=leerClave("SUPABASE_ANON_KEY","SUPABASE_PUBLISHABLE_KEYS"), service=leerClave("SUPABASE_SERVICE_ROLE_KEY","SUPABASE_SECRET_KEYS");
 if(!url||!anon||!service)return json({error:"Faltan secretos de Supabase en la función"},500);
 const authHeader=req.headers.get("Authorization");if(!authHeader)return json({error:"Sesión requerida"},401);
 const callerClient=createClient(url,anon,{global:{headers:{Authorization:authHeader}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data:{user:caller},error:authErr}=await callerClient.auth.getUser();if(authErr||!caller)return json({error:"Sesión no válida"},401);
 const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:profile,error:profileErr}=await admin.from("perfiles").select("user_id,es_superadmin,activo").eq("user_id",caller.id).maybeSingle();
 if(profileErr||!profile||!profile.es_superadmin||!profile.activo)return json({error:"Solo un superadministrador activo puede crear responsables"},403);
 let b:any;try{b=await req.json()}catch{return json({error:"JSON no válido"},400)}
 const {negocio_id,sucursal_id,nombre,login_id,email_contacto,telefono,rol,password,codigo_negocio}=b||{};
 if(!negocio_id||!nombre||!login_id||!password||!codigo_negocio)return json({error:"Faltan campos obligatorios"},400);
 const usuario=String(login_id).trim().toLowerCase();
 if(!/^[a-z0-9._-]{3,40}$/.test(usuario)||!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(codigo_negocio))return json({error:"Usuario o código de negocio no válido"},400);
 if(["superadmin","admin","administrador","root","soporte","multisoft","sistema"].includes(usuario))return json({error:"Ese nombre de usuario está reservado"},400);
 if(typeof password!=="string"||password.length<10||password.length>128)return json({error:"La contraseña debe tener entre 10 y 128 caracteres"},400);
 if(!["admin_negocio","cajero"].includes(rol))return json({error:"Rol no permitido"},400);
 const {data:negocio,error:negErr}=await admin.from("negocios").select("id,codigo,activo").eq("id",negocio_id).maybeSingle();
 if(negErr||!negocio||!negocio.activo||negocio.codigo!==codigo_negocio)return json({error:"Negocio no válido o inactivo"},400);
 if(rol==="cajero"){
  if(!sucursal_id)return json({error:"El cajero necesita una sucursal"},400);
  const {data:suc,error:sucErr}=await admin.from("sucursales").select("id").eq("id",sucursal_id).eq("negocio_id",negocio_id).eq("activa",true).maybeSingle();
  if(sucErr||!suc)return json({error:"La sucursal no pertenece al negocio o está inactiva"},400);
 } else if(sucursal_id) return json({error:"El administrador se asigna a todo el negocio, sin sucursal específica"},400);
 // El usuario se guarda tal como se escribió (único en todo el sistema), sin añadir el código del negocio.
 const finalLogin=usuario;
 const syntheticEmail=`${finalLogin}@acceso.multisoft.app`;
 const {data:existing}=await admin.from("perfiles").select("user_id").eq("login_id",finalLogin).maybeSingle();if(existing)return json({error:"Ese usuario ya existe en el sistema. Elige otro nombre de usuario."},409);
 const {data:created,error:createErr}=await admin.auth.admin.createUser({email:syntheticEmail,password,email_confirm:true,user_metadata:{multisoft_login_id:finalLogin,nombre}});
 if(createErr||!created.user)return json({error:createErr?.message||"No se pudo crear la cuenta de acceso"},400);
 const uid=created.user.id;
 const {error:perErr}=await admin.from("perfiles").insert({user_id:uid,login_id:finalLogin,nombre,telefono:telefono||null,email_contacto:email_contacto||null,es_superadmin:false,activo:true});
 if(perErr){await admin.auth.admin.deleteUser(uid);return json({error:`No se pudo guardar el perfil: ${perErr.message}`},400)}
 const {error:memErr}=await admin.from("membresias").insert({user_id:uid,negocio_id,sucursal_id:rol==="cajero"?sucursal_id:null,rol,activo:true});
 if(memErr){await admin.auth.admin.deleteUser(uid);return json({error:`No se pudo asignar el rol al negocio: ${memErr.message}`},400)}
 // Auditoría explícita: con service_role los triggers no saben quién actuó, así que se registra aquí.
 const {error:audErr}=await admin.from("auditoria").insert({negocio_id,usuario_id:caller.id,accion:"CREAR_RESPONSABLE",entidad:"responsables",entidad_id:uid,despues:{login_id:finalLogin,rol,sucursal_id:rol==="cajero"?sucursal_id:null}});
 if(audErr)console.error("No se pudo registrar la auditoría:",audErr.message);
 return json({ok:true,login_id:finalLogin,rol});
});
