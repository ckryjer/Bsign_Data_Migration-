## 2026-09-09 — Endpoint scoping fix

API key confirmed correct (BRIO Master account) — issue was NOT the key. `signature_request/list` defaults to only the API key owner's own requests when `account_id` param is omitted. Need `account_id=all` added to the relative URL to get all team/client usage instead of just internal/demo data.

Keeping endpoint `v3/signature_request/list` — NOT switching to `v3/report/create` (that endpoint emails an async CSV, not queryable/pipeline-friendly).

Updated relative URL (not yet applied in Azure):
`v3/signature_request/list?page=<pageNumber>&page_size=20&account_id=all`

ForEach loop stays — still needed after this fix, and the hardcoded page range (`@range(1,22)`) will likely need to increase once real account-wide data flows (more data = more pages than the 428-row demo set).

Confirmed via Postman: `account_id=all` works. `list_info.num_pages` = 150, `num_results` = 2,997 (up from 428/22 pages). Updated relative URL:
`@concat('v3/signature_request/list?page=', dataset().pageNumber, '&page_size=20&account_id=all')`
Updated ForEach1 Items: `@range(1,150)` (was `@range(1,22)`).
Plan: truncate `dbo.signature_requests_raw` before re-running, so old demo data doesn't mix with real data.

## Note — ForEach Sequential setting

`Items = @range(1,150)` generates the list `[1...150]` for ForEach to iterate — just a clean way to produce 150 sequential numbers without typing them out.

`Sequential` checkbox (checked) = iterations run one at a time, in order. Unchecked = parallel execution (faster, but riskier — out-of-order/rate-limited API calls, concurrent writes to same SQL table). Keeping Sequential checked for now, since this is the first real run at full scale (150 pages). Revisit parallel (with a concurrency cap) later if speed becomes a problem.

## Note — why the relative URL is dynamic

ForEach iterates through page numbers, so the relative URL must change each pass (a static URL would call page 1 on every iteration). The `pageNumber` dataset parameter is what allows that change. `concat()` is what reassembles the fixed text + changing page number back into one single valid URL string each time, so ADF always sends a complete address (e.g. `v3/signature_request/list?page=7&page_size=20`), never fragmented pieces.
