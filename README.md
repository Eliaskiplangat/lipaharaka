# LipaHaraka Backend — Step 1: Bare Phoenix Skeleton

This is the first step of building the LipaHaraka backend, step by step. It is
deliberately minimal: no auth, no invoicing, no M-Pesa — just a Phoenix API
app that boots, connects to Postgres, and answers one health-check request.

## What's in this step

- A Phoenix **API-only** app (no HTML/LiveView) — matches our architecture,
  where React is the separate frontend and Phoenix is purely a JSON API.
- `Lipaharaka.Repo` wired up (Ecto + Postgres), but **no schemas or
  migrations yet** — that's Step 2, when we build the Accounts context
  (users, businesses, KYC).
- One real route: `GET /api/health`, returning `{"status": "ok", ...}`.
- A test for that route, using the standard Phoenix `ConnCase`/`DataCase`
  pattern so future tests slot in the same way.

## What's deliberately NOT here yet

- No Oban (background jobs) — comes when we build the reminder engine.
- No bcrypt/auth — comes with the Accounts context.
- No M-Pesa integration — comes once payments/invoicing exist.
- No `mix.lock` — generated fresh by you on first `mix deps.get`, since this
  project was hand-assembled in a sandboxed environment that couldn't reach
  hex.pm (Elixir's package registry). Your machine should reach it fine.

## Prerequisites (on your own machine)

- Elixir 1.14+ and Erlang/OTP 25+ (check with `elixir --version`)
- PostgreSQL running locally (default config below assumes user/pass
  `postgres`/`postgres` on `localhost` — adjust `config/dev.exs` if yours
  differs)

## Running it

```bash
cd lipaharaka
mix deps.get          # fetches Phoenix, Ecto, Postgrex etc. from hex.pm
mix ecto.create        # creates the lipaharaka_dev database (empty for now)
mix phx.server          # boots the app on http://localhost:4000
```

Then in another terminal:

```bash
curl http://localhost:4000/api/health
```

You should see:

```json
{"status":"ok","service":"lipaharaka","version":"0.1.0"}
```

Run the test suite:

```bash
mix test
```

## Next step (Step 2)

Once you've confirmed this boots on your machine, the next step is the
**Accounts context**: the `User` and `Business` Ecto schemas, a migration
for both tables, and the registration/OTP-verification endpoints (FR-1.1
and FR-1.2 from the FSD). We'll add that together the same way — one small,
runnable piece at a time.

---

## Step 2: Accounts (User registration, OTP verification, login)

**New in this step:**

- `users` table + migration (phone number, password hash, OTP fields).
- `Lipaharaka.Accounts` context — `register_user/1`, `verify_otp/2`,
  `authenticate/2`, `issue_and_send_otp/1`.
- An SMS abstraction (`Lipaharaka.SMS`) with three adapters:
  - `Lipaharaka.SMS.Console` — **default in dev**. Logs the OTP to your
    terminal instead of sending a real SMS, so you can develop and test
    without an Africa's Talking account.
  - `Lipaharaka.SMS.AfricasTalking` — the real integration, fully
    implemented, used automatically in production. You can also switch
    dev to use it (see below) once you have sandbox credentials.
  - `Lipaharaka.SMS.Test` — used automatically in `test`, records sent
    messages in memory so tests can read the OTP back out.
- Four endpoints: `POST /api/auth/register`, `/verify_otp`, `/resend_otp`,
  `/login`.

### New dependencies

Two new deps were added to `mix.exs`: `bcrypt_elixir` (password hashing)
and `req` (HTTP client for the Africa's Talking API). Run:

```bash
mix deps.get
mix ecto.migrate
```

### Trying it out locally (Console adapter — no SMS account needed)

```bash
# 1. Register
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "0712345678", "password": "supersecret"}'
```

Check your `mix phx.server` terminal output — you'll see a line like:

```
[info] [SMS/Console] To: +254712345678 — Your LipaHaraka verification code is 483920. It expires in 5 minutes.
```

```bash
# 2. Verify using the code from the console log
curl -X POST http://localhost:4000/api/auth/verify_otp \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "0712345678", "otp": "483920"}'

# 3. Log in
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "0712345678", "password": "supersecret"}'
```

### Switching dev to real Africa's Talking SMS

1. Create a sandbox account at https://account.africastalking.com (free).
2. Grab your sandbox **username** (it's literally `sandbox`) and **API key**
   from the dashboard.
3. In `config/dev.exs`, change:
   ```elixir
   config :lipaharaka, :sms_adapter, Lipaharaka.SMS.Console
   ```
   to:
   ```elixir
   config :lipaharaka, :sms_adapter, Lipaharaka.SMS.AfricasTalking

   config :lipaharaka, :africas_talking,
     username: "sandbox",
     api_key: "your-sandbox-api-key",
     base_url: "https://api.sandbox.africastalking.com"
   ```
4. Sandbox mode requires you to register a test phone number in the AT
   dashboard's simulator before it will actually deliver — real delivery
   only happens on a live (non-sandbox) account.

In **production**, `config/runtime.exs` already requires
`AFRICASTALKING_USERNAME` and `AFRICASTALKING_API_KEY` environment
variables and wires up the real adapter automatically — no code changes
needed when you deploy.

### Running the tests

```bash
mix test
```

This covers both the `Accounts` context directly
(`test/lipaharaka/accounts_test.exs`) and the HTTP endpoints
(`test/lipaharaka_web/controllers/auth_controller_test.exs`), using the
`Test` SMS adapter so no real messages are sent during testing.

### What's deliberately NOT here yet

- No `Business` schema/endpoint — that's Step 3, as agreed (register user
  first, add business profile as a separate step).
- No session/token issuance on login — right now `/login` just confirms
  the credentials are correct and returns the user. We'll decide between
  a signed cookie session and a bearer token (for the React/mobile
  clients) when we build the endpoints that actually need to be
  authenticated.
- No rate limiting at the HTTP layer (e.g. capping registration attempts
  per IP) — only the per-user OTP attempt counter exists so far.

### Next step (Step 3)

The `Business` context: SME business profile (name, KRA PIN, sector,
M-Pesa till/paybill) and KYC document upload, linked to the `User` we
just built (FR-1.2–1.4 from the FSD).

---

## Step 3: Bearer token authentication

**New in this step:**

- `LipaharakaWeb.Auth.Token` — thin wrapper around `Phoenix.Token`
  (sign/verify), no new dependency needed.
- `LipaharakaWeb.Plugs.RequireAuth` — plug that reads
  `Authorization: Bearer <token>`, verifies it, and assigns
  `conn.assigns.current_user`, or halts with a 401.
- A new `:authenticated` router pipeline (composed with `:api`).
- `GET /api/me` — the first protected route, returns whoever the
  token belongs to. Exists both as proof the plug works and because
  it's genuinely useful later (frontend "am I still logged in" check).
- `/verify_otp` and `/login` now both return a `token` field in their
  JSON response, in addition to `user`.

### New files

```
lib/lipaharaka_web/auth/token.ex
lib/lipaharaka_web/plugs/require_auth.ex
test/lipaharaka_web/auth/token_test.exs
```

### Modified files

```
lib/lipaharaka_web/router.ex               (added :authenticated pipeline, GET /me)
lib/lipaharaka_web/controllers/auth_controller.ex   (token issuance, me/2 action)
lib/lipaharaka_web/controllers/auth_json.ex         (token field, me/1 render)
test/lipaharaka_web/controllers/auth_controller_test.exs  (token assertions, /me tests)
```

No new deps, no new migration — `mix deps.get` isn't needed for this step.

### Trying it out

```bash
# 1. Verify OTP (or log in) — response now includes "token"
curl -X POST http://localhost:4000/api/auth/verify_otp \
  -H "Content-Type: application/json" \
  -d '{"phone_number": "0712345678", "otp": "483920"}'
# => {"user": {...}, "token": "SFMyNTY....", "message": "Phone number verified."}

# 2. Use the token on a protected route
curl http://localhost:4000/api/me \
  -H "Authorization: Bearer SFMyNTY...."
# => {"user": {"id": "...", "phone_number": "+254712345678", "phone_verified": true}}

# 3. Without a token — 401
curl http://localhost:4000/api/me
# => {"errors": {"detail": "missing Authorization header"}}
```

### What's deliberately NOT here yet

- **No revocation.** Tokens are stateless (signed, not stored), so
  there's currently no way to invalidate a single token early — e.g.
  "log out this device" or "log out everywhere" isn't possible short
  of rotating `secret_key_base` (which would log out *everyone*).
  Worth revisiting if/when we have a real requirement for it — the
  usual fix is moving to a stored-session-id + DB lookup model instead
  of pure stateless tokens.
- **No refresh token.** Tokens are valid for 30 days flat, then the
  user has to log in again. Fine for now; a refresh-token flow is a
  reasonable future addition if 30 days proves too short.
- **No role/permission checks yet.** `RequireAuth` only proves *who*
  you are, not what you're allowed to do. That distinction matters
  once Admin endpoints exist (Section 4.2, FR-7.x in the FSD).

### Next step (Step 4)

The `Business` context: SME business profile (name, KRA PIN, sector,
M-Pesa till/paybill) and KYC document upload, now correctly scoped to
`conn.assigns.current_user` via the `:authenticated` pipeline instead
of a client-supplied `user_id`.

---

## Step 4: Business context (SME profile)

**New in this step:**

- `businesses` table + migration — one business per authenticated user
  (enforced with a unique index on `user_id`), FK'd to `users` with
  `on_delete: :delete_all`.
- `Lipaharaka.Businesses` context — `create_business/2`,
  `get_business_for_user/1`, `update_business/2`. Every function takes
  the authenticated user explicitly and scopes to it; there is no
  "fetch any business by id" function in this context on purpose (see
  the moduledoc in `businesses.ex` for why).
- Three endpoints, all behind the `:authenticated` pipeline from
  Step 3 — a request with no valid bearer token never reaches these:
  - `POST /api/businesses` — create (only `business_name` required)
  - `GET /api/businesses/me`
  - `PATCH /api/businesses/me`
- `kyc_status` field (`pending` / `approved` / `rejected`) exists on
  the business now, defaulting to `pending`, ready for the Admin
  review flow later — but there's no way to change it yet except
  directly in the database.

### New files

```
priv/repo/migrations/20260819090000_create_businesses.exs
lib/lipaharaka/businesses/business.ex
lib/lipaharaka/businesses.ex
lib/lipaharaka_web/controllers/business_controller.ex
lib/lipaharaka_web/controllers/business_json.ex
test/lipaharaka/businesses_test.exs
test/lipaharaka_web/controllers/business_controller_test.exs
```

### Modified files

```
lib/lipaharaka_web/router.ex   (added /api/businesses routes)
```

No new dependencies. Run the migration:

```bash
mix ecto.migrate
```

### Trying it out

```bash
# 1. Get a token the usual way (register -> verify_otp), then:
TOKEN="paste-your-token-here"

# 2. Create a business
curl -X POST http://localhost:4000/api/businesses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"business_name": "Jaza Traders Ltd", "kra_pin": "A123456789Z", "sector": "Retail"}'

# 3. Fetch it
curl http://localhost:4000/api/businesses/me -H "Authorization: Bearer $TOKEN"

# 4. Update it
curl -X PATCH http://localhost:4000/api/businesses/me \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"sector": "Wholesale"}'
```

### What's deliberately NOT here yet

- **No KYC document upload.** That's Step 5 — file storage (local disk
  vs. S3-compatible) is a different kind of problem than everything
  we've built so far and deserves its own step.
- **No way to change `kyc_status`.** It exists and defaults to
  `pending`, but nothing in the API can move it to `approved` /
  `rejected` yet — that's the Admin review flow, which needs an Admin
  role/permission concept we haven't built (see FR-1.4, FR-7.4 in the
  FSD). `RequireAuth` currently proves *who* you are, not what you're
  allowed to do.
- **One business per user, hard-enforced.** If a future requirement
  needs multiple businesses per user (e.g. an accountant managing
  several SME clients), this constraint — the unique index plus
  `create_business/2`'s `:already_exists` check — is exactly what
  would need to change.

### Next step (Step 5)

KYC document upload: SME uploads ID, certificate of registration, and
KRA PIN certificate (FR-1.3), stored and linked to their business,
followed by the Admin review flow that can actually set `kyc_status`.

---

## Step 5: KYC document upload (S3-compatible storage)

**New in this step:**

- `Lipaharaka.Storage` — adapter behaviour + dispatcher (same pattern
  as `Lipaharaka.SMS`), with two adapters:
  - `Lipaharaka.Storage.Local` — **default in dev/test**. Writes to
    `priv/uploads/` (or `priv/uploads_test/` in test), no S3 account
    needed to keep developing.
  - `Lipaharaka.Storage.S3` — the real integration via `ExAws`. Works
    with any S3-compatible provider (AWS S3, DigitalOcean Spaces,
    MinIO, Cloudflare R2 — just point `S3_HOST` at the right
    endpoint). **The bucket must be private.** KYC documents (national
    IDs, KRA PIN certificates) are sensitive and are never served from
    a public URL — every read goes through a presigned URL that
    expires in 15 minutes.
- `kyc_documents` table + migration, linked to `Business`. One
  document per `(business, document_type)` — re-uploading replaces
  the existing one in place and resets its status to `pending`.
- `Lipaharaka.Businesses` extended with `upload_kyc_document/3`,
  `list_kyc_documents/1`, `kyc_document_download_url/1`.
- Two endpoints, behind `:authenticated`:
  - `POST /api/businesses/me/kyc_documents` — multipart upload
    (`document_type` + `file` fields)
  - `GET /api/businesses/me/kyc_documents` — list, each with a fresh
    presigned download URL generated at request time (not stored,
    since they expire)
- Validates document type (`national_id`, `certificate_of_registration`,
  `kra_pin_certificate`, `mpesa_statement`), content type (JPEG, PNG,
  PDF only), and file size (5MB max) — all **before** touching storage.

### New dependencies

`ex_aws`, `ex_aws_s3`, `hackney`, `sweet_xml`. Run:

```bash
mix deps.get
mix ecto.migrate
```

### Trying it out (Local adapter — no S3 account needed)

```bash
TOKEN="paste-your-token-here"

# Assumes you already created a business (Step 4)
curl -X POST http://localhost:4000/api/businesses/me/kyc_documents \
  -H "Authorization: Bearer $TOKEN" \
  -F "document_type=national_id" \
  -F "file=@/path/to/some/id_photo.jpg"

curl http://localhost:4000/api/businesses/me/kyc_documents \
  -H "Authorization: Bearer $TOKEN"
```

With the Local adapter, `download_url` in the response will look like
`file:///home/you/.../priv/uploads/kyc/...` — that's expected, it's a
local filesystem path, not something a real frontend should be given.
Switch to `Lipaharaka.Storage.S3` in `config/dev.exs` (with real or
MinIO credentials) to get back real, working presigned HTTPS URLs.

### Switching dev to real S3-compatible storage

1. Get a bucket + credentials from your provider of choice (AWS S3,
   DigitalOcean Spaces, or run MinIO locally via Docker for a
   zero-cost local S3-compatible target).
2. **Make sure the bucket is private** — block all public access.
3. In `config/dev.exs`, uncomment and fill in the `:storage_adapter`,
   `:kyc_bucket`, `:ex_aws`, and `:ex_aws, :s3` blocks (already
   scaffolded there, commented out).

In **production**, `config/runtime.exs` already requires
`S3_KYC_BUCKET`, `S3_ACCESS_KEY_ID`, and `S3_SECRET_ACCESS_KEY`
environment variables and wires up the real `S3` adapter automatically.

### What's deliberately NOT here yet

- **No Admin review.** `kyc_status` exists and defaults to `pending`
  for every document, but there's still no way to move it to
  `approved`/`rejected` — that needs an Admin role/permission concept,
  which doesn't exist yet.
- **No virus/malware scanning on uploads.** Worth adding before this
  ever handles real documents in production — accepting arbitrary
  file uploads from users is a real attack surface.
- **No content-sniffing validation.** We trust the `Content-Type` the
  client sends rather than inspecting the file's actual magic bytes.
  A client could technically claim `image/jpeg` for a non-image file
  that happens to be under 5MB. Low risk given we don't execute or
  render these files anywhere yet, but worth hardening later.

### Next step (Step 6)

The Admin role/permission concept, and the first Admin-only endpoint:
reviewing and approving/rejecting a business's KYC documents (FR-1.4).

---

## Step 6: Admin role + KYC review

**New in this step:**

- `role` column on `users` (`"sme"` / `"admin"`, defaults to `"sme"`).
  **Not settable by the client** — it's absent from
  `registration_changeset`'s cast list entirely, so even a malicious
  `{"role": "admin"}` in a registration request is silently ignored
  (see `test/lipaharaka/accounts_role_test.exs`).
- `Accounts.promote_to_admin/1` — the only way to create an admin
  right now is via `iex`, on purpose (see "Creating an admin" below).
- `LipaharakaWeb.Plugs.RequireAdmin` — composed after `RequireAuth` in
  a new `:admin` pipeline. Distinguishes 401 (not logged in) from 403
  (logged in, not an admin) — genuinely different situations.
- `Lipaharaka.Admin` context — the one deliberate exception to "never
  fetch by raw ID" that the rest of the codebase follows (see its
  moduledoc for why that's safe here specifically).
- Two endpoints, behind `:admin`:
  - `GET /api/admin/kyc_documents/pending` — FIFO review queue, each
    document preloaded with its business and the owner's phone number
  - `PATCH /api/admin/kyc_documents/:id` — `{"decision": "approved" |
    "rejected", "review_note": "..."}` (note optional)
- Reviewing a document **automatically recomputes** the business's
  overall `kyc_status` (`Businesses.refresh_kyc_status/1`): rejected
  if any document is rejected, approved only once every document is
  approved, pending otherwise.

### New files

```
priv/repo/migrations/20260821080000_add_role_to_users.exs
lib/lipaharaka_web/plugs/require_admin.ex
lib/lipaharaka/admin.ex
lib/lipaharaka_web/controllers/admin/kyc_document_controller.ex
lib/lipaharaka_web/controllers/admin/kyc_document_json.ex
test/lipaharaka_web/plugs/require_admin_test.exs
test/lipaharaka/admin_test.exs
test/lipaharaka_web/controllers/admin/kyc_document_controller_test.exs
test/lipaharaka/accounts_role_test.exs
```

### Modified files

```
lib/lipaharaka/accounts/user.ex        (role field)
lib/lipaharaka/accounts.ex             (promote_to_admin/1)
lib/lipaharaka/businesses/kyc_document.ex  (review_changeset/3)
lib/lipaharaka/businesses.ex           (refresh_kyc_status/1)
lib/lipaharaka_web/router.ex           (:admin pipeline, /api/admin routes)
```

No new dependencies. Run the migration:

```bash
mix ecto.migrate
```

### Creating an admin (no API endpoint — deliberately)

```bash
iex -S mix
```
```elixir
alias Lipaharaka.Accounts
user = Accounts.get_user_by_phone("+254700000000")  # must already be registered + verified
{:ok, admin} = Accounts.promote_to_admin(user)
```

### Trying it out

```bash
ADMIN_TOKEN="token-for-your-promoted-admin-user"

curl http://localhost:4000/api/admin/kyc_documents/pending \
  -H "Authorization: Bearer $ADMIN_TOKEN"

curl -X PATCH http://localhost:4000/api/admin/kyc_documents/DOCUMENT_ID \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"decision": "approved", "review_note": "Clear ID photo, matches business name"}'
```

Trying the same requests with a non-admin's token should return 403;
with no token at all, 401.

### What's deliberately NOT here yet

- **No admin signup/invite flow.** Every admin is created by direct
  DB/iex intervention. Fine for a small team running this themselves;
  would need a real invite/audit flow before handing admin access to
  a larger operations team.
- **No audit log of review decisions.** We record `reviewed_at` and
  `review_note` on the document itself, but not a durable, append-only
  log of "admin X did Y at time Z" — worth adding before this is
  handling real regulatory-sensitive decisions (see FSD Section 15,
  audit logging as a compliance requirement).
- **No way to un-approve/re-open a review.** Once a document is
  `approved` or `rejected`, the only way back to `pending` is the SME
  re-uploading a new file for that document type.

### Next step (Step 7)

Core invoicing (FR-2.x): SMEs can now be verified end-to-end
(register → business → KYC → admin approval) — the next real feature
is letting an approved SME actually create and send an invoice.
