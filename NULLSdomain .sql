SELECT COUNT(*) AS null_email_count
FROM signature_requests_raw
WHERE sent_from_domain IS NULL;