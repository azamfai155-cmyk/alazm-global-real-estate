-- Enable the 12 defined AI roles on the shared, constrained Gemini report-only adapter.
-- This does NOT grant external browsing, publishing, messaging, transactions, or autonomous approvals.
-- Every output remains in needs_review until the owner reviews it.
update public.ai_employees
set enabled = true,
    requires_human_approval = true,
    updated_at = now()
where id in ('ceo','sourcing','rights','quality','marketing','publishing','buyers','sellers','sales','analyst','localization','audit');
