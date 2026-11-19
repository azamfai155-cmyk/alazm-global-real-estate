# AL AZM GLOBAL REAL ESTATE

المشروع المستقل لشركة العزم العالمية للعقارات.

## الملفات
- `index.html`: الموقع التعريفي العربي المتجاوب.
- `admin.html`: لوحة عمليات أولية لإدارة العقارات وطلبات العملاء والمصادر وسياسة فحص النشر.

## ما تعمل به النسخة الحالية
- تسجيل العقارات محلياً.
- فحص أولي لأهلية النشر: مصدر مسجل، إذن صريح ومرجعه، اكتمال البيانات، وعدم وجود تكرار أو علامة اشتباه.
- إحالة السجلات غير المستوفية إلى المراجعة البشرية.
- إدارة طلبات العملاء ومصادر العقارات والشركاء.
- تصدير واستيراد نسخة احتياطية بصيغة JSON.

## حدود النسخة الحالية
هذه نسخة واجهة تشغيل محلية أولية وليست منصة إنتاج مكتملة:
- البيانات محفوظة في LocalStorage على المتصفح والجهاز الحالي فقط.
- لا توجد قاعدة بيانات أو مزامنة أو حسابات وصلاحيات مستخدمين.
- لا توجد واجهات API أو تكاملات خارجية أو نشر تلقائي على منصات أخرى.
- لا يوجد اتصال فعلي بنموذج ذكاء اصطناعي أو موظفين آليين نشطين.
- لا تستخدمها لحفظ بيانات هوية أو وثائق ملكية أو معلومات مالية حساسة.

## النشر على Netlify
1. افتح https://app.netlify.com/
2. اختر Add new site ثم Import an existing project.
3. اربط GitHub واختر المستودع `alazm-global-real-estate` والفرع `main`.
4. اترك Build command فارغاً.
5. اجعل Publish directory هو `.`.
6. اضغط Deploy site.

## متطلبات ما قبل الإنتاج
1. قاعدة بيانات وخادم API مع قواعد صلاحيات.
2. تسجيل دخول آمن وأدوار (مدير، مراجع، موظف).
3. سجل تدقيق غير قابل للتلاعب لموافقات النشر.
4. تخزين آمن للمستندات مع ضوابط وصول.
5. فحص تكرار فعلي ومراجعة قانونية حسب الدولة.
6. تكاملات مصادر العقارات وفق شروط الاستخدام وحقوق إعادة النشر.
7. اختبار أمني ووظيفي قبل فتح النظام للعامة.

لا تضف إعلاناً إلا بعد الحصول على إذن المالك أو ممثله المخوّل والتحقق من المعلومات. لا تضع مفاتيح API أو كلمات مرور في هذا المستودع العام.


## Supabase database setup (next activation step)

A first schema migration is included at:
`supabase/migrations/202611190001_initial_schema.sql`

It defines profiles and staff roles, property sources, property listings, media rights metadata, customer leads, audit logs, and row-level security policies.

To activate it:
1. Create a Supabase project at https://supabase.com/dashboard (choose a region suitable for your audience and review the free-tier limits).
2. Open SQL Editor and run the migration file.
3. Create the first user through Supabase Auth.
4. Verify that user's UUID in Authentication > Users, then promote that exact account to owner from the SQL Editor:
   `update public.profiles set role = 'owner', active = true where id = '<verified-auth-user-uuid>';`
5. Store the Supabase project URL and anon key only in the frontend environment configuration; never expose the service_role key in browser code or GitHub.
6. Connect the application to Supabase Auth and database APIs, then test RLS with separate owner, reviewer, agent, and anonymous sessions.

Important: The migration has been committed but has NOT been executed against a live Supabase project. No Supabase project credentials were available in this repository workflow. Until the migration is applied and RLS tests pass, the cloud database and authentication remain inactive.
