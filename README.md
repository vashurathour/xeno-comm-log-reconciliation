# Communication Log Reconciliation

SQL-based reconciliation of communication logs to determine the correct Finance `target_base` for a merchant's Diwali campaigns.

## Overview

This project investigates a discrepancy between a naive communication count and the `target_base` reported by Finance.

For Merchant `501` and the relevant October 2026 Diwali campaigns:

* Initial count: **25**
* Finance target: **22**
* Final reconciled count: **22**

The analysis identifies the business rules responsible for the difference and implements them in SQL.

## Business Problem

Communication logs contain multiple campaign types, campaign retries, delivery statuses, and campaign approval states.

A simple customer-level distinct count is insufficient because:

* Unapproved campaigns should not contribute to the Finance count.
* Retry campaigns represent the same underlying communication and should be deduplicated.
* Multiple sends from a standalone campaign can represent legitimate separate communication events.

The objective is therefore to build a reproducible SQL reconciliation rather than simply match the expected number.

## Objective

Determine the correct Finance `target_base` by:

1. Filtering to the relevant merchant and campaign period.
2. Applying campaign approval/finalization rules.
3. Selecting qualifying delivered communications.
4. Resolving campaign retry lineage using `parent_id`.
5. Deduplicating customers within retry chains.
6. Preserving legitimate repeated sends from standalone campaigns.
7. Reconciling the result to Finance's reported `target_base`.

## Key Result

| Metric                                     |  Count |
| ------------------------------------------ | -----: |
| Initial naive count                        |     25 |
| Excluded due to campaign approval status   |      4 |
| Post-filter count                          |     21 |
| Legitimate standalone repeat send restored |      1 |
| **Final Finance target_base**              | **22** |

## Business Rules

### Campaign eligibility

Only campaigns satisfying the required merchant, campaign, processing, and finalized creation-status criteria are included.

Campaign `9004` is excluded because it remained in an approval-pending state.

### Retry handling

Campaigns can reference previous campaigns through `parent_id`.

A recursive CTE is used to identify the root campaign and group retry chains into a single logical communication lineage.

Within a retry chain:

```text
Same customer + same communication lineage
→ Count once
```

### Standalone campaign handling

Standalone campaigns (`parent_id IS NULL`) are treated differently.

Multiple delivered sends to the same customer can represent separate communication events:

```text
Standalone campaign
C20 → Send 1
C20 → Send 2

→ Count = 2
```

This prevents over-deduplication.

## Technical Approach

The SQL implementation uses Common Table Expressions (CTEs) to separate business logic into clear stages.

### 1. Campaign filtering

Identify eligible campaigns based on merchant, campaign, processing, and creation status.

### 2. Campaign lineage

A recursive CTE follows `parent_id` relationships to determine the root campaign for retry chains.

### 3. Qualifying communications

Filter communication logs using the required:

* Merchant
* Communication type
* Delivery status
* Reporting period

### 4. Context-aware aggregation

The final aggregation applies different counting rules depending on whether the communication belongs to a retry chain or a standalone campaign.

Conceptually:

```sql
CASE
    WHEN campaign_lineage_contains_retries
        THEN COUNT(DISTINCT customer_id)
    ELSE
        COUNT(*)
END
```

This produces the final:

```text
target_base = 22
```

## Data Flow

```text
Communication Logs
        │
        ▼
Campaign Eligibility
        │
        ▼
Delivered Communications
        │
        ▼
Campaign Lineage
        │
        ├───────────────┐
        ▼               ▼
   Retry Chain      Standalone
        │               │
 DISTINCT Customer   Count Sends
        │               │
        └───────┬───────┘
                ▼
        Finance target_base
                │
                ▼
               22
```

## Repository Structure

```text
xeno-comm-log-reconciliation/
│
├── data/
│   ├── comm_log.db
│   └── source CSV files
│
├── query.sql
├── RECONCILIATION.md
└── README.md
```

### File Description

| File                | Description                                        |
| ------------------- | -------------------------------------------------- |
| `query.sql`         | Final SQL reconciliation logic                     |
| `RECONCILIATION.md` | Detailed investigation and reconciliation analysis |
| `data/comm_log.db`  | SQLite database                                    |
| `data/`             | Source datasets                                    |

## Running the Analysis

### Requirements

* SQLite 3+
* Git

### Clone

```bash
git clone https://github.com/vashurathour/xeno-comm-log-reconciliation.git
cd xeno-comm-log-reconciliation
```

### Run

```bash
sqlite3 data/comm_log.db < query.sql
```

Expected result:

```text
22
```

## Validation

The result is validated against Finance's reported `target_base`:

```text
SQL result     = 22
Finance target = 22
Variance       = 0
```

The target is not hard-coded into the query. The result is derived from the underlying campaign and communication data using the identified business rules.

## Key Analytical Insight

The primary challenge was not the aggregation itself but defining what constitutes a **unique communication event**.

A simple:

```sql
COUNT(DISTINCT customer_id)
```

can incorrectly merge legitimate repeated communications, while:

```sql
COUNT(*)
```

can incorrectly count retries as separate events.

The correct solution requires **campaign lineage + customer-level deduplication + campaign context**.

## Skills Demonstrated

* SQL
* SQLite
* Recursive CTEs
* Data reconciliation
* Data validation
* Relational data analysis
* Business-rule translation
* Deduplication logic
* Campaign lineage analysis

[GitHub](https://github.com/vashurathour)
