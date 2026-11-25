# AL AZM GLOBAL REAL ESTATE — Company Foundation

**Document status:** Operational baseline for the current digital business.  
**Revision:** 2026-11-25  
**Legal status:** This document defines the intended operating model. It is not a certificate of incorporation, real-estate brokerage licence, tax registration, or proof of authority to trade in any jurisdiction.

## 1. Identity and scope

- Trading / product name: **AL AZM GLOBAL REAL ESTATE**
- Arabic name: **شركة العزم العالمية للعقارات**
- Business model: digital-first, multi-market property and asset marketing, brokerage introductions, buyer/seller lead generation, and partner referrals.
- Initial operating language: Arabic. English is the secondary international language; additional languages are introduced only after translation and support quality checks.
- Operating posture: global discovery and lead intake may be offered online, but regulated brokerage, representation, advertising, handling deposits, and transaction execution are performed only where the company and its contracted local partners are legally authorised.
- Geographic launch policy: Yemen is the initial coordination/home market for the founder's operations. Other countries are **prospecting markets only** until local licensing, partner authority, consumer-protection, privacy, tax, and advertising requirements have been checked and documented. Do not label any country as an active licensed market without evidence.
- No claim of a registered office, legal entity number, licence, local branch, or authorised agent is made by this document.

## 2. Service catalogue

### Property and land
1. Sale marketing: collect authorised property information, qualify the seller, verify source and publication rights, list approved offers, and introduce interested buyers.
2. Rental marketing: qualify landlord and tenant requirements, publish authorised rental offers, arrange introductions, and track the rental lead through agreement.
3. Buyer and tenant sourcing: capture requirements, budget, location, asset type, timing, and contact consent; match only against verified offers.
4. Seller and landlord sourcing: register the owner/source, evidence authority to market, and document agreed commission or marketing terms before work begins.
5. Brokerage / transaction introduction: introduce parties and coordinate follow-up. Negotiation, representation, escrow, deposits, contract drafting, and closing are handled only by appropriately licensed parties where required.

### Marketing and partnerships
6. Digital marketing: publish approved listings, landing pages, search-engine content, and campaign material with documented image/text rights.
7. Partner referrals: refer qualified leads to approved local brokers, agencies, developers, or service providers under a written referral/commission agreement.
8. Market research: prepare comparable-offer and location reports with source links, dates, and clear limitations.

### Other assets
Cars, motorcycles, and commercial shops may be accepted as separate categories only after the same source, ownership/authority, advertising-rights, and local legal checks. They are not to be represented as real estate.

## 3. Revenue controls

Permitted revenue models:
- Written brokerage commission, only where lawful and agreed before introductions.
- Written marketing/listing fee, if disclosed and lawful.
- Written referral/partner fee, with conflict disclosure where required.
- Contracted business-to-business marketing services.

Controls:
- No guaranteed earnings or guaranteed sale/rental claims.
- No collection or custody of customer deposits or purchase funds through the website.
- No fee or commission is recorded as earned until the contractual trigger is met and evidence is attached.
- Record gross amount, currency, payer, payee, agreement reference, due date, collected date, and split.
- Never promise a fixed commission percentage without a signed agreement and jurisdiction check.

## 4. Organisation and responsibility

| Function | Accountable role | Core responsibility |
|---|---|---|
| Governance and approvals | Owner | Legal scope, staff access, contracts, final publishing exceptions, finance oversight |
| Operations | Operations manager | Workflow, service levels, escalations, quality dashboard |
| Supply / listings | Listing & source officer | Owner/source onboarding, offer completeness, evidence |
| Verification | Verification reviewer | Identity/authority evidence, duplicate/fraud flags, image and text rights |
| Sales / CRM | Client relations officer | Buyer/seller qualification, consent, follow-up, deal stages |
| Partnerships | Partner manager | Local partner due diligence and written agreements |
| Marketing | Marketing officer | Approved campaigns, SEO, social publishing, attribution |
| Finance & compliance | Finance/compliance officer | Commission ledger, invoices, records, privacy and regulatory checklist |
| Technical administration | System administrator | Access administration and technical maintenance; cannot grant owner privileges |

One person may temporarily hold multiple functions, but each record must show the responsible person and reviewer. AI roles are software workflows, not human employees, and must not be presented as staffed positions.

## 5. Account and permission model

Database roles currently defined by the application:
- `owner`: sole top-level company authority.
- `admin`: operational administration; no owner-level role grants or owner account control.
- `reviewer`: review listing/source evidence and quality flags.
- `agent`: manage assigned leads and offers within assigned scope.
- `support`: limited customer support and permitted read/update actions.

Mandatory access rules:
- Least privilege; deny by default.
- No self-registration into staff roles.
- New Auth users default to `support` unless owner-controlled onboarding assigns an approved role.
- Only an active owner may invite/create, change staff roles, or deactivate staff.
- Admin cannot create another admin, change roles, deactivate owner, or grant owner.
- Deactivation must revoke or block access server-side, not merely hide a UI link.
- Every sensitive action must be audited with actor, target, action, timestamp, and outcome.
- Never expose the Supabase service-role key in browser code.
- Staff accounts must use individual identities; no shared passwords.

**Implementation status:** An owner-only staff administration API (`/api/staff-admin`) and page (`/staff-admin.html`) are implemented on the development branch. The API lists Auth users, sends invitations with a fixed trusted redirect, assigns only allowed non-owner roles, deactivates/reactivates accounts, and writes staff changes to the existing `public.audit_logs` table using the server-side service role. The branch code passed syntax validation and mocked handler tests for missing auth, non-owner/inactive-owner denial, owner listing, invitation, role update, deactivate/reactivate, invalid role rejection, and audit insertion. The Vercel preview is READY and the staff page returns HTTP 200. Live authenticated API integration, real email delivery, and a real staff lifecycle test remain NOT TESTED; invitation delivery depends on Supabase Auth email configuration. The production deployment has not been changed.

## 6. Listing publication policy

A listing remains private / pending review until all checks pass:
1. Source identity and contact details recorded.
2. Owner authority or source authority documented.
3. Explicit permission reference and permitted channels/scope recorded.
4. Text and image reuse rights independently confirmed.
5. Location, price/currency, asset category, and key facts are complete or explicitly marked unknown.
6. Duplicate and suspicious-content checks pass.
7. Reviewer approval recorded with timestamp.
8. Publication status changed only by an authorised workflow.

Missing, expired, conflicting, suspicious, duplicated, or unlicensed listings are held for human review. No automatic scraping or republication without permission.

## 7. Customer and transaction workflow

1. Lead intake with explicit contact consent and privacy notice.
2. Validate contact details and classify buy / sell / rent / lease / partnership / inquiry.
3. Qualify budget, asset, location, timeline, language, and preferred contact method.
4. Match against verified published offers only.
5. Assign a named agent and record every contact attempt.
6. Record viewing / introduction outcome and next action.
7. Record offer, negotiation status, and agreement references.
8. Record commission/referral terms before a payable introduction.
9. Close as won/lost with reason; retain records according to applicable law.

## 8. Security, continuity, and backups

- Keep RLS enabled and reviewed for every exposed table.
- Keep service-role credentials server-side and rotate immediately if exposed.
- Enforce HTTPS, secure response headers, request validation, rate limits, and no-store on sensitive API responses.
- Use MFA on GitHub, Vercel, and Supabase owner accounts where available.
- Review Supabase Security Advisor and Vercel runtime/build logs regularly.
- Keep production changes behind reviewed commits; no direct unreviewed database edits.
- Maintain a written incident response and access-revocation procedure.
- **Supabase Free does not provide downloadable managed database backups.** The documented no-upgrade path is regular logical exports using Supabase CLI `db dump` and off-site storage. Storage objects require a separate export because database dumps do not contain the actual files.
- A detailed free-plan export, Storage-object backup, and restore-drill procedure is documented in `SECURITY_BACKUP_RUNBOOK.md`. Backup acceptance requires: dated encrypted export, separate off-site copy, checksum, documented restore steps, and a successful restore drill to a separate safe environment. Never claim a backup is working until a restore drill passes.
- Automated managed backups / PITR are not enabled because they require a paid plan or add-on. No paid upgrade is authorised.

## 9. Launch gates

The company is not declared fully operational until all are evidenced:
- Owner login tested; recovery path and MFA reviewed.
- Human staff lifecycle (invite, role assignment, deactivation, session revocation) tested, with durable audit logging.
- RLS and API authorization tests pass for each role.
- Listing/source/media workflow tested with permissioned test material.
- Public lead POST tested with synthetic data and removed after verification.
- Backup export and restore drill pass, including Storage object recovery.
- Privacy, terms, local licensing, and partner contracts reviewed for each active market.
- No critical/high security findings remain unexplained.
- Production deployment and rollback path verified.

## 10. Current verified limitations

- Current Supabase project is on the Free plan; managed downloadable backups and PITR must not be assumed.
- The known database state had one active owner profile and no human staff accounts.
- Existing public listing, CRM, source, and AI employee tables do not themselves prove a staffed or revenue-generating operation.
- The AI worker remains disabled unless free-tier use is independently confirmed; this policy does not authorise paid API use.
- This charter does not certify legal incorporation, licensing, or permission to broker in any country.
