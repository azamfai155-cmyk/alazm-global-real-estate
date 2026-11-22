(function(){
"use strict";
const LANGS=["aa","ab","ae","af","ak","am","an","ar","as","av","ay","az","ba","be","bg","bh","bi","bm","bn","bo","br","bs","ca","ce","ch","co","cr","cs","cu","cv","cy","da","de","dv","dz","ee","el","en","eo","es","et","eu","fa","ff","fi","fj","fo","fr","fy","ga","gd","gl","gn","gu","gv","ha","he","hi","ho","hr","ht","hu","hy","hz","ia","id","ie","ig","ii","ik","io","is","it","iu","ja","jv","ka","kg","ki","kj","kk","kl","km","kn","ko","kr","ks","ku","kv","kw","ky","la","lb","lg","li","ln","lo","lt","lu","lv","mg","mh","mi","mk","ml","mn","mr","ms","mt","my","na","nb","nd","ne","ng","nl","nn","no","nr","nv","ny","oc","oj","om","or","os","pa","pi","pl","ps","pt","qu","rm","rn","ro","rw","sa","sc","sd","se","sg","si","sk","sl","sm","sn","so","sq","sr","ss","st","su","sv","sw","ta","te","tg","th","ti","tk","tl","tn","to","tr","ts","tt","tw","ty","ug","uk","ur","uz","ve","vi","vo","wa","wo","xh","yi","yo","za","zh","zu"];
const RTL=new Set(["ar","fa","he","ur","ps","sd","ug","yi","dv"]);
const names=(()=>{try{return new Intl.DisplayNames([navigator.language||"en"],{type:"language"})}catch(e){return null}})();
const path=location.pathname,segments=path.split("/").filter(Boolean);
const pathLocale=segments.length&&LANGS.includes(segments[0])?segments[0]:null;
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
if(lang==="en")return;
notice("ترجمة آلية تجريبية للمحتوى الثابت فقط. قد تبقى أجزاء دون ترجمة؛ النسخة الإنجليزية هي المرجع. لا تُرسل بيانات النماذج إلى خدمة الترجمة.");
const cacheKey="azm_mt_cache_v1",usageKey="azm_mt_usage_v1";let cache={};try{cache=JSON.parse(localStorage.getItem(cacheKey)||"{}")}catch(e){}
let usage={date:"",chars:0};try{usage=JSON.parse(localStorage.getItem(usageKey)||"{}")}catch(e){}
const today=new Date().toISOString().slice(0,10);if(usage.date!==today)usage={date:today,chars:0};const maxDaily=4500;
const skipTags=new Set(["SCRIPT","STYLE","NOSCRIPT","TEXTAREA","INPUT","SELECT","OPTION","SVG","CODE","PRE"]);
function eligible(node){const p=node.parentElement;if(!p||skipTags.has(p.tagName)||p.closest("#azm-language-picker,#azm-translation-note,script,style,textarea,input,select,option,code,pre"))return false;const s=node.nodeValue.trim();return s.length>1&&/[A-Za-z]/.test(s)}
function chunks(s,max){const out=[];let rest=s;while(rest.length>max){let cut=rest.lastIndexOf(" ",max);if(cut<max*.55)cut=max;out.push(rest.slice(0,cut));rest=rest.slice(cut)}if(rest)out.push(rest);return out}
async function translateChunk(s){const key=lang+"|"+s;if(cache[key])return cache[key];if(usage.chars+s.length>maxDaily)throw new Error("daily-limit");const url="https://api.mymemory.translated.net/get?"+new URLSearchParams({q:s,langpair:"en|"+lang,mt:"1"});const response=await fetch(url,{method:"GET",headers:{Accept:"application/json"}});if(!response.ok)throw new Error("translation-http-"+response.status);const data=await response.json(),translated=data&&data.responseData&&data.responseData.translatedText;if(!translated||data.responseStatus!==200||translated.toLowerCase()===s.toLowerCase())throw new Error("translation-unavailable");cache[key]=translated;usage.chars+=s.length;try{localStorage.setItem(cacheKey,JSON.stringify(cache));localStorage.setItem(usageKey,JSON.stringify(usage))}catch(e){}return translated}
async function run(){const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT),nodes=[];while(walker.nextNode())if(eligible(walker.currentNode))nodes.push(walker.currentNode);let done=0,limited=false;for(const node of nodes){if(!node.isConnected)continue;const original=node.nodeValue,pieces=chunks(original,430),results=[];try{for(const piece of pieces)results.push(await translateChunk(piece));node.nodeValue=results.join("");done++}catch(e){if(String(e.message).includes("daily-limit")||String(e.message).includes("429")){limited=true;break}}}if(limited)notice("وصلنا إلى الحد المجاني اليومي للترجمة؛ ستبقى بعض النصوص بلغتها الأصلية. لم تُرسل أي بيانات من النماذج.");else if(done===0)notice("تعذرت الترجمة حالياً أو أن اللغة غير مدعومة من الخدمة المجانية؛ المحتوى الأصلي ما زال متاحاً.");else notice("تمت ترجمة "+done+" مقطعاً آلياً. راجع المعنى قبل الاعتماد على المعلومات القانونية أو التعاقدية.")}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",run,{once:true});else run();
})();