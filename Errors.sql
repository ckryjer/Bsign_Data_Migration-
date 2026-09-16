SELECT COUNT(*) AS error_count
FROM signature_requests_raw
	WHERE has_error = 1
AND requester_email_address <> 'dropboxsign@gobr.io.com';


-- DOES NOT show WHERE erros occur...itenral or client? 