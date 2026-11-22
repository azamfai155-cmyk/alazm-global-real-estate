const json = (res, status, body) => res.status(status).setHeader("Content-Type", "application/json").setHeader("Cache-Control", "no-store").json(body);
const recent = new Map();
const kinds = new Map([
  ["شراء عقار", "buy"],
  ["بيع عقار", "sell"],
  ["استئجار عقار", "rent"],
  ["تأجير عقار", "lease"],
  ["شراكة أو تعاون", "partnership"],
  ["استفسار عام", "inquiry"]
]);
const clean = (value, max) => String(value || "").trim().replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "").slice(0, max);

module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return json(res, 405, { error: "Method not allowed" });
  }

  // Accept browser submissions only from the production website.
  const origin = req.headers.origin || "";
  let originHost = "";
  try { originHost = new URL(origin).host.toLowerCase(); } catch (_) {}
  const allowedHosts = new Set([
    "alazm-global-real-estate.vercel.app",
    "alazm-global-real-estate-azamfai155-cmyk.vercel.app",
    "alazm-global-real-estate-git-main-azamfai155-cmyk.vercel.app",
    String(process.env.VERCEL_PROJECT_PRODUCTION_URL || "").toLowerCase(),
    String(process.env.VERCEL_URL || "").toLowerCase()
  ].filter(Boolean));
  if (!origin || !origin.startsWith("https://") || !allowedHosts.has(originHost)) {
    return json(res, 403, { error: "مصدر الطلب غير مسموح." });
  }

  const length = Number(req.headers["content-length"] || 0);
  if (length > 12000) return json(res, 413, { error: "حجم الطلب أكبر من المسموح." });
  const body = typeof req.body === "string" ? (() => { try { return JSON.parse(req.body); } catch (_) { return null; } })() : (req.body || {});
  if (!body || typeof body !== "object" || Array.isArray(body)) return json(res, 400, { error: "بيانات الطلب غير صالحة." });

  // Honeypot for basic bot filtering. Do not store bot submissions.
  if (clean(body.website, 120)) return json(res, 200, { ok: true });

  const ip = String(req.headers["x-forwarded-for"] || req.socket?.remoteAddress || "unknown").split(",")[0].trim().slice(0, 80);
  const now = Date.now();
  const last = recent.get(ip) || 0;
  if (now - last < 20000) return json(res, 429, { error: "انتظر قليلاً قبل إرسال طلب آخر." });
  if (recent.size > 5000) {
    for (const [key, time] of recent) if (now - time > 60000) recent.delete(key);
  }
  recent.set(ip, now);

  const full_name = clean(body.name, 80);
  const phone = clean(body.phone, 30);
  const country = clean(body.country, 70);
  const city = clean(body.city, 70);
  const kind = kinds.get(clean(body.purpose, 40));
  const digits = phone.replace(/\D/g, "");
  if (full_name.length < 2) return json(res, 400, { error: "أدخل الاسم بشكل صحيح." });
  if (digits.length < 7 || digits.length > 20) return json(res, 400, { error: "أدخل رقم تواصل صحيحاً مع مفتاح الدولة." });
  if (!country || !city) return json(res, 400, { error: "الدولة والمدينة مطلوبتان." });
  if (!kind) return json(res, 400, { error: "نوع الطلب غير صالح." });
  if (body.consent !== true) return json(res, 400, { error: "يجب الموافقة على حفظ البيانات والتواصل بشأن الطلب." });

  const propertyType = clean(body.propertyType, 70);
  const budget = clean(body.budget, 70);
  const contactTime = clean(body.time, 30);
  const details = clean(body.details, 700);
  const detailParts = [];
  if (propertyType) detailParts.push("نوع العقار: " + propertyType);
  if (budget) detailParts.push("الميزانية التقريبية: " + budget);
  if (contactTime) detailParts.push("وقت التواصل: " + contactTime);
  if (details) detailParts.push("تفاصيل العميل: " + details);

  const serviceUrl = String(process.env.SUPABASE_URL || "https://latgmqklsszgictpuerp.supabase.co").replace(/\/$/, "");
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceKey) return json(res, 503, { error: "خدمة استقبال الطلبات غير مهيأة حالياً. حاول لاحقاً." });

  try {
    const response = await fetch(serviceUrl + "/rest/v1/leads", {
      method: "POST",
      headers: {
        apikey: serviceKey,
        "Content-Type": "application/json",
        Prefer: "return=representation"
      },
      body: JSON.stringify({
        full_name,
        phone,
        kind,
        country,
        city,
        details: detailParts.join("\n").slice(0, 1600) || null,
        consent_to_contact: true
      }),
      signal: AbortSignal.timeout(8000)
    });
    if (!response.ok) {
      console.error("[public-lead] database insert failed", { status: response.status });
      return json(res, 502, { error: "تعذر حفظ الطلب حالياً. حاول مرة أخرى بعد قليل." });
    }
    const rows = await response.json();
    const lead = Array.isArray(rows) ? rows[0] : null;
    if (!lead?.id) return json(res, 502, { error: "لم نتأكد من حفظ الطلب. حاول مرة أخرى." });
    return json(res, 201, { ok: true, reference: lead.id });
  } catch (error) {
    console.error("[public-lead] request failed", { name: error?.name || "Error", message: String(error?.message || error).slice(0, 180) });
    return json(res, 503, { error: "تعذر الاتصال بخدمة استقبال الطلبات. حاول لاحقاً." });
  }
};
