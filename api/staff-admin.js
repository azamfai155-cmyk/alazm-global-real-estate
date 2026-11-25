const json=(res,status,body)=>res.status(status).setHeader("Content-Type","application/json").setHeader("Cache-Control","no-store, private").json(body);
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const ROLES=new Set(["admin","reviewer","agent","support"]);
const timeout=ms=>AbortSignal.timeout(ms);
async function writeAudit(base,headers,{actorId,action,entityType,entityId=null,details={}}){
 const response=await fetch(base+"/rest/v1/audit_logs",{method:"POST",headers:{...headers,Prefer:"return=minimal"},body:JSON.stringify({actor_id:actorId,action,entity_type:entityType,entity_id:entityId,details}),signal:timeout(7000)});
 return response.ok;
}
module.exports=async function handler(req,res){
 if(!["GET","POST","PATCH"].includes(req.method)){res.setHeader("Allow","GET, POST, PATCH");return json(res,405,{error:"Method not allowed"});}
 const auth=String(req.headers.authorization||"");
 if(!auth.startsWith("Bearer ")||auth.length>8192)return json(res,401,{error:"تسجيل الدخول مطلوب."});
 const base=String(process.env.SUPABASE_URL||"").replace(/\/$/,"");
 const anon=process.env.SUPABASE_ANON_KEY||process.env.SUPABASE_PUBLISHABLE_KEY||"sb_publishable_wMBzGxUySW5xznKG_Gx_Rg_DFNqDwhP";
 const service=process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!base||!anon||!service)return json(res,503,{error:"إعدادات الخادم غير مكتملة."});
 const adminHeaders={apikey:service,Authorization:"Bearer "+service,"Content-Type":"application/json"};
 try{
  const verify=await fetch(base+"/auth/v1/user",{headers:{apikey:anon,Authorization:auth},signal:timeout(7000)});
  if(!verify.ok)return json(res,401,{error:"جلسة الدخول غير صالحة."});
  const actor=await verify.json();
  if(!UUID.test(String(actor.id||"")))return json(res,401,{error:"هوية الحساب غير صالحة."});
  const profileResponse=await fetch(base+"/rest/v1/profiles?id=eq."+encodeURIComponent(actor.id)+"&select=role,active",{headers:adminHeaders,signal:timeout(7000)});
  const profiles=await profileResponse.json(),profile=Array.isArray(profiles)?profiles[0]:null;
  if(!profileResponse.ok||!profile||profile.role!=="owner"||profile.active!==true)return json(res,403,{error:"هذه الإدارة متاحة لمالك الشركة النشط فقط."});
  if(req.method==="GET"){
   const usersResponse=await fetch(base+"/auth/v1/admin/users?page=1&per_page=200",{headers:adminHeaders,signal:timeout(9000)});
   if(!usersResponse.ok)return json(res,502,{error:"تعذر تحميل حسابات المستخدمين."});
   const usersData=await usersResponse.json(),users=Array.isArray(usersData.users)?usersData.users:[];
   const ids=users.map(u=>u.id).filter(id=>UUID.test(String(id||"")));
   if(!ids.length)return json(res,200,{users:[]});
   const pr=await fetch(base+"/rest/v1/profiles?id=in.("+ids.map(encodeURIComponent).join(",")+")&select=id,full_name,role,active,created_at",{headers:adminHeaders,signal:timeout(9000)});
   const rows=await pr.json();
   if(!pr.ok)return json(res,502,{error:"تعذر تحميل صلاحيات الحسابات."});
   const byId=new Map((Array.isArray(rows)?rows:[]).map(p=>[p.id,p]));
   return json(res,200,{users:users.map(u=>{const p=byId.get(u.id);return {id:u.id,email:u.email||null,full_name:p?.full_name||u.user_metadata?.full_name||null,role:p?.role||"unassigned",active:p?.active===true,created_at:u.created_at,confirmed:!!u.email_confirmed_at};})});
  }
  const body=req.body&&typeof req.body==="object"&&!Array.isArray(req.body)?req.body:{};
  if(req.method==="POST"){
   const email=String(body.email||"").trim().toLowerCase();
   if(email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))return json(res,400,{error:"أدخل بريداً إلكترونياً صالحاً."});
   const inviteUrl=String(process.env.STAFF_INVITE_REDIRECT_URL||"https://alazm-global-real-estate.vercel.app/login.html");
   let parsed;try{parsed=new URL(inviteUrl)}catch(_){return json(res,503,{error:"رابط الدعوة غير صالح."});}
   if(parsed.protocol!=="https:"||parsed.host!=="alazm-global-real-estate.vercel.app"||parsed.username||parsed.password)return json(res,503,{error:"رابط الدعوة يجب أن يكون نطاق الإنتاج المعتمد عبر HTTPS."});
   const invite=await fetch(base+"/auth/v1/invite?redirect_to="+encodeURIComponent(inviteUrl),{method:"POST",headers:adminHeaders,body:JSON.stringify({email,data:{invited_by:actor.id}}),signal:timeout(12000)});
   const invited=await invite.json();
   if(!invite.ok)return json(res,invite.status===429?429:invite.status===422?409:502,{error:"تعذر إرسال الدعوة. تحقق من إعدادات البريد أو حالة الحساب.",details:invited.msg||invited.message||null});
   const userId=UUID.test(String(invited.id||""))?invited.id:null;
   const auditLogged=await writeAudit(base,adminHeaders,{actorId:actor.id,action:"staff.invited",entityType:"staff_account",entityId:userId,details:{email_domain:email.split("@")[1]||"",initial_role:"support"}});
   return json(res,202,{ok:true,message:"تم إرسال الدعوة. سيبدأ الحساب بدور الدعم المحدود.",user_id:userId,audit_logged:auditLogged});
  }
  const id=String(body.user_id||"");
  if(!UUID.test(id)||id===actor.id)return json(res,400,{error:"معرّف الموظف غير صالح أو لا يمكن تعديل حساب المالك الحالي."});
  const targetResponse=await fetch(base+"/rest/v1/profiles?id=eq."+encodeURIComponent(id)+"&select=id,role,active",{headers:adminHeaders,signal:timeout(7000)});
  const targetRows=await targetResponse.json(),target=Array.isArray(targetRows)?targetRows[0]:null;
  if(!targetResponse.ok||!target)return json(res,404,{error:"حساب الموظف غير موجود."});
  if(target.role==="owner")return json(res,403,{error:"لا يمكن تغيير أو تعطيل حساب مالك الشركة."});
  const patch={};
  if(body.role!==undefined){if(!ROLES.has(body.role))return json(res,400,{error:"الدور المطلوب غير مسموح."});patch.role=body.role;}
  if(body.active!==undefined){if(typeof body.active!=="boolean")return json(res,400,{error:"قيمة حالة الحساب غير صالحة."});patch.active=body.active;}
  if(!Object.keys(patch).length)return json(res,400,{error:"لا توجد تغييرات صالحة."});
  if(patch.active===false){
   const ban=await fetch(base+"/auth/v1/admin/users/"+encodeURIComponent(id),{method:"PUT",headers:adminHeaders,body:JSON.stringify({ban_duration:"876000h"}),signal:timeout(9000)});
   if(!ban.ok)return json(res,502,{error:"تعذر إيقاف جلسات الحساب؛ لم يتم اعتماد التعطيل."});
  }
  if(patch.active===true){
   const unban=await fetch(base+"/auth/v1/admin/users/"+encodeURIComponent(id),{method:"PUT",headers:adminHeaders,body:JSON.stringify({ban_duration:"none"}),signal:timeout(9000)});
   if(!unban.ok)return json(res,502,{error:"تعذر إعادة تفعيل جلسات الحساب."});
  }
  const update=await fetch(base+"/rest/v1/profiles?id=eq."+encodeURIComponent(id),{method:"PATCH",headers:{...adminHeaders,Prefer:"return=representation"},body:JSON.stringify(patch),signal:timeout(9000)});
  const updated=await update.json();
  if(!update.ok){
   if(patch.active===false)await fetch(base+"/rest/v1/profiles?id=eq."+encodeURIComponent(id),{method:"PATCH",headers:adminHeaders,body:JSON.stringify({active:false}),signal:timeout(7000)}).catch(()=>{});
   return json(res,502,{error:"تعذر حفظ صلاحيات الموظف. تم إبقاء الحساب محظوراً عند محاولة تعطيله."});
  }
  const auditLogged=await writeAudit(base,adminHeaders,{actorId:actor.id,action:"staff.updated",entityType:"staff_account",entityId:id,details:{before:{role:target.role,active:target.active},after:{role:patch.role??target.role,active:patch.active??target.active}}});
  return json(res,200,{user:Array.isArray(updated)?updated[0]:updated,audit_logged:auditLogged});
 }catch(error){return json(res,500,{error:"حدث خطأ داخلي في إدارة حسابات الموظفين."});}
};
