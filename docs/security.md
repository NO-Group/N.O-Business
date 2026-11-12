# Security assessment

Scope: the code in this repository at the time of writing, and what the
repository's history reveals about the previous system. No secret values
appear in this document.

## Summary

| Area | Assessment |
| --- | --- |
| Tenant isolation | Enforced in the database and tested, including by mutation testing |
| Authorization | Permission checks in policies and in every function; tested for insiders and outsiders |
| Secrets in the client | None. Only the public key is accepted, and a privileged key is rejected at start-up |
| Secrets in the repository | None in the current tree. One public client key of the previous project remains in git history (see below) |
| Session storage | Operating-system credential store, never plain preferences |
| Verified in a live environment | **No.** See "Open items" |

## How it was assessed

- **Database tests.** 334 assertions run against PostgreSQL in CI. They act
  as an anonymous caller, as members of two different organizations, as each
  built-in role, as a suspended member and as the service role.
- **Mutation testing of the functions.** Each permission check and guard in
  the functions was removed in turn and the suite re-run. Every such change
  made a test fail (no surviving mutants).
- **Mutation testing of the policies.** Each `using` and `with check`
  expression was replaced by `true` in turn: 43 mutants, 37 detected. The six
  undetected are all `with check` clauses of update policies
  (`profiles_update_self`, `organizations_update`, `workspaces_update`,
  `customers_update`, `products_update`, `documents_update`). In each case
  the `using` clause of the same policy already limits which rows can be
  updated, and a separate mechanism stops a row being moved out of that set
  (the trigger that refuses to change `organization_id`, or column grants
  that exclude the key). The clauses are therefore a second line of defence
  with no test of their own, not an open hole.
- **Contract check.** Function names, parameters and columns used by the app
  were compared mechanically with the migrations.
- **Secret scan.** The working tree and the full git history were searched
  for keys, tokens and private-key material.

Not done: penetration testing against a deployed project, dependency
vulnerability scanning, review by a second person.

## Controls in place

**Backend**

- Row-level security on every table; a test fails if a table is added
  without it.
- No privileges for `anon`; explicit, column-level grants for
  `authenticated`.
- Roles, memberships, invitations and the audit trail are writable only
  through functions that check permissions.
- Functions use a fixed empty `search_path`, so objects cannot be shadowed.
- A role cannot be created or edited to hold a permission its author lacks;
  built-in roles are immutable; the last owner cannot leave, be demoted,
  suspended or removed.
- Accepting an invitation requires a confirmed email address that matches
  the invitation.
- Pending invitations per organization are capped, and a seat limit is
  honoured when one is set.
- Totals, tax, balances and stock are computed server-side. Client-supplied
  totals are not accepted.
- Composite foreign keys and a tenant-lock trigger make cross-tenant
  references impossible even for a caller that bypasses row-level security.
- The audit trail is append-only for every role.
- The file bucket is private, with size and type limits and per-organization
  object policies.
- Suspending a member removes their access immediately, because every check
  reads the membership's current status.

**Client**

- The backend URL and public key are supplied at build time and are not in
  the source. A service-role or secret key is detected and refused.
- Only `https` backend URLs are accepted, apart from localhost for
  development.
- The session, which contains the refresh token, is kept in the Android
  Keystore-backed store or the Windows credential store. If that store is
  unavailable the session is not persisted at all.
- Android: backups are disabled, and the app's own manifest requests only
  network access (plugins may add what they need, such as file access for
  the document picker).
- Error messages shown to users never include table, constraint or policy
  names. Logs redact credential-like fields.
- Search input is stripped of characters that have meaning in filter syntax
  before it is used in a query.
- Uploaded file names are reduced to a safe character set and stored under a
  generated identifier.
- Passwords need at least 10 characters with a letter and a digit, in the
  app and in the suggested project configuration.

**Build and release**

- Signing material and backend settings come from CI secrets and are never
  written to the repository. `.gitignore` excludes keystores, certificates
  and `.env` files.
- The CI workflow has read-only repository access, except for the single
  step that commits formatting on working branches.
- The Flutter version is pinned and the dependency lockfile is committed.

## Findings from the previous codebase

| # | Finding | Severity | Status |
| --- | --- | --- | --- |
| 1 | All data access went through one edge function that used the service-role key and re-implemented authorization in application code, with the platform's JWT check switched off for that function. Any mistake in that code exposed every row | High | Removed. Replaced by row-level security and SQL functions |
| 2 | The production project URL and its public client key were compiled into the source as defaults | Medium | Removed from the tree. **Still present in git history** |
| 3 | Sign-in could fall back to a locally stored password hash when the server was unreachable | High | Removed. There is no offline sign-in |
| 4 | A specific user id was treated as a super-user through an environment variable | Medium | Removed. Ownership is a role, and an organization may have several owners |
| 5 | The schema was created outside version control (one migration file existed), so it could not be reviewed or reproduced | Medium | Replaced by complete, tested migrations |
| 6 | Single-tenant by design: one company's name, branding and data model throughout | Design | Replaced by a multi-tenant model |

### The key in git history

The history of this repository contains the URL and the public ("anon")
client key of the previous Supabase project. No service-role key, password
or signing key was found in the tree or the history.

A public client key is designed to be shipped in apps, so its exposure is
not by itself a breach. What it allows depends on that project's row-level
security, which this repository cannot show. Because the previous design
relied on an edge function rather than on row-level security, the tables of
that project should be assumed to be only as protected as their policies
are.

Recommended, in this order:

1. In the previous project, confirm that row-level security is enabled on
   every table and that the `anon` role can read nothing.
2. Use a **new project** for N.O Business, as the migration plan says, so
   the old key has no bearing on the new system.
3. When the old project is retired, rotate its keys and pause it.
4. Rewriting git history to remove the key is optional. It does not
   un-publish a key that has been in a public repository or in distributed
   app builds; rotating the key is what ends its usefulness.

## Open items

| # | Item | Why it matters | Suggested action |
| --- | --- | --- | --- |
| 1 | Nothing has been run against a live Supabase project | The tests use a stand-in for `auth` and `storage`. Hosted behaviour, especially of Storage, may differ | Run the checklist in [status.md](status.md) on a scratch project before release |
| 2 | Release signing is unexercised | CI artifacts are signed with debug or test credentials | Add the signing secrets and verify a signed build installs |
| 3 | Six update policies have an untested `with check` clause | Defence in depth without a regression test | Add a test per clause, or record them as accepted |
| 4 | No rate limiting beyond Supabase Auth's own and the invitation cap | A signed-in member could call functions in a tight loop | Acceptable at small scale; revisit with usage data |
| 5 | No multi-factor authentication in the app | Account takeover by password alone | TOTP enrolment is enabled in the suggested configuration; the app needs screens for it |
| 6 | No dependency vulnerability scanning in CI | Known-vulnerable packages could go unnoticed | Enable Dependabot alerts for the repository |
| 7 | An uploaded file can be orphaned if its record fails to save and the uploader lacks delete permission | Storage clutter; the file stays inside the tenant's private folder | A scheduled clean-up, or a server-side upload function |
| 8 | Invitations are not emailed | An invited person must be told out of band to sign up with that address | Add an edge function that sends the invitation email |
| 9 | No in-app account deletion or data export | May be required by privacy law or app-store policy, depending on where the app is offered | Decide the policy, then build it |

## Operational recommendations

- Keep the service-role key out of every client, script and CI job that does
  not strictly need it. The app never needs it.
- Enable leaked-password protection and CAPTCHA on sign-up in the Supabase
  dashboard before opening registration to the public.
- Turn on point-in-time recovery or scheduled backups for the project, and
  test a restore.
- Review the Supabase security advisor after applying the migrations.
