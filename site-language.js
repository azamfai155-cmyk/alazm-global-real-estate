(function(){
"use strict";
const LANGS=["ar","en","fr","es","de","tr","ru","zh-cn","ja","ko","hi","ur","fa","pt","it","nl","id","ms","bn","sw"];
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
function populatePreferredLanguage(){
 const field=document.getElementById("preferredLanguage");
 if(!field||field.dataset.languageOptionsReady==="true")return;
 const selected=LANGS.includes(lang)?lang:"ar";
 let labels;
 try{labels=new Intl.DisplayNames([lang],{type:"language"})}catch(e){labels=names}
 field.replaceChildren();
 LANGS.forEach(code=>{
  const option=document.createElement("option");
  option.value=code;
  option.textContent=(labels&&labels.of(code))||code;
  option.selected=code===selected;
  field.appendChild(option);
 });
 field.dataset.languageOptionsReady="true";
}
function mountPicker(){
 const wrap=document.createElement("label");wrap.id="azm-language-picker";wrap.setAttribute("aria-label","Choose language");
 wrap.style.cssText="position:fixed;z-index:99999;inset-block-start:10px;inset-inline-end:10px;background:#10251f;color:#fff;padding:7px 10px;border:1px solid #c9a66b;border-radius:10px;box-shadow:0 2px 12px #0003;font:12px Arial,sans-serif;display:flex;align-items:center;gap:7px";
 const caption=document.createElement("span");caption.textContent="🌐";const select=document.createElement("select");
 select.style.cssText="max-width:190px;border:0;border-radius:6px;padding:5px;background:#fff;color:#172a22;font:12px Arial,sans-serif";
 LANGS.forEach(code=>{const option=document.createElement("option");option.value=code;option.textContent=(names&&names.of(code))||code;if(code===lang)option.selected=true;select.appendChild(option)});
 select.addEventListener("change",()=>location.href=targetUrl(select.value));wrap.append(caption,select);document.body.appendChild(wrap);
}
function notice(message){let el=document.getElementById("azm-translation-note");if(!el){el=document.createElement("div");el.id="azm-translation-note";el.style.cssText="position:fixed;z-index:99998;inset-block-end:10px;inset-inline:10px;margin:auto;max-width:680px;background:#fff8df;color:#473919;border:1px solid #d6bd76;border-radius:9px;padding:8px 12px;font:12px/1.5 Arial,sans-serif;box-shadow:0 2px 10px #0002";document.body.appendChild(el)}el.textContent=message}
mountPicker();populatePreferredLanguage();document.documentElement.lang=lang;document.documentElement.dir=RTL.has(lang)?"rtl":"ltr";

notice("تتم الترجمة آلياً مع حفظ الترجمات الناجحة في قاعدة بيانات الشركة. قد تتأخر بعض اللغات أو تبقى نصوص غير مدعومة بلغتها الأصلية. لا تُرسل بيانات النماذج.");
const cacheKey="azm_mt_cache_v3";let cache={};try{cache=JSON.parse(localStorage.getItem(cacheKey)||"{}")}catch(e){}
const processed=new WeakSet(),skipTags=new Set(["SCRIPT","STYLE","NOSCRIPT","TEXTAREA","INPUT","SELECT","SVG","CODE","PRE"]);
let translatedCount=0,failedCount=0,busy=false,pending=[],pausedUntil=0,retryTimer=null,nextRequestAt=0,backoffMs=60000;
function hasSupportedSourceText(s){return /[A-Za-z\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]/.test(s)}
function sourceLanguage(s){const arabic=(s.match(/[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]/g)||[]).length;const latin=(s.match(/[A-Za-z]/g)||[]).length;return arabic>latin?"ar":"en"}
function eligible(node){const p=node.parentElement;if(!p||skipTags.has(p.tagName)||p.closest("#azm-language-picker,#azm-translation-note,script,style,textarea,input,select#preferredLanguage,code,pre"))return false;const s=node.nodeValue.trim();return s.length>1&&hasSupportedSourceText(s)&&sourceLanguage(s)!==lang}
const utf8Encoder=new TextEncoder();
function utf8Bytes(s){return utf8Encoder.encode(s).length}
function chunks(s,maxBytes){
 const out=[];let current="",bytes=0,lastSpace=-1;
 for(const ch of s){
  const size=utf8Bytes(ch);
  if(bytes+size>maxBytes&&current){
   const cut=lastSpace>0?lastSpace:current.length;
   out.push(current.slice(0,cut));
   current=current.slice(cut);bytes=utf8Bytes(current);lastSpace=-1;
   for(let i=0;i<current.length;i++)if(/\s/.test(current[i]))lastSpace=i+1;
  }
  current+=ch;bytes+=size;
  if(/\s/.test(ch))lastSpace=current.length;
 }
 if(current)out.push(current);
 return out;
}
async function waitForProviderSlot(){
 const wait=Math.max(0,nextRequestAt-Date.now());
 if(wait)await new Promise(resolve=>setTimeout(resolve,wait));
 nextRequestAt=Date.now()+2000;
}
async function translateChunk(s,source=sourceLanguage(s)){
 const key=source+"|"+lang+"|"+s;if(cache[key])return cache[key];
 if(Date.now()<pausedUntil){const e=new Error("provider_throttled");e.throttled=true;throw e}
 let lastError;
 for(let attempt=0;attempt<3;attempt++){
  try{
   await waitForProviderSlot();
   const response=await fetch(API,{method:"POST",headers:{"Content-Type":"application/json","apikey":(window.AL_AZM_SUPABASE&&window.AL_AZM_SUPABASE.publishableKey)||""},body:JSON.stringify({text:s,source,target:lang})});
   const data=await response.json();
   if(response.ok&&data.translated){
    cache[key]=data.translated;
    try{localStorage.setItem(cacheKey,JSON.stringify(cache))}catch(e){}
    backoffMs=60000;
    return data.translated;
   }
   if(response.status===429){
    pausedUntil=Date.now()+backoffMs;
    backoffMs=Math.min(backoffMs*2,1800000);
    const e=new Error(data.error||"provider_throttled");e.throttled=true;throw e;
   }
   if(!data.retryable)throw new Error(data.error||"translation_unavailable");
   lastError=new Error(data.error||"temporary_translation_error");
  }catch(e){
   if(e.throttled)throw e;
   lastError=e;
  }
  if(attempt<2)await new Promise(resolve=>setTimeout(resolve,700*(attempt+1)));
 }
 throw lastError||new Error("translation_unavailable");
}
function scheduleRetry(){
 if(retryTimer!==null)return;
 const wait=Math.max(1000,pausedUntil-Date.now());
 retryTimer=setTimeout(()=>{retryTimer=null;drain()},wait);
}
async function translateNode(node){
 if(!node.isConnected||processed.has(node)||!eligible(node))return;
 processed.add(node);const original=node.nodeValue,pieces=chunks(original,450),results=[];
 try{for(const piece of pieces)results.push(await translateChunk(piece,sourceLanguage(piece)));node.nodeValue=results.join("");translatedCount++}
 catch(e){failedCount++;processed.delete(node);if(e.throttled){pending.unshift(node);scheduleRetry()}}
}
async function drain(){
 if(busy)return;
 if(Date.now()<pausedUntil){scheduleRetry();return}
 busy=true;
 while(pending.length){
  if(Date.now()<pausedUntil)break;
  const node=pending.shift();
  await translateNode(node);
  if(Date.now()<pausedUntil)break;
 }
 busy=false;
 if(pending.length){
  scheduleRetry();
  notice("مزود الترجمة فرض حداً مؤقتاً. تم الاحتفاظ ببقية النصوص في قائمة الانتظار، وستستأنف الترجمة تلقائياً بعد انتهاء فترة الانتظار. الترجمات المحفوظة تبقى متاحة.");
  return;
 }
 notice("انتهت محاولة الترجمة. تمت ترجمة "+translatedCount+" مقطعاً؛ وتعذر ترجمة "+failedCount+" مقطعاً بسبب حدود مزود الترجمة أو عدم دعم زوج اللغات. الترجمات الناجحة محفوظة مركزياً.");
}
function enqueue(node){if(node&&node.nodeType===Node.TEXT_NODE){pending.push(node);drain()}else if(node&&node.nodeType===Node.ELEMENT_NODE){const walker=document.createTreeWalker(node,NodeFilter.SHOW_TEXT);while(walker.nextNode())if(eligible(walker.currentNode))pending.push(walker.currentNode);drain()}}
function scan(){enqueue(document.body);if(document.title&&hasSupportedSourceText(document.title)&&sourceLanguage(document.title)!==lang){translateChunk(document.title,sourceLanguage(document.title)).then(t=>{document.title=t}).catch(()=>{})}}
function observe(){const observer=new MutationObserver(records=>{for(const record of records){if(record.type==="characterData")enqueue(record.target);for(const added of record.addedNodes)enqueue(added)}});observer.observe(document.body,{subtree:true,childList:true,characterData:true})}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",()=>{scan();observe()},{once:true});else{scan();observe()}
})();