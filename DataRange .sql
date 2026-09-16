SELECT
  FORMAT(DATEADD(SECOND, MIN(created_at), '1970-01-01'), 'MM/dd/yyyy') AS earliest,
  FORMAT(DATEADD(SECOND, MAX(created_at), '1970-01-01'), 'MM/dd/yyyy') AS latest
FROM dbo.signature_requests_raw;