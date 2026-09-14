# Communication Log Reconciliation

SQL-based reconciliation of campaign communication logs to determine the Finance-reported `target_base` for Merchant 501's Diwali campaigns.

## Overview

This project analyzes communication and campaign data to reconcile a discrepancy between the raw communication count and Finance's reported target base.

The initial analysis produced a count of **25**, while the Finance target was **22**.

The objective was to identify the underlying business rules and implement a reproducible SQL solution that correctly handles campaign eligibility, retries, and repeated customer communications.

**Final reconciled target base: `22`**

---

## Problem

A simple count of communication records or distinct customers does not correctly represent the business definition of a communication event.

The dataset contains:

* Campaign lifecycle states
* Processed and delivered communication logs
* Retry campaigns linked through `parent_id`
* Multiple communications to the same customer
* Campaigns that should be excluded from reporting

The reconciliation therefore requires distinguishing between:

* Invalid/ineligible campaigns
* Retry communications
* Legitimate repeated sends

---

## Solution

The reconciliation is implemented using SQL and follows four main stages:

### 1. Campaign eligibility

Filter campaigns using the required merchant, campaign, processing, and lifecycle-status criteria.

Campaigns that have not reached the required finalized state are excluded from the reporting population.

### 2. Communication filtering

Select qualifying communication records based on:

* Reporting period
* Communication type
* Delivery status
* Eligible campaigns

### 3. Campaign lineage

Use a **recursive CTE** to traverse `parent_id` relationships and identify the root campaign of retry chains.

This allows multiple retry campaigns to be treated as one underlying communication lineage.

### 4. Context-aware aggregation

Apply different counting logic based on campaign lineage:

| Scenario            | Counting logic                       |
| ------------------- | ------------------------------------ |
| Retry chain         | `COUNT(DISTINCT customer_id)`        |
| Standalone campaign | Count each qualifying delivered send |

This prevents both over-counting retries and under-counting legitimate repeated communications.

---

## Technical Approach

```text
Campaign Data + Communication Logs
                │
                ▼
        Campaign Eligibility
                │
                ▼
       Qualifying Communications
                │
                ▼
        Campaign Lineage (CTE)
                │
        ┌───────┴───────┐
        ▼               ▼
   Retry Chains      Standalone
        │               │
        ▼               ▼
 Distinct Customers   Count Sends
        │               │
        └───────┬───────┘
                ▼
        Reconciled Target Base
                │
                ▼
               22
```

### Key SQL techniques

* Common Table Expressions (CTEs)
* Recursive CTEs
* Conditional aggregation
* `COUNT(DISTINCT ...)`
* Self-referential campaign hierarchies
* Date filtering
* Business-rule-based filtering
* Data reconciliation

---

## Results

| Metric                              |  Value |
| ----------------------------------- | -----: |
| Initial count                       |     25 |
| Excluded ineligible communications  |      4 |
| Post-filter count                   |     21 |
| Legitimate standalone communication |     +1 |
| **Final target base**               | **22** |

### Validation

```text
SQL result      = 22
Finance target  = 22
Variance        = 0
```

The final value is derived from the underlying data and business rules rather than hard-coded into the query.

---

## Why `COUNT(DISTINCT customer_id)` Alone Is Insufficient

Consider two different scenarios.

### Retry

```text
Campaign A
   ↓
Retry B
   ↓
Retry C

Customer C20 → 3 delivered sends
```

These represent the same underlying communication and should be counted once.

### Standalone campaign

```text
Campaign A

Customer C20 → Send 1
Customer C20 → Send 2
```

These can represent two legitimate communication events and should therefore be counted separately.

The reconciliation logic uses campaign lineage to distinguish these cases.

---

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

| File                | Description                                       |
| ------------------- | ------------------------------------------------- |
| `query.sql`         | Final reconciliation query                        |
| `RECONCILIATION.md` | Detailed investigation and business-rule analysis |
| `data/`             | Source data and SQLite database                   |

---

## Reproducibility

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

---

## Key Takeaway

The primary challenge was not calculating a count, but defining **what constitutes a unique communication event**.

The final solution combines:

**Campaign eligibility + campaign lineage + customer-level deduplication + standalone-send handling**

to produce a reproducible Finance-aligned `target_base` of **22**.

---

## Skills

**SQL · SQLite · Recursive CTEs · Data Reconciliation · Data Validation · Deduplication · Hierarchical Data · Business Rule Translation**

---


[GitHub](https://github.com/vashurathour) .
