(function(){
"use strict";
const LANGS=["aa","ab","ae","af","ak","am","an","ar","as","av","ay","az","ba","be","bg","bh","bi","bm","bn","bo","br","bs","ca","ce","ch","co","cr","cs","cu","cv","cy","da","de","dv","dz","ee","el","en","eo","es","et","eu","fa","ff","fi","fj","fo","fr","fy","ga","gd","gl","gn","gu","gv","ha","he","hi","ho","hr","ht","hu","hy","hz","ia","id","ie","ig","ii","ik","io","is","it","iu","ja","jv","ka","kg","ki","kj","kk","kl","km","kn","ko","kr","ks","ku","kv","kw","ky","la","lb","lg","li","ln","lo","lt","lu","lv","mg","mh","mi","mk","ml","mn","mr","ms","mt","my","na","nb","nd","ne","ng","nl","nn","no","nr","nv","ny","oc","oj","om","or","os","pa","pi","pl","ps","pt","qu","rm","rn","ro","rw","sa","sc","sd","se","sg","si","sk","sl","sm","sn","so","sq","sr","ss","st","su","sv","sw","ta","te","tg","th","ti","tk","tl","tn","to","tr","ts","tt","tw","ty","ug","uk","ur","uz","ve","vi","vo","wa","wo","xh","yi","yo","za","zh","zu"];
const RTL=new Set(["ar","fa","he","ur","ps","sd","ug","yi","dv"]);
const API="https://latgmqklsszgictpuerp.supabase.co/functions/v1/site-translate";
const names=(()=>{try{return new Intl.DisplayNames([navigator.language||"en"],{type:"language"})}catch(e){return null}})();
const path=location.pathname,segments=path.split("/").filter(Boolean),pathLocale=segments.length&&LANGS.includes(segments[0])?segments[0]:null;
const page=path.endsWith("properties.html")?"properties.html":path.endsWith("privacy.html")?"privacy.html":"index.html";
const pagePath=page==="index.html"?"":page,query=new URLSearchParams(location.search);
let lang=(query.get("lang")||pathLocale||document.documentElement.lang||"en").toLowerCase();
if(!LANGS.includes(lang))lang="en";
if(pathLocale&&["es","fr","tr","ur"].includes(pathLocale)&&!query.has("lang")){location.replace("/en/"+(pagePath||"")+"?lang="+pathLocale);return}
function targetUrl(code){if(code==="ar")return(pagePath?"/"+pagePath:"/")+"?lang=ar";return"/en/"+(pagePath||"")+"?lang="+encodeURIComponent(code)}
function mountPicker(){
 const wrap=document.createElement("label");wrap.id="azm-language-picker";wrap.setAttribute("aria-label","Choose language");
 wrap.style.cssText="position:fixed;z-index:99999;inset-block-start:10px;inset-inline-end:10px;background:#10251f;color:#fff;padding:7px 10px;border:1px solid #c9a66b;border-radius:10px;box-shadow:0 2px 12px #0003;font:12px Arial,sans-serif;display:flex;align-items:center;gap:7px";
 const caption=document.createElement("span");caption.textContent="🌐";const select=document.createElement("select");
 select.style.cssText="max-width:190px;border:0;border-radius:6px;padding:5px;background:#fff;color:#172a22;font:12px Arial,sans-serif";
 LANGS.forEach(code=>{const option=document.createElement("option");option.value=code;option.textContent=(names&&names.of(code))||code;if(code===lang)option.selected=true;select.appendChild(option)});
 select.addEventListener("change",()=>location.href=targetUrl(select.value));wrap.append(caption,select);document.body.appendChild(wrap);
}
function notice(message){let el=document.getElementById("azm-translation-note");if(!el){el=document.createElement("div");el.id="azm-translation-note";el.style.cssText="position:fixed;z-index:99998;inset-block-end:10px;inset-inline:10px;margin:auto;max-width:680px;background:#fff8df;color:#473919;border:1px solid #d6bd76;border-radius:9px;padding:8px 12px;font:12px/1.5 Arial,sans-serif;box-shadow:0 2px 10px #0002";document.body.appendChild(el)}el.textContent=message}
mountPicker();document.documentElement.lang=lang;document.documentElement.dir=RTL.has(lang)?"rtl":"ltr";
if(lang==="en"||lang==="ar")return;
notice("تتم الترجمة آلياً مع حفظ الترجمات الناجحة في قاعدة بيانات الشركة. قد تتأخر بعض اللغات أو تبقى نصوص غير مدعومة بلغتها الأصلية. لا تُرسل بيانات النماذج.");
const cacheKey="azm_mt_cache_v2";let cache={};try{cache=JSON.parse(localStorage.getItem(cacheKey)||"{}")}catch(e){}
const processed=new WeakSet(),skipTags=new Set(["SCRIPT","STYLE","NOSCRIPT","TEXTAREA","INPUT","SELECT","SVG","CODE","PRE"]);
let translatedCount=0,failedCount=0,busy=false,pending=[];
function eligible(node){const p=node.parentElement;if(!p||skipTags.has(p.tagName)||p.closest("#azm-language-picker,#azm-translation-note,script,style,textarea,input,select#preferredLanguage,code,pre"))return false;const s=node.nodeValue.trim();return s.length>1&&/[A-Za-z]/.test(s)}
function chunks(s,max){const out=[];let rest=s;while(rest.length>max){let cut=rest.lastIndexOf(" ",max);if(cut<max*.55)cut=max;out.push(rest.slice(0,cut));rest=rest.slice(cut)}if(rest)out.push(rest);return out}
async function translateChunk(s){
 const key=lang+"|"+s;if(cache[key])return cache[key];
 let lastError;
 for(let attempt=0;attempt<3;attempt++){
  try{
   const response=await fetch(API,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({text:s,target:lang})});
   const data=await response.json();
   if(response.ok&&data.translated){cache[key]=data.translated;try{localStorage.setItem(cacheKey,JSON.stringify(cache))}catch(e){}return data.translated}
   if(!data.retryable&&response.status!==429)throw new Error(data.error||"translation_unavailable");
   lastError=new Error(data.error||"temporary_translation_error");
  }catch(e){lastError=e}
  if(attempt<2)await new Promise(resolve=>setTimeout(resolve,700*(attempt+1)));
 }
 throw lastError||new Error("translation_unavailable");
}
async function translateNode(node){
 if(!node.isConnected||processed.has(node)||!eligible(node))return;
 processed.add(node);const original=node.nodeValue,pieces=chunks(original,430),results=[];
 try{for(const piece of pieces)results.push(await translateChunk(piece));node.nodeValue=results.join("");translatedCount++}
 catch(e){failedCount++;processed.delete(node)}
}
async function drain(){
 if(busy)return;busy=true;
 while(pending.length){const node=pending.shift();await translateNode(node)}
 busy=false;
 notice("تمت ترجمة "+translatedCount+" مقطعاً وحفظ الترجمات الناجحة مركزياً. "+(failedCount?"تعذر مؤقتاً ترجمة "+failedCount+" مقطعاً؛ ستعاد المحاولة عند ظهور المحتوى مجدداً.":"النصوص الجديدة تُعالج تلقائياً.")+" راجع النصوص القانونية قبل الاعتماد عليها.");
}
function enqueue(node){if(node&&node.nodeType===Node.TEXT_NODE){pending.push(node);drain()}else if(node&&node.nodeType===Node.ELEMENT_NODE){const walker=document.createTreeWalker(node,NodeFilter.SHOW_TEXT);while(walker.nextNode())if(eligible(walker.currentNode))pending.push(walker.currentNode);drain()}}
function scan(){enqueue(document.body);if(document.title&&/[A-Za-z]/.test(document.title)){translateChunk(document.title).then(t=>{document.title=t}).catch(()=>{})}}
function observe(){const observer=new MutationObserver(records=>{for(const record of records){if(record.type==="characterData")enqueue(record.target);for(const added of record.addedNodes)enqueue(added)}});observer.observe(document.body,{subtree:true,childList:true,characterData:true})}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",()=>{scan();observe()},{once:true});else{scan();observe()}
})();