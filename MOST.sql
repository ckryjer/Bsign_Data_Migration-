SELECT
  signature_request_id,
  requester_email_address,
  sent_from_domain,
  created_at,
  CONVERT(VARCHAR, DATEADD(SECOND, created_at, '1970-01-01'), 101) AS created_date,
  is_complete,
  has_error,
  client_id,
  signed_at,
  CONVERT(VARCHAR, DATEADD(SECOND, signed_at, '1970-01-01'), 101) AS signed_date,
  cc_email_addresses
FROM dbo.signature_requests_raw;


-- created_at & signed_at original in Unix (seconds) 
-- 4 Duplicate rows 