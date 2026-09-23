SELECT COUNT(*) AS total_rows, COUNT(DISTINCT signature_request_id) AS distinct_ids
FROM dbo.signature_requests_raw;

-- Claude mentioned pagination error??

SELECT *
FROM dbo.signature_requests_raw
WHERE signature_request_id IN (
    SELECT signature_request_id
    FROM dbo.signature_requests_raw
    GROUP BY signature_request_id
    HAVING COUNT(*) > 1
)
ORDER BY signature_request_id;