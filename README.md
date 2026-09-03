# LipaHaraka

**A smart invoice-to-cash platform for Kenyan SMEs.**

LipaHaraka helps small and medium-sized businesses in Kenya get paid
faster. It combines invoicing, automated payment collections, and
M-Pesa-integrated invoice-backed cash advances into a single platform
— closing the gap between issuing an invoice and actually holding the
cash it represents.

Kenyan SMEs routinely wait 30–90+ days to be paid by corporate and
government clients, while generating close to 40% of the country's
GDP and remaining largely excluded from conventional bank credit.
LipaHaraka addresses this by letting SMEs access the cash tied up in
a verified, outstanding invoice before the buyer has actually paid —
structured so that financing risk sits with a licensed lending
partner, not with the platform itself.

## Features

- **Phone-based authentication** — registration and login via phone
  number and OTP (SMS), with bearer-token authenticated sessions.
- **Business profiles** — SMEs register a business (name, KRA PIN,
  sector, M-Pesa till/paybill) tied to their verified identity.
- **KYC document upload** — national ID, certificate of registration,
  KRA PIN certificate, and M-Pesa statements, stored in S3-compatible
  object storage behind private, time-limited download links.
- **Admin review** — platform staff review and approve/reject KYC
  documents; a business's overall verification status updates
  automatically as its documents are reviewed.
- **Invoicing** — SMEs create invoices with line items, tax, and due
  dates; server-computed totals (never trusted from the client);
  full lifecycle (draft → sent → paid, or cancelled).
- **Automated reminders** — sending an invoice schedules a fixed,
  escalating sequence of payment reminders (before due, on due date,
  then increasingly firm as it goes overdue), delivered via SMS in
  the background and logged per-invoice for audit purposes.
- *(In progress)* M-Pesa payment integration and invoice-backed
  financing — see [Roadmap](#roadmap).

## Tech stack

| Layer | Technology |
|---|---|
| Backend | [Elixir](https://elixir-lang.org/) + [Phoenix](https://www.phoenixframework.org/) (API-only) |
| Database | PostgreSQL via [Ecto](https://hexdocs.pm/ecto/) |
| Authentication | Phone + OTP, [Phoenix.Token](https://hexdocs.pm/phoenix/Phoenix.Token.html) bearer sessions, [bcrypt](https://hexdocs.pm/bcrypt_elixir/) password hashing |
| SMS | [Africa's Talking](https://africastalking.com/) API |
| Background jobs | [Oban](https://hexdocs.pm/oban/) (Postgres-backed) |
| Object storage | S3-compatible via [ExAws](https://hexdocs.pm/ex_aws/) (AWS S3, DigitalOcean Spaces, MinIO, etc.) |
| Payments *(planned)* | M-Pesa Daraja API |

Elixir/Phoenix was chosen specifically for this domain: the platform's
heaviest workloads — fanning out reminder notifications, handling
bursts of payment callbacks, reconciling concurrent transactions — are
highly concurrent and I/O-bound, which is exactly what the BEAM VM is
built for. OTP's supervision trees also mean a single failed webhook
or SMS send is isolated and retried automatically, rather than
affecting other in-flight financial transactions.

## API overview

All endpoints are prefixed `/api`. Authenticated endpoints require an
`Authorization: Bearer <token>` header, obtained from `/auth/login` or
`/auth/verify_otp`.

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/health` | — | Liveness check |
| POST | `/auth/register` | — | Register with phone + password |
| POST | `/auth/verify_otp` | — | Verify phone via OTP, returns a token |
| POST | `/auth/resend_otp` | — | Request a fresh OTP |
| POST | `/auth/login` | — | Log in, returns a token |
| GET | `/me` | User | Current authenticated user |
| POST | `/businesses` | User | Register a business |
| GET | `/businesses/me` | User | Fetch your business |
| PATCH | `/businesses/me` | User | Update your business |
| POST | `/businesses/me/kyc_documents` | User | Upload a KYC document (multipart) |
| GET | `/businesses/me/kyc_documents` | User | List your uploaded documents |
| POST | `/invoices` | User | Create a draft invoice |
| GET | `/invoices` | User | List your invoices |
| GET | `/invoices/:id` | User | Fetch one invoice |
| PATCH | `/invoices/:id` | User | Update a draft invoice |
| POST | `/invoices/:id/send` | User | Mark an invoice as sent |
| POST | `/invoices/:id/mark_paid` | User | Mark a sent invoice as paid |
| POST | `/invoices/:id/cancel` | User | Cancel a draft or sent invoice |
| GET | `/invoices/:invoice_id/reminders` | User | Reminder history for an invoice |
| GET | `/admin/kyc_documents/pending` | Admin | Review queue |
| PATCH | `/admin/kyc_documents/:id` | Admin | Approve/reject a document |

## Getting started

### Prerequisites

- Elixir 1.14+ / Erlang OTP 25+
- PostgreSQL
- (Optional) An Africa's Talking sandbox account, for real SMS —
  otherwise OTPs are logged to the console in development.
- (Optional) S3-compatible storage credentials — otherwise KYC uploads
  are written to local disk in development.

### Setup

```bash
git clone <this-repo-url>
cd lipaharaka
mix deps.get
mix ecto.setup      # creates the database and runs migrations
mix phx.server
```

The API is now running at `http://localhost:4000`.

### Configuration

Development defaults to safe local adapters (console-logged OTPs,
local-disk file storage) so the app runs out of the box with no
external accounts. To use real integrations, see the commented-out
config blocks in `config/dev.exs`. Production (`config/runtime.exs`)
requires the following environment variables:

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Phoenix session/token signing (generate via `mix phx.gen.secret`) |
| `PHX_HOST` | Public hostname |
| `AFRICASTALKING_USERNAME` / `AFRICASTALKING_API_KEY` | SMS |
| `S3_KYC_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` | KYC document storage |

### Creating an admin user

There is no self-service admin signup, by design. Promote an existing,
verified user via `iex -S mix`:

```elixir
alias Lipaharaka.Accounts
user = Accounts.get_user_by_phone("+254700000000")
Accounts.promote_to_admin(user)
```

### Running tests

```bash
mix test
```

Tests use isolated adapters (an in-memory SMS recorder, local-disk
storage under a separate test directory) so the full suite runs with
no external services or credentials required.

## Architecture

The backend follows a bounded-context structure under `lib/lipaharaka/`:

- **`Accounts`** — users, phone verification, authentication
- **`Businesses`** — business profiles and KYC documents
- **`Invoicing`** — invoices, line items, and status lifecycle; all
  monetary values use `Decimal`, never floats, and totals are always
  computed server-side from submitted line items
- **`Reminders`** — schedules and delivers escalating payment
  reminders via Oban; each reminder re-checks the invoice's live
  status at send time, so a paid or cancelled invoice's remaining
  reminders are silently no-ops rather than needing explicit
  cancellation
- **`Admin`** — cross-business operations for platform staff (KYC
  review); the one deliberate exception to the rule every other
  context follows of never fetching a record by a raw client-supplied
  ID — see its moduledoc for why that boundary matters
- **`SMS`** / **`Storage`** — adapter-pattern integrations (console/local
  adapters for development, real Africa's Talking/S3 adapters for
  production), so business logic never talks to a third-party API
  directly

Controllers stay thin and call into these contexts; contexts own all
business rules and database access.

## Roadmap

- [x] Phone/OTP authentication with bearer tokens
- [x] Business profile registration
- [x] KYC document upload (S3-compatible storage)
- [x] Admin KYC review
- [x] Invoicing (create, send, track lifecycle)
- [x] Automated payment reminders
- [ ] M-Pesa payment integration (STK Push, C2B, B2C)
- [ ] Risk scoring and invoice-backed financing
- [ ] Partner lender integration

## License

TBD.
