# Comm-Log Send Reconciliation — Take-Home Submission

See [`RECONCILIATION.md`](./RECONCILIATION.md) for the full reconciliation
bridge, the "surprised me" paragraph, and an explanation of the approach.

- `RECONCILIATION.md` — bridge table + write-up
- `query.sql` — the final SQL that computes `target_base = 22` directly
  against `data/comm_log.db`
- `data/` — copy of the raw data (SQLite + CSVs) for reproducibility

## Run it

```bash
sqlite3 data/comm_log.db < query.sql
```
