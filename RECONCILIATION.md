# Comm-Log Send Reconciliation — Merchant 501, October 2026, Diwali Campaigns

## Goal
Reproduce Finance's reported `target_base = 22` from the raw `campaign` and
`communication_log` tables, and explain the gap from a naive query.

## Reconciliation Bridge

| Step | Description | Result | Reason |
|---|---|---|---|
| 0 | Naive query: `COUNT(DISTINCT customer_id)` across all campaigns named `%Diwali%` for merchant 501, Oct 2026, `communication_type = 2` — no status or delivery filters | **25** | Starting point — the most obvious query a first pass would produce |
| 1 | Excluded campaigns still `creation_status = 'approval_awaiting'` (campaign `9004`, 4 customers: C11–C14) | **21** | Its sends had already run (`processing_status = 'processed'`), but the campaign itself was never approved. The pipeline can send before approval clears, and Finance doesn't count a campaign until *both* statuses are finalized |
| 2 | Added back one duplicate send to customer `C20` under campaign `9101` (a standalone campaign — no `parent_id`, no children) — two separate, both-delivered sends 10 days apart | **22** | `COUNT(DISTINCT customer_id)` had silently collapsed this into a single customer. But a repeat customer under a *standalone* campaign is not a retry — retries only exist via `parent_id` chains. A standalone campaign's repeat send is its own qualifying event and should be counted twice |
| **final** | | **22** | Matches Finance's reported target_base |

## Why this isn't just a `DISTINCT` trick

`COUNT(DISTINCT customer_id)` after excluding unapproved campaigns happens to
land on 22 here, but it works for the wrong reason in general — it would also
silently collapse a legitimate repeat send under a standalone campaign
whenever that repeat happened to land in the same query window, and it gives
no way to tell a retry (same underlying communication) apart from a genuine
re-target (a new communication).

The query in `query.sql` instead:

1. Filters to campaigns that are actually finalized for reporting
   (`creation_status` resolved, `processing_status = 'processed'`).
2. Walks each campaign's `parent_id` chain to find the root
   "underlying communication" it belongs to.
3. For any communication that **is** a retry chain (more than one campaign in
   the lineage), counts **distinct customers reached** (`delivery_status =
   900`) — a customer retried 3x still counts once.
4. For a **standalone** communication (no retries), counts **every delivered
   send as its own event** — even a repeat customer.
5. Sums across all underlying communications.

Running it against `data/comm_log.db` returns:

| root campaign | campaigns in chain | contribution |
|---|---|---|
| 9001 (Diwali Cart Recovery, + 2 retries) | 3 | 10 |
| 9101 (Diwali Flash Sale — Standalone) | 1 | 7 |
| 9201 (Diwali Wave 2, + 1 retry) | 2 | 5 |
| **Total** | | **22** |

Campaign `9004` (a would-be retry of 9001) is excluded entirely — it never
cleared approval.

## What surprised me

Two things. First, campaign `9004` had already fully processed and delivered
four sends while still sitting in `approval_awaiting` — the send pipeline can
run completely independent of and ahead of the approval workflow, so
`processing_status = 'processed'` alone is not a safe signal that a campaign
should be reported. Second, campaign `9101` (standalone) sent to the same
customer (`C20`) twice, ten days apart. My first instinct was to treat any
repeated `customer_id` as a dedup case, but the data dictionary is explicit
that this only applies to true retries (`parent_id` chains) — a standalone
campaign's repeat send is a separate, legitimate event. Deduping it was
actually what caused my first "corrected" count to *undershoot* by 1 rather
than overshoot, which I hadn't anticipated going in.

## How to reproduce

```bash
sqlite3 data/comm_log.db < query.sql
```
