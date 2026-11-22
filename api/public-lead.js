const json = (res, status, body) => res.status(status).setHeader("Content-Type", "application/json").setHeader("Cache-Control", "no-store").json(body);
const crypto = require("crypto");
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

  const assetCategory = clean(body.assetCategory, 30) || "real_estate";
  if (!["real_estate","shop","car","motorcycle","other"].includes(assetCategory)) return json(res, 400, { error: "فئة العرض غير صالحة." });
  const preferredLanguage = clean(body.preferredLanguage, 20) || "ar";
  if (!/^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})?$/.test(preferredLanguage)) return json(res, 400, { error: "رمز لغة التواصل غير صالح." });
  const propertyType = clean(body.propertyType, 70);
  const budget = clean(body.budget, 70);
  const contactTime = clean(body.time, 30);
  const details = clean(body.details, 700);
  const detailParts = [];
  if (propertyType) detailParts.push("النوع أو الموديل: " + propertyType);
  detailParts.push("لغة التواصل المفضلة: " + preferredLanguage);
  if (budget) detailParts.push("الميزانية التقريبية: " + budget);
  if (contactTime) detailParts.push("وقت التواصل: " + contactTime);
  if (details) detailParts.push("تفاصيل العميل: " + details);
  detailParts.push("موافقة سياسة الخصوصية: v1");
  detailParts.push("موافقة مشاركة المعلومات الضرورية مع الطرف العقاري المخوّل: نعم");

  const serviceUrl = String(process.env.SUPABASE_URL || "https://latgmqklsszgictpuerp.supabase.co").replace(/\/$/, "");
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceKey) return json(res, 503, { error: "خدمة استقبال الطلبات غير مهيأة حالياً. حاول لاحقاً." });

  try {
    const ip = String(req.headers["x-forwarded-for"] || req.socket?.remoteAddress || "unknown").split(",")[0].trim().slice(0, 80);
    const rateSalt = process.env.LEAD_RATE_LIMIT_SALT || serviceKey;
    const ipHash = crypto.createHash("sha256").update(rateSalt).update(":").update(ip).digest("hex");
    const rateCheck = await fetch(serviceUrl + "/rest/v1/rpc/allow_public_lead_submission", {
      method: "POST",
      headers: { apikey: serviceKey, "Content-Type": "application/json" },
      body: JSON.stringify({ p_ip_hash: ipHash }),
      signal: AbortSignal.timeout(5000)
    });
    if (!rateCheck.ok) {
      console.error("[public-lead] rate-limit check failed", { status: rateCheck.status });
      return json(res, 503, { error: "تعذر التحقق من حد الإرسال الآمن. حاول لاحقاً." });
    }
    const allowed = await rateCheck.json();
    if (allowed !== true) {
      res.setHeader("Retry-After", "20");
      return json(res, 429, { error: "انتظر 20 ثانية قبل إرسال طلب آخر." });
    }

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
        asset_category: assetCategory,
        preferred_language: preferredLanguage,
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
