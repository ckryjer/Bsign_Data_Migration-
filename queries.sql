-- BSIGN-358 — EDA queries against dbo.signature_requests_raw
-- Captured from working session, 2026-09-09

-- ============================================================
-- Data Dictionary: column names + data types for the table
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'signature_requests_raw'
ORDER BY ORDINAL_POSITION;

-- ============================================================
-- Truncate table (used before re-running pipeline with corrected account_id param)
-- ============================================================
TRUNCATE TABLE dbo.signature_requests_raw;

-- ============================================================
-- Client breakdown: request count per domain, ranked highest to lowest
-- ============================================================
SELECT sent_from_domain, COUNT(*) AS request_count
FROM dbo.signature_requests_raw
GROUP BY sent_from_domain
ORDER BY request_count DESC;

-- ============================================================
-- Date range covered by the data (readable format)
-- ============================================================
SELECT
  FORMAT(DATEADD(SECOND, MIN(created_at), '1970-01-01'), 'MM/dd/yyyy') AS earliest,
  FORMAT(DATEADD(SECOND, MAX(created_at), '1970-01-01'), 'MM/dd/yyyy') AS latest
FROM dbo.signature_requests_raw;

-- ============================================================
-- Status breakdown: complete / declined / errored counts
-- ============================================================
SELECT is_complete, is_declined, has_error, COUNT(*) AS cnt
FROM dbo.signature_requests_raw
GROUP BY is_complete, is_declined, has_error;

-- ============================================================
-- Null check on key columns (sent_from_domain, client_id)
-- ============================================================
SELECT
  SUM(CASE WHEN sent_from_domain IS NULL THEN 1 ELSE 0 END) AS null_domain,
  SUM(CASE WHEN client_id IS NULL THEN 1 ELSE 0 END) AS null_client_id
FROM dbo.signature_requests_raw;

-- ============================================================
-- Which column is the real client-grouping key? Compare distinct counts
-- ============================================================
SELECT COUNT(DISTINCT client_id) AS distinct_client_ids,
       COUNT(DISTINCT sent_from_domain) AS distinct_domains
FROM dbo.signature_requests_raw;

-- ============================================================
-- Client breakdown + completion/decline rate combined
-- ============================================================
SELECT sent_from_domain,
       COUNT(*) AS total_requests,
       SUM(CASE WHEN is_complete = 1 THEN 1 ELSE 0 END) AS completed,
       SUM(CASE WHEN is_declined = 1 THEN 1 ELSE 0 END) AS declined
FROM dbo.signature_requests_raw
GROUP BY sent_from_domain
ORDER BY total_requests DESC;

-- ============================================================
-- Volume over time (monthly trend)
-- ============================================================
SELECT FORMAT(DATEADD(SECOND, created_at, '1970-01-01'), 'yyyy-MM') AS month,
       COUNT(*) AS requests
FROM dbo.signature_requests_raw
GROUP BY FORMAT(DATEADD(SECOND, created_at, '1970-01-01'), 'yyyy-MM')
ORDER BY month;

-- ============================================================
-- Duplicate check on requester_email_address (who's actually sending)
-- ============================================================
SELECT requester_email_address, COUNT(*) AS cnt
FROM dbo.signature_requests_raw
GROUP BY requester_email_address
ORDER BY cnt DESC;

-- ============================================================
-- Dedup check: total rows vs. distinct signature_request_id
-- ============================================================
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT signature_request_id) AS distinct_ids
FROM dbo.signature_requests_raw;

-- ============================================================
-- List all unique sent_from_domain values (no counts, alphabetical)
-- ============================================================
SELECT DISTINCT sent_from_domain
FROM dbo.signature_requests_raw
ORDER BY sent_from_domain;

-- ============================================================
-- Unique sent_from_domain values WITH request count, alphabetical
-- ============================================================
SELECT sent_from_domain, COUNT(*) AS request_count
FROM dbo.signature_requests_raw
GROUP BY sent_from_domain
ORDER BY sent_from_domain;

-- ============================================================
-- Usage by client (core ticket requirement: request counts groupable by client)
-- ============================================================
SELECT sent_from_domain, COUNT(*) AS usage_count
FROM dbo.signature_requests_raw
GROUP BY sent_from_domain
ORDER BY usage_count DESC;

-- ============================================================
-- Usage by client, excluding NULL sent_from_domain
-- ============================================================
SELECT sent_from_domain, COUNT(*) AS usage_count
FROM dbo.signature_requests_raw
WHERE sent_from_domain IS NOT NULL
GROUP BY sent_from_domain
ORDER BY usage_count DESC;

-- ============================================================
-- Usage by client, excluding NULLs and any internal BRIO test domains (briolabs*)
-- ============================================================
SELECT sent_from_domain, COUNT(*) AS usage_count
FROM dbo.signature_requests_raw
WHERE sent_from_domain IS NOT NULL
  AND sent_from_domain NOT LIKE '%briolabs%'
GROUP BY sent_from_domain
ORDER BY usage_count DESC;

-- ============================================================
-- Count of rows with has_error = true
-- ============================================================
SELECT COUNT(*) AS error_count
FROM dbo.signature_requests_raw
WHERE has_error = 1;

-- ============================================================
-- client_id vs sent_from_domain relationship check
-- ============================================================
SELECT client_id, sent_from_domain, COUNT(*) AS cnt
FROM dbo.signature_requests_raw
GROUP BY client_id, sent_from_domain
ORDER BY client_id, cnt DESC;
