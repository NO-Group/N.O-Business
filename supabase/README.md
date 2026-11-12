# M-TEK server — Supabase + MongoDB ONLY (free tier is enough)

The apps (Android APK + Windows EXE) both talk to ONE backend:
**Supabase Auth** (sign-in) + the **`data-api` Edge Function** (all data,
stored in MongoDB across 7 databases). Nothing else exists — no website
hosting, no GitHub dependency.

STOCK IS NEVER SEEDED by the server: the products collection starts EMPTY
and fills through the apps' own fields (Add product / Import TXT →
`POST /api/products/upsert`). Serial books self-provision from 000000001.

## One-time setup — 4 clicks

**1. MongoDB Atlas → Network Access → + ADD IP ADDRESS → "Allow access from
anywhere" (0.0.0.0/0) → Confirm.**
(Supabase functions connect from rotating cloud IPs.)

**2. Supabase dashboard → Edge Functions → Secrets** — the pre-added
`SUPABASE_SECRET_KEY(S)` default stays exactly as it is. Add:

| Name | Value |
|---|---|
| `MONGODB_URI` | your Atlas connection string (`mongodb+srv://…@mfsl.w5ifd7x.mongodb.net/…`) |

**3. Deploy the function — ONE file:** Edge Functions → Create a new
function → name `data-api` → in the editor open `index.ts` → select all →
paste the whole contents of **`supabase/functions/data-api/index.ts`** →
**Deploy**. (It has no side files; nothing else to add.)

**4. Supabase → Authentication → Users → "Add user"** → email
`mtekfiresafetyltd@gmail.com` + the company password → tick
"Auto-confirm user". This is only for the CEO account — it is locked to
this exact email and always gets the `ceo` role.

Everyone else (Admin/Sales staff) creates their own account straight from
the app's "Create an account →" link on the sign-in screen — no dashboard
work needed. It calls `POST /api/auth/signup` on the function above, which
uses the Supabase Admin API (the `SUPABASE_SERVICE_ROLE_KEY` the Edge
Runtime already injects automatically — nothing to add) to create a real
Supabase Auth user and a matching MongoDB profile, plus their phone number
(so it shows in Authentication → Users) and their self-chosen recovery
phrase (≥15 characters — the only way to reset a forgotten password; there
is no email/OTP flow). New accounts always start as `sales`. Promotion to
`admin` is done entirely INSIDE the app now — sign in as the CEO, open the
**Staff** screen, and tap "Make Admin"/"Demote" next to a name; nothing to
edit in Supabase or MongoDB by hand any more. Every signed-in user (CEO,
Admin, Sales) also sees a live **Notifications** feed of every sale,
invoice payment, document issued, stock change, new customer/product and
MILS job, and CEO/Admin can post announcements from there too (with a
read-count and the list of who has read it).

## Check it's alive
Open `https://kshuadjcflwlidupnqly.supabase.co/functions/v1/data-api/health`
→ you should see `"ok": true` and the serial books (all zero).

## Updating later
Edit `supabase/functions/data-api/index.ts`, then re-paste it in the
dashboard editor and hit Deploy. That's the whole update process.
