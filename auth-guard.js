import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cfg=window.AL_AZM_SUPABASE;
const supabase=createClient(cfg.url,cfg.publishableKey);
window.alAzmAuth=supabase;
(async()=>{
 const {data:{session},error}=await supabase.auth.getSession();
 if(error||!session){location.replace("login.html");return}
 const {data:profile,error:profileError}=await supabase.from("profiles").select("role,active,full_name").eq("id",session.user.id).single();
 if(profileError||!profile||!profile.active||!["owner","admin"].includes(profile.role)){
   await supabase.auth.signOut();
   location.replace("login.html?reason=unauthorized");return;
 }
 document.documentElement.dataset.authenticated="true";
 const slot=document.createElement("div");
 slot.style.cssText="position:fixed;left:12px;bottom:12px;z-index:9999;background:#0b211b;color:white;padding:8px 12px;border-radius:10px;font:12px Tahoma;display:flex;gap:10px;align-items:center";
 slot.innerHTML='<span></span><button type="button" style="border:0;border-radius:6px;padding:5px 8px;cursor:pointer">خروج</button>';
 slot.querySelector("span").textContent=profile.full_name||session.user.email;
 slot.querySelector("button").onclick=async()=>{await supabase.auth.signOut();location.replace("login.html")};
 document.body.append(slot);
})();
