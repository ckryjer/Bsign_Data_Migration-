SELECT COUNT (*) AS TOTAL_NULLS
FROM signature_requests_raw
	WHERE requester_email_address IS NULL;