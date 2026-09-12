-- target_base for merchant 501, Diwali campaigns, October 2026
WITH RECURSIVE finalized AS (
  -- only campaigns whose creation workflow has cleared AND whose sends have processed
  SELECT * FROM campaign
  WHERE merchant_id = 501
    AND name LIKE '%Diwali%'
    AND creation_status IN ('approved', 'aborted', 'resumed', 'stopped')  -- excludes approval_awaiting
    AND processing_status = 'processed'
),
lineage(id, root_id) AS (
  -- walk parent_id chains to find the root "underlying communication" for every campaign
  SELECT id, id FROM finalized WHERE parent_id IS NULL
  UNION ALL
  SELECT f.id, l.root_id
  FROM finalized f
  JOIN lineage l ON f.parent_id = l.id
),
qualifying_sends AS (
  SELECT cl.customer_id, l.root_id
  FROM communication_log cl
  JOIN lineage l ON cl.communication_id = l.id
  WHERE cl.merchant_id = 501
    AND cl.communication_type = '2'
    AND cl.delivery_status = 900             -- only delivered sends count as "reached"
    AND strftime('%Y-%m', cl.sent_time) = '2026-10'
),
per_root AS (
  SELECT root_id, COUNT(*) AS n_campaigns
  FROM lineage
  GROUP BY root_id
)
SELECT SUM(
  CASE WHEN pr.n_campaigns > 1
    -- part of a retry chain: dedupe by customer (a customer retried 3x still counts once)
    THEN (SELECT COUNT(DISTINCT qs.customer_id) FROM qualifying_sends qs WHERE qs.root_id = pr.root_id)
    -- standalone campaign: every send is its own event, even a repeat customer
    ELSE (SELECT COUNT(*) FROM qualifying_sends qs WHERE qs.root_id = pr.root_id)
  END
) AS target_base
FROM per_root pr;
