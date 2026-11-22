const json=(res,status,body)=>res.status(status).setHeader("Content-Type","application/json").setHeader("Cache-Control","no-store").json(body);

module.exports=async function handler(req,res){
  if(!["GET","POST","PATCH"].includes(req.method)) return json(res,405,{error:"Method not allowed"});
  const contentLength=Number(req.headers["content-length"]||0);
  if(Number.isFinite(contentLength)&&contentLength>16000) return json(res,413,{error:"حجم الطلب أكبر من الحد المسموح."});
  const auth=req.headers.authorization||"";
  if(!auth.startsWith("Bearer ")) return json(res,401,{error:"تسجيل الدخول مطلوب."});
  const url=(process.env.SUPABASE_URL||"https://latgmqklsszgictpuerp.supabase.co").replace(/\/$/,"");
  const anon=process.env.SUPABASE_ANON_KEY||"sb_publishable_wMBzGxUySW5xznKG_Gx_Rg_DFNqDwhP";
  const service=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!service) return json(res,503,{error:"إعداد مفتاح الخادم السري في Vercel مطلوب."});
  const userHeaders={apikey:anon,Authorization:auth};
  const serverHeaders={apikey:service,"Content-Type":"application/json"};
  try{
    const ur=await fetch(url+"/auth/v1/user",{headers:userHeaders});
    if(!ur.ok) return json(res,401,{error:"جلسة الدخول غير صالحة."});
    const user=await ur.json();
    const pr=await fetch(url+"/rest/v1/profiles?id=eq."+encodeURIComponent(user.id)+"&select=role,active",{headers:serverHeaders});
    const pa=await pr.json(),profile=Array.isArray(pa)?pa[0]:null;
    if(!pr.ok||!profile||!profile.active||!["owner","admin"].includes(profile.role)) return json(res,403,{error:"هذه الإدارة متاحة لمالك الشركة النشط فقط."});

    if(req.method==="GET"){
      const [tr,er]=await Promise.all([
        fetch(url+"/rest/v1/ai_employee_tasks?select=id,employee_id,title,instructions,input_data,status,priority,result,error_message,created_at,started_at,completed_at,reviewed_at&order=created_at.desc&limit=50",{headers:serverHeaders}),
        fetch(url+"/rest/v1/ai_employees?select=id,name,department,purpose,enabled,requires_human_approval&order=department.asc",{headers:serverHeaders})
      ]);
      const [tasks,employees]=await Promise.all([tr.json(),er.json()]);
      if(!tr.ok||!er.ok) return json(res,502,{error:"تعذر قراءة قائمة مهام الذكاء الاصطناعي."});
      return json(res,200,{tasks,employees});
    }

    if(req.method==="POST"){
      const body=req.body||{};
      const title=String(body.title||"").trim();
      const instructions=String(body.instructions||"").trim();
      if(!title||title.length>160||!instructions||instructions.length>4000) return json(res,400,{error:"أدخل عنواناً وتعليمات، ضمن الحدود المسموحة."});
      const inputData=body.input_data===undefined?{}:body.input_data;
      if(!inputData||typeof inputData!=="object"||Array.isArray(inputData)) return json(res,400,{error:"بيانات المهمة يجب أن تكون كائناً صالحاً."});
      let inputDataText;
      try{inputDataText=JSON.stringify(inputData);}catch(_){return json(res,400,{error:"تعذر قراءة بيانات المهمة."});}
      if(inputDataText.length>8000) return json(res,413,{error:"بيانات المهمة كبيرة جداً؛ الحد 8000 حرف."});
      const employeeId=String(body.employee_id||"ceo");
      const er=await fetch(url+"/rest/v1/ai_employees?id=eq."+encodeURIComponent(employeeId)+"&select=id,enabled",{headers:serverHeaders});
      const ea=await er.json(),employee=Array.isArray(ea)?ea[0]:null;
      if(!er.ok||!employee||!employee.enabled) return json(res,409,{error:"الموظف غير موجود أو غير مفعّل."});
      const priority=["low","normal","high","urgent"].includes(body.priority)?body.priority:"normal";
      const cr=await fetch(url+"/rest/v1/ai_employee_tasks",{method:"POST",headers:{...serverHeaders,Prefer:"return=representation"},body:JSON.stringify({employee_id:employeeId,title,instructions,input_data:inputData,priority,status:"queued",created_by:user.id})});
      const created=await cr.json();
      if(!cr.ok) return json(res,502,{error:"تعذر إنشاء المهمة."});
      return json(res,201,{task:Array.isArray(created)?created[0]:created});
    }

    const body=req.body||{},id=String(body.task_id||""),action=String(body.action||"");
    if(!/^[0-9a-f-]{36}$/i.test(id)) return json(res,400,{error:"معرّف المهمة غير صالح."});
    const allowed={approve:{from:"needs_review",to:"completed"},cancel:{from:["queued","needs_review","failed"],to:"cancelled"},retry:{from:"failed",to:"queued"}};
    const rule=allowed[action];
    if(!rule) return json(res,400,{error:"الإجراء غير معروف."});
    const from=Array.isArray(rule.from)?rule.from:[rule.from];
    if(action==="approve"){
      // Approval is permitted only after a non-empty AI report is actually stored.
      const vr=await fetch(url+"/rest/v1/ai_employee_tasks?id=eq."+encodeURIComponent(id)+"&select=id,status,result,employee_id",{headers:serverHeaders});
      const va=await vr.json(),task=Array.isArray(va)?va[0]:null;
      const report=task?.result?.report;
      if(!vr.ok) return json(res,502,{error:"تعذر التحقق من نتيجة المهمة قبل اعتمادها."});
      if(!task||task.status!=="needs_review"||typeof report!=="string"||!report.trim()||task.result?.requires_human_approval!==true)
        return json(res,409,{error:"لا يمكن اعتماد المهمة: لا توجد نتيجة مكتملة وصالحة للمراجعة."});
    }
    const patch={status:rule.to};
    if(action==="approve"){patch.reviewed_by=user.id;patch.reviewed_at=new Date().toISOString();}
    const filter=from.map(s=>"status.eq."+s).join(",");
    const rr=await fetch(url+"/rest/v1/ai_employee_tasks?id=eq."+encodeURIComponent(id)+"&or=("+filter+")",{method:"PATCH",headers:{...serverHeaders,Prefer:"return=representation"},body:JSON.stringify(patch)});
    const rows=await rr.json();
    if(!rr.ok) return json(res,502,{error:"تعذر تحديث المهمة."});
    if(!Array.isArray(rows)||rows.length!==1) return json(res,409,{error:"حالة المهمة تغيرت؛ حدّث القائمة قبل المحاولة."});
    return json(res,200,{task:rows[0]});
  }catch(e){return json(res,500,{error:"حدث خطأ داخلي أثناء إدارة المهام."});}
};
