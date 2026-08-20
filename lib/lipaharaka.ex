defmodule Lipaharaka do
  @moduledoc """
  Lipaharaka keeps the boundary contexts that make up the business domain.

  This module intentionally has no functions yet — it exists as the
  root of the application's context tree. As we build together, each
  bounded context (Accounts, Invoicing, Collections, Financing, ...)
  will live under `lib/lipaharaka/<context_name>/` with its own public
  API module here, e.g. `Lipaharaka.Invoicing`.

  Step 1 note: nothing lives here yet. This is intentional — we will
  add the first real context (Accounts, for user + business + KYC)
  together in the next step.
  """
end
