SELECT requester_email_address, COUNT(*) AS usage_count
FROM signature_requests_raw
WHERE requester_email_address IS NOT NULL
    --AND requester_email_address NOT LIKE '%briolabs%'
GROUP BY requester_email_address
ORDER BY usage_count DESC;
-- notice 12 & 3, not in dropbox UI

--INTERNAL(admin) = "dropboxsign@gobr.o" , 