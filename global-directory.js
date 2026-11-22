(function(){
const countries=["AD","AE","AF","AG","AI","AL","AM","AO","AQ","AR","AS","AT","AU","AW","AX","AZ","BA","BB","BD","BE","BF","BG","BH","BI","BJ","BL","BM","BN","BO","BQ","BR","BS","BT","BV","BW","BY","BZ","CA","CC","CD","CF","CG","CH","CI","CK","CL","CM","CN","CO","CR","CU","CV","CW","CX","CY","CZ","DE","DJ","DK","DM","DO","DZ","EC","EE","EG","EH","ER","ES","ET","FI","FJ","FK","FM","FO","FR","GA","GB","GD","GE","GF","GG","GH","GI","GL","GM","GN","GP","GQ","GR","GS","GT","GU","GW","GY","HK","HM","HN","HR","HT","HU","ID","IE","IL","IM","IN","IO","IQ","IR","IS","IT","JE","JM","JO","JP","KE","KG","KH","KI","KM","KN","KP","KR","KW","KY","KZ","LA","LB","LC","LI","LK","LR","LS","LT","LU","LV","LY","MA","MC","MD","ME","MF","MG","MH","MK","ML","MM","MN","MO","MP","MQ","MR","MS","MT","MU","MV","MW","MX","MY","MZ","NA","NC","NE","NF","NG","NI","NL","NO","NP","NR","NU","NZ","OM","PA","PE","PF","PG","PH","PK","PL","PM","PN","PR","PS","PT","PW","PY","QA","RE","RO","RS","RU","RW","SA","SB","SC","SD","SE","SG","SH","SI","SJ","SK","SL","SM","SN","SO","SR","SS","ST","SV","SX","SY","SZ","TC","TD","TF","TG","TH","TJ","TK","TL","TM","TN","TO","TR","TT","TV","TW","TZ","UA","UG","UM","US","UY","UZ","VA","VC","VE","VG","VI","VN","VU","WF","WS","YE","YT","ZA","ZM","ZW"];
const languages=["af","am","ar","as","az","be","bg","bn","bs","ca","ceb","co","cs","cy","da","de","el","en","eo","es","et","eu","fa","fi","fil","fj","fr","fy","ga","gd","gl","gu","ha","haw","he","hi","hmn","hr","ht","hu","hy","id","ig","is","it","ja","jv","ka","kk","km","kn","ko","ku","ky","la","lb","lo","lt","lv","mg","mi","mk","ml","mn","mr","ms","mt","my","ne","nl","no","ny","om","or","pa","pl","ps","pt","ro","ru","rw","sd","si","sk","sl","sm","sn","so","sq","sr","su","sv","sw","ta","te","tg","th","tk","tl","to","tr","tt","ug","uk","ur","uz","vi","xh","yi","yo","zh","zh-Hant","yue","zu"];
const locale=(navigator.language||"en").split("-")[0];
let regions,languageNames;
try{regions=new Intl.DisplayNames([navigator.language||"en"],{type:"region"});}catch(e){}
try{languageNames=new Intl.DisplayNames([navigator.language||"en"],{type:"language"});}catch(e){}
const countryList=document.createElement("datalist");countryList.id="alazm-country-options";
countries.map(code=>({code,label:regions?.of(code)||code})).sort((a,b)=>a.label.localeCompare(b.label,locale)).forEach(x=>{const o=document.createElement("option");o.value=x.label;o.label=x.code;countryList.appendChild(o);});
document.body.appendChild(countryList);
document.querySelectorAll('input[name="country"],input#country,input#countryFilter').forEach(input=>input.setAttribute("list",countryList.id));
document.querySelectorAll('select#preferredLanguage').forEach(select=>{
 const previous=select.value;
 select.innerHTML=languages.map(code=>'<option value="'+code+'">'+(languageNames?.of(code)||code)+" ("+code+")</option>").join("");
 select.value=languages.includes(previous)?previous:(languages.includes(locale)?locale:"ar");
});
})();