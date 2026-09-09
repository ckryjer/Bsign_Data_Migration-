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

## Reference — v3/report/create schema (user_activity report)

Tested `report/create` with `report_type: ["user_activity"]`. CSV arrived by email with this schema — team already uses/trusts these columns. Note: this is a **per-user/team aggregate summary**, not per-signature-request rows like our raw extract — different granularity, useful for shaping the eventual Tableau-facing/transformed table, not a replacement for `signature_requests_raw`.

Columns:
- Email Address
- Last Name
- First Name
- Team Name
- Templates Owned
- Requests sent
- % requests complete
- % requests cancelled
- % requests declined
- Documents signed

(Row data intentionally omitted — real client emails/names, not needed for schema reference.)

## Known limitation — 4 duplicate rows

Full extract: 3000 rows, 2996 distinct `signature_request_id`, 4 duplicates (each 2x). Cause: live data changed during the 150-page sequential pull, shifting records across page boundaries. Not fixed in pipeline — dedup later via `SELECT DISTINCT`/`ROW_NUMBER()` if needed.

## Open question — is this truly ALL historical data?

Extract date range: 5/19/2025 to 9/9/2026. `account_id=all` docs don't confirm full historical coverage (no documented date limit, but not guaranteed either). Need to confirm with Greg/Larry when BRIO's Dropbox Sign account was actually set up — if earlier than 5/19/2025, data is missing.

## Columns we will likely keep (not cutting anything yet — pre-transform)

| Column | Why |
|---|---|
| signature_request_id | primary identifier, dedup/counting |
| sent_from_domain | leading client-grouping key candidate |
| client_id | other grouping-key candidate |
| created_at | time-based/trend reporting |
| is_complete | completion-rate metric |
| is_declined | decline-rate metric |
| has_error | flags failed requests |
| test_mode | filter out non-production/test data |
| requester_email_address | attribution/audit trail |
| title | plausible Tableau context |
| subject | plausible Tableau context |
| expires_at | plausible Tableau context |
| signed_at | plausible Tableau context |

## Reference — Collection reference (verified via Microsoft Learn docs)

`collectionReference` is a real, documented ADF Copy Activity mapping property (`translator.collectionReference`). Per Microsoft docs: "If you want to iterate and extract data from the objects inside an array field with the same pattern and convert to per row per object, specify the JSON path of that array to do cross-apply." It's what turns the nested `signature_requests` array into one row per signature request, instead of one row for the whole response.

Our value `$['signature_requests']` matches Microsoft's documented JSON path syntax exactly.

Bonus behavior (from same doc): if the array marked as collection reference comes back empty on a given record, and the "Map complex values to string" checkbox is checked, that whole record is silently skipped (not written as a blank row).

## Note — why the relative URL is dynamic

ForEach iterates through page numbers, so the relative URL must change each pass (a static URL would call page 1 on every iteration). The `pageNumber` dataset parameter is what allows that change. `concat()` is what reassembles the fixed text + changing page number back into one single valid URL string each time, so ADF always sends a complete address (e.g. `v3/signature_request/list?page=7&page_size=20`), never fragmented pieces.
