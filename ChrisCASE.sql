select
count(*) as count,
s.requester_email_address
from dbo.signature_requests_raw s
group by s.requester_email_address
order by s.requester_email_address

select
s.signature_request_id,
CASE
	WHEN s.requester_email_address = 'bsign@wallacemiller.com' THEN 'Wallace Miller'
	WHEN s.requester_email_address = 'esclaw-bsign@gobrio.com' THEN 'ESC'
	ELSE ''
END as clientName
from dbo.signature_requests_raw s