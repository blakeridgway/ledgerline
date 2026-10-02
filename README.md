# time_logix

A small Rails app for 1099 / independent contractor work: track clients, log
time, and turn the work into an invoice PDF. Two billing models are supported:

- **Hourly** — each billable time entry becomes a line item at the client's rate.
- **Monthly** — a flat retainer line per invoice period. Any hours logged in the
  period are marked as billed but are covered by the retainer, so they are never
  charged twice.

A monthly client can also carry an **expected hours** commitment (160 for a
full-time 1099 arrangement). That tracks progress against the commitment and
produces a monthly **timesheet PDF** to submit alongside the invoice — which
matters when the fee is a flat salary but the hours still have to be evidenced.
Logged hours never change the amount billed.

On the money side there is a **week grid** for logging time fast, **repeat
invoice** for re-billing a retainer in one click, **email delivery with overdue
chasing**, and an **Expenses** ledger feeding a **Profit & taxes** report with net
profit and a quarterly estimated-tax set-aside.

Each account has one sign-in and its own business details (name, address, tax ID,
payment terms, invoice prefix, payment instructions) that appear on the invoices.

## Requirements

- Ruby 4.0.5 (see `.ruby-version`)
- Rails 8.1
- SQLite (bundled, no server needed) — used for development, test and production

## Getting started

```bash
bundle install
bin/rails db:prepare   # creates, loads schema, and migrates
bin/rails db:seed      # creates your account + a little demo data
bin/rails server
```

Open <http://localhost:3000>.

The seed script creates an account and a few demo clients so the app isn't empty:

| Email                | Password      |
| -------------------- | ------------- |
| `blake@example.com`  | `password123` |

Override the credentials (and skip the demo rows) with environment variables:

```bash
SEED_EMAIL=me@example.com SEED_PASSWORD=correct-horse SEED_BUSINESS="Me LLC" bin/rails db:seed
```

Demo data is only created when the account has no clients yet, so re-running
`db:seed` is safe. There is no public sign-up page — accounts are created by the
seed script or in the Rails console:

```ruby
User.create!(email_address: "me@example.com", password: "secret")
```

## Using it

1. **Business** (top right) — fill in your details and payment instructions first;
   they are rendered onto every invoice PDF.
2. **Add client** — choose hourly or monthly billing and set the rate. For a
   retainer, also set **expected hours per month** (the form prefills it from
   your business settings) to get progress tracking and timesheets. Archived
   clients stay in the app for your records but drop out of the active list.
3. **Log time** — from the dashboard, the Time page, or a client page. The
   stopwatch on the Log time card fills in the hours field when you stop it.
   Entries can be non-billable, which keeps them out of invoices and timesheets.
   For a full week at once, **Log a week** shows one row per day with
   "fill weekdays with 8", so a full-time retainer month is a handful of
   submissions rather than twenty.
4. **New invoice** — pick a client and a period. The preview updates as you
   change either, showing exactly which entries will be billed and what the
   total comes to before you commit. Creating the invoice locks those entries
   to it. Retainer clients also see their hours progress against the commitment.
5. **Repeat an invoice** — every invoice page has **Repeat for next month**,
   which re-bills the same client for the following period (calendar month for
   retainers, same length otherwise). The invoices page also has **Draft retainer
   invoices**, which creates this month's drafts for every active retainer that
   doesn't have one yet and skips the rest.
6. **Download PDF** — the invoice page has a print-ready PDF (served inline, so
   it previews in the browser). Mark invoices as sent, paid, void, or delete them.
7. **Timesheet** — for retainer clients, open the client page (or the dashboard's
   Retainers card) and pick a month. The timesheet rolls the month's entries into
   one row per day, totals them against the commitment, and downloads as a PDF
   with a signature line. It is built from the hours *logged* in the month, so it
   stays correct even if you invoiced before the month ended.
8. **Expenses** — record what you spend, by Schedule C-ish category, optionally
   tagged to a client. Expenses are for your books only; they are never added to
   an invoice.
9. **Reports** — invoiced vs received, expenses by category, net profit, and a
   **set-aside** for estimated taxes, broken into the four US federal
   instalments with their real (uneven) periods and due dates.

### Profit and tax

Set the **tax set-aside %** under **Business** (defaults to 30). The Reports page
then shows net profit and what to hold back, both for the year and for the next
instalment. Income is recognised by invoice issue date and expenses by the date
incurred, which is the practical proxy for cash-basis books — the page says so,
and the figures are a planning aid rather than tax advice.

### Sending and chasing invoices

Invoices can be emailed straight to the client with the PDF attached — **Send to
client** on an invoice (or **Resend invoice** if it has already gone out), and
**Send reminder** once it is with them. Sending records `sent_at` and moves a
draft to *sent*.

Once an invoice is sent and its due date passes it is **overdue**: the dashboard
shows a count and a total, the invoice list gains an *Overdue* tab and a due
column with a badge, and the dashboard's open-invoice table gives you a one-click
**Remind**.

> **In development, mail is not actually sent.** `letter_opener` opens the
> message (with the attached PDF) in a browser tab so you can see exactly what
> the client would get, and the flash says so. To send for real, set
> `SMTP_ADDRESS`, `SMTP_USERNAME` and `SMTP_PASSWORD` in production.

### Retainer hours

Set the expected hours on the client (or as a default under **Business**). The
app then shows `152 / 160 hrs · 8 hrs to go` on the dashboard, the client page,
and the invoice preview, plus the effective hourly rate
(`$6,000.00/mo · $37.50/hr over 160 hrs`). The timesheet PDF is a separate
document from the invoice — one is the timesheet the client signs, the other is
the financial document.

Only **billable** hours count toward the commitment, matching what gets attached
to invoices. Non-billable hours are excluded and reported separately on the
timesheet, so nothing disappears silently.

### What happens to hours on an invoice

| Action              | Effect on time entries                                    |
| ------------------- | --------------------------------------------------------- |
| Create invoice      | Entries in the period are attached and stop being unbilled |
| Void invoice        | Entries are released and become unbilled again             |
| Delete invoice      | Entries are released and become unbilled again             |
| Mark paid           | No change — the invoice is simply locked from edits        |

A period that already has a non-void invoice for the same client cannot be
invoiced twice, which prevents accidental double billing.

Retainer hours are informational: they are attached to the invoice so they can't
be counted twice, but the invoice amount is always the flat retainer. The
timesheet is generated from the hours logged in the month, independently of
whichever invoice covered them.

### Invoice numbering

`INV-YYYYMM-001`, using the prefix from your business settings. The sequence
restarts each month and can be edited per invoice.

## How it's put together

```
app/models        User, Client, TimeEntry, Invoice, InvoiceLineItem, Expense, Session
app/models        Timesheet  — a period of hours plus the retainer commitment
app/models        TaxSummary — a year of income, expenses and estimated tax
app/services      InvoiceBuilder  — turns unbilled entries into an invoice
app/pdfs          PdfHelpers      — shared Prawn drawing helpers
app/pdfs          InvoicePdf      — Prawn rendering of the invoice
app/pdfs          TimesheetPdf    — Prawn rendering of the monthly timesheet
app/controllers   dashboard, clients, time_entries, invoices, expenses, reports, profiles (+ auth)
app/views         ERB templates; hand-written CSS, no build step
```

- **Auth** is the Rails 8 authentication generator (`has_secure_password`, a
  `Session` row per device, signed cookie). Every query is scoped through
  `Current.user`, so one account can never read another's data.
- **InvoiceBuilder** is the single place that decides what gets billed. Hourly
  clients get a line item per entry; monthly clients get one retainer line. It
  raises `InvoiceBuilder::Error` (shown as a flash message) instead of creating a
  half-formed invoice.
- **Timesheet** answers "how many hours have I logged this month, and how far
  through the commitment am I?". It drives the dashboard/client/invoice-preview
  progress displays and the timesheet PDF, so all four agree by construction. It
  counts hours by the date they were worked rather than by what an invoice swept
  up, so mid-month invoicing can't distort it.
- **TaxSummary** does the same job for the year: income by invoice date, expenses
  by date incurred, net profit, and the four IRS instalment periods and due dates
  (which are not calendar quarters, and the last of which falls in the following
  January). It backs the dashboard's profit card and the Reports page.
- **Expenses** are deliberately independent of invoicing. Tagging an expense to a
  client is reporting-only, and deleting a client untags their expenses rather
  than deleting them.
- **InvoiceMailer** attaches a freshly rendered PDF to every send, so the client
  always receives what you see. Delivery failures are caught and shown as a flash
  rather than a 500. Overdue is derived from `status` and `due_on` rather than
  stored, so it can never drift out of date.
- **InvoiceLineItem** snapshots the description, rate and amount, so a later rate
  change never rewrites an invoice you already sent.
- **InvoicePdf** / **TimesheetPdf** use Prawn with its built-in fonts. Text
  outside the WinAnsi character set (emoji, arrows, CJK) is transliterated or
  replaced so a stray character in a note can't break the PDF.
- **Time zone** — `config/application.rb` follows the machine's zone so "today"
  and month boundaries match your wall clock. Override with
  `TZ=America/New_York bin/rails server`.

## Tests

```bash
bin/rails test     # 234 tests: models, timesheets, tax summary, the invoice builder, mailers, PDFs, controllers
bin/rubocop        # styling (rubocop-rails-omakase)
```

Tests run against SQLite in parallel; fixtures in `test/fixtures` are written to
be valid records rather than placeholders.

## Notes on this setup

Kamal, Docker, and the Solid Cache/Queue/Cable trio were skipped when the app was
generated, so there are no extra services to run. For a real deployment you'd add
a production database and a web server of your choice; nothing in the app depends
on being run locally.
