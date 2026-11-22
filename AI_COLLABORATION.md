# AL AZM GLOBAL REAL ESTATE — Shared AI Collaboration Brief

Last updated: 2026-11-22

This file is the shared handoff context for ChatGPT and Claude. Read it before proposing or making project changes, and update it when verified project decisions or implementation status changes.

## Project identity
- Company/project: AL AZM GLOBAL REAL ESTATE
- Legacy Lovable project name: Nexora Global Realty
- GitHub repository: https://github.com/azamfai155-cmyk/alazm-global-real-estate
- Default branch: main
- Production URL: https://alazm-global-real-estate.vercel.app/
- Supabase project: AL AZM GLOBAL REAL ESTATE
- Supabase project ref: `latgmqklsszgictpuerp`
- Supabase region: ap-northeast-1
- Supabase status at last check: ACTIVE_HEALTHY
- Lovable is connected to this project ecosystem; exact Lovable project/workspace IDs still need verification.

## Business objective
Build a reliable real-estate platform that attracts buyers and sellers, collects property offers from social platforms and other sources only where collection and redistribution are authorized, and presents verified properties to customers.

## Publication and safety policy
- Automatic publication is allowed only after source provenance, explicit authorization/redistribution rights, completeness, duplicate checks, and suspicious-listing checks all pass.
- Suspicious, incomplete, duplicate, or unauthorized listings must be held for human review.
- Never bypass authorization, RLS, audit logging, or approval controls.
- Do not expose service-role keys, API keys, passwords, customer personal data, or other secrets in source control, prompts, logs, or frontend code.
- Do not perform destructive database changes or production-impacting actions without explicit owner approval.

## Verified repository architecture (from README)
- `index.html`: public company website and lead intake.
- `properties.html`: public catalog; published properties only.
- `privacy.html`: privacy notice.
- `login.html`: Supabase Auth login.
- `admin-cloud.html`: cloud operations dashboard.
- `employees-cloud.html`: cloud team interface.
- `employee-profiles.html`: proposed role cards, not active employees.
- `api/ai-tasks.js`, `api/run-task.js`, `api/public-lead.js`: server-side task, reporting, and lead intake endpoints.
- `supabase/migrations/`: database schema, policies, and security migrations.

## Verified status and limitations
- GitHub Actions migration workflow run #15 succeeded on 2026-11-21; baseline was skipped and `supabase db push` completed successfully.
- Do not rerun `baseline_existing_schema`; it must remain false.
- Vercel production environment has server-side variables configured: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `GEMINI_API_KEY`. Never request or copy their values into GitHub.
- Twelve AI role configurations currently use one shared, limited Gemini reporting adapter. They are not independent autonomous agents and have no external browsing, publishing, or outreach permissions. Reports remain `needs_review` and require human approval.
- The public catalog reads only listings with status `published`.
- There is no automated property-source ingestion integration yet.
- There is no external auto-publication integration.
- Public lead intake has input validation, consent, a honeypot, and an instance-local temporary rate limit. Centralized rate limiting/CAPTCHA remains a pre-scale requirement.
- A successful Vercel deployment does not by itself prove end-to-end login, database, or UI workflows.

## Priority verification backlog
1. Verify the owner account exists in Supabase Auth.
2. Verify the correct owner UUID, `public.profiles` role = `owner`, and `active = true`.
3. Test `/login.html` and `/admin-cloud.html` with an authorized owner account.
4. Submit a synthetic test lead and verify it appears in the dashboard and database.
5. Test adding a source and property as owner; verify database records and audit trail.
6. Run one safe executive-report task and verify report and run-log persistence.
7. Test role separation and RLS using test accounts before inviting staff.
8. Implement centralized rate limiting/CAPTCHA before significant public traffic.
9. Build source ingestion only with documented permissions and redistribution rights.

## Collaboration protocol for Claude
1. Start by reading this file and the current repository state; do not assume this brief is more current than the code.
2. Inspect relevant files, migrations, workflows, and tests before suggesting changes.
3. Prefer small, reviewable commits on a feature branch and open a pull request; do not push unreviewed production changes directly to `main`.
4. For each task, report: observed evidence, root cause, files changed, tests run, test results, remaining risks, and any owner approval needed.
5. Do not claim a test passed unless it was actually executed and its output checked.
6. Coordinate through GitHub issues/PRs and this shared brief. ChatGPT and Claude do not automatically see each other's private chat histories; this repository is the shared source of truth unless an explicit integration is configured.
7. Before any production-impacting, destructive, financial, legal, external-publication, or permission-changing action, stop and request owner approval.

## Current AI collaboration status
- A direct native ChatGPT ↔ Claude conversation sync has not been configured.
- This file provides a safe, repository-based shared context that Claude can read after the repository is connected/imported in Claude.
- A true automated two-way bridge would require a separately configured integration (for example, a controlled service using the Anthropic API and GitHub webhooks/MCP). No Anthropic API key or Claude integration credential is configured here.
