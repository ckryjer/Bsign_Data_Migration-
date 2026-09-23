SELECT COUNT(*) AS error_count
FROM signature_requests_raw
	WHERE has_error = 1
AND sent_from_domain IS NOT NULL 
AND sent_from_domain NOT LIKE '%briolabs%';