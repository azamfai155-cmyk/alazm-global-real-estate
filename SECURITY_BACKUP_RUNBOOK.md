# Security and Backup Runbook — AL AZM GLOBAL REAL ESTATE

**Applies to:** Supabase project on the Free plan and Vercel production project.  
**Policy:** no paid add-ons, no third-party paid backup service, no secrets committed to Git.

## 1. Owner account and access

- Keep the owner account unique; never share its password or recovery codes.
- Enable MFA on the GitHub, Supabase, and Vercel accounts.
- Store recovery codes offline in a secure place.
- Review active sessions and revoke sessions when a staff member leaves.
- Staff invitations are sent only after the owner confirms the email address and intended role.
- Start all new staff with the least-privileged `support` role. Promote only after identity and duties are checked.
- The staff admin API is `/api/staff-admin`; its UI is `/staff-admin.html`. It is owner-only. The invite endpoint sends email and therefore must be tested with a controlled address before operational use.
- Staff invitation and account changes are written by the owner-only API to the existing `public.audit_logs` table using the server-side service role. Verify `audit_logged: true` in API responses and periodically review the restricted audit log. The API handler has passed mocked tests; live authenticated end-to-end testing remains NOT TESTED.

## 2. Database baseline

Before every schema or policy change:
1. Review the SQL and intended access paths.
2. Export the current schema and data using the approved backup process below.
3. Apply changes through reviewed migrations, not ad-hoc production edits.
4. Re-run RLS and role authorization checks.
5. Record migration commit, operator, time, and outcome.

Minimum checks:
- RLS enabled on every exposed table.
- No service-role or secret key in browser assets, Git, logs, or public build output.
- Every server API verifies the Supabase user token and checks the active profile role.
- Sensitive responses use `Cache-Control: no-store`.
- Staff deactivation blocks Auth sessions and marks the profile inactive.
- Test anonymous, support, agent, reviewer, admin, and owner access separately.

## 3. Free-plan logical database export

Supabase Free does not provide downloadable managed backups. Run this on a trusted computer with Supabase CLI installed. Obtain the database connection string from the Supabase dashboard privately; never paste it into chat or commit it.

Example shell procedure:

```bash
umask 077
mkdir -p "$HOME/alazm-backups"
export SUPABASE_DB_URL='PASTE_DATABASE_CONNECTION_STRING_LOCALLY'
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
supabase db dump --db-url "$SUPABASE_DB_URL" -f "$HOME/alazm-backups/alazm-$STAMP.sql"
unset SUPABASE_DB_URL
sha256sum "$HOME/alazm-backups/alazm-$STAMP.sql" > "$HOME/alazm-backups/alazm-$STAMP.sql.sha256"
```

Confirm the dump file is non-empty and inspect the CLI exit code. Encrypt the dump before copying it to a separate storage location. Keep the encryption key separate from the backup. Do not upload an unencrypted dump to a public drive or repository.

## 4. Storage object backup

A database dump contains Storage metadata, not the actual image/object bytes. Export every required object from the private Storage buckets separately using an authenticated, owner-controlled process. Preserve each bucket name and object path. Generate a manifest and checksums. Do not make private buckets public for convenience.

The object export procedure must be tested independently. Do not mark Storage backup complete based only on a database dump.

## 5. Restore drill

A backup is not accepted until it has been restored successfully:
1. Use a separate disposable project/environment that is confirmed free and isolated from production.
2. Restore the SQL dump using the documented Supabase restore process.
3. Restore the Storage objects to matching private buckets.
4. Verify table counts, key relationships, RLS policies, triggers, functions, and sample object retrieval.
5. Record start/end time, errors, checksum, and verification results.
6. Delete the disposable test environment only after evidence is recorded.

If no free isolated restore environment is available, mark the restore drill **NOT TESTED**. Never test restoration over production.

## 6. Vercel and website controls

- Require HTTPS and preserve the existing security response headers.
- Review deployment diffs before production promotion.
- Keep production secrets in Vercel Environment Variables, not source files.
- Do not expose deployment protection bypass secrets.
- Review runtime errors, deployment logs, and API authorization failures.
- Do not enable Gemini or other paid APIs until no-cost use is verified independently.

## 7. Incident response

If a credential or staff account is compromised:
1. Disable the staff account from the owner-only staff console.
2. Revoke relevant sessions and rotate affected credentials at their provider.
3. Preserve logs and timestamps.
4. Review recent role changes, leads, listings, and storage activity.
5. Restore from backup only after identifying the recovery point and assessing data loss.
6. Document the incident and the corrective action.

## 8. Completion evidence

Record these as separate statuses; do not infer one from another:

- Database export completed: date, file size, checksum.
- Off-site encrypted copy completed: location reference (never key).
- Storage objects exported: bucket list, object count, manifest checksum.
- Database restore drill: PASS / FAIL / NOT TESTED.
- Storage restore drill: PASS / FAIL / NOT TESTED.
- Owner MFA reviewed: date.
- Staff invite/deactivate tests: mocked handler tests PASS; live Auth/email/session lifecycle NOT TESTED.
- RLS/role matrix tests: PASS / FAIL / NOT TESTED.
