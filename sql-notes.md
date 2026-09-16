# SQL Notes (SQL Server)

Personal study notes from working through some real queries.

## USE - selecting which database to run against

A SQL Server can hold multiple databases. `USE` tells SQL Server which one your
queries should run against for the rest of the session/script.

```sql
USE sqldb-bsign-usage;

SELECT * FROM signature_requests_raw;
```

**In SSMS specifically:** you don't always need to write this. The dropdown in
the toolbar next to the "Execute" button shows/sets the current database for
that query window - if it's already showing the right database name, anything
you run in that window already targets it, no `USE` statement needed. You'd
only need `USE` if you want to switch databases partway through a script, or
want the script to be explicit/self-contained regardless of what the dropdown
happens to be set to.

## GROUP BY rule

Every column in `SELECT` that isn't inside an aggregate function (like `COUNT()`)
**must** also appear in `GROUP BY`. If they don't match, SQL Server throws an error.

```sql
-- Wrong: SELECT and GROUP BY use different columns
SELECT requester_email_address, COUNT(*) AS usage_count
FROM signature_requests_raw
GROUP BY sent_from_domain   -- doesn't match the SELECT above

-- Right: they match
SELECT requester_email_address, COUNT(*) AS usage_count
FROM signature_requests_raw
GROUP BY requester_email_address
ORDER BY usage_count DESC;
```

## Getting rid of "duplicate" rows that aren't really duplicates

`GROUP BY` already collapses exact duplicates. If you're still seeing what looks
like duplicates, it's usually casing or whitespace differences
(`John@Acme.com` vs `john@acme.com` are different strings to SQL Server).

Fix: normalize the value before grouping.

```sql
SELECT
    LOWER(TRIM(requester_email_address)) AS requester_email_address,
    COUNT(*) AS usage_count
FROM signature_requests_raw
GROUP BY LOWER(TRIM(requester_email_address))
ORDER BY usage_count DESC;
```

(If SQL Server predates 2017, `TRIM()` isn't available — use `LTRIM(RTRIM(x))` instead.)

## Pulling a domain out of an email address

`requester_email_address` holds a full email. To group by company (not by
person), pull out everything after the `@`.

```sql
SELECT
    RIGHT(requester_email_address, LEN(requester_email_address) - CHARINDEX('@', requester_email_address)) AS client_domain,
    COUNT(*) AS usage_count
FROM signature_requests_raw
GROUP BY RIGHT(requester_email_address, LEN(requester_email_address) - CHARINDEX('@', requester_email_address))
ORDER BY usage_count DESC;
```

(This is SQL Server syntax. Postgres/Snowflake have an easier built-in:
`SPLIT_PART(requester_email_address, '@', 2)`.)

## Formatting a date with CONVERT

`CONVERT(VARCHAR, created_at, 101)` does two separate jobs at once:

- **`VARCHAR`** = *what type* to convert to. This is what makes the output
  actual readable text instead of a raw datetime value.
- **`101`** = *what layout* to use for that text (a "style code"). It only
  makes sense when converting a date/datetime to text.
- **`CONVERT()`** itself is the function doing the work — it takes both
  instructions together and produces the formatted string.

So VARCHAR alone gets you *text*, but not necessarily the layout you want.
The style code is what pins down the exact format.

```sql
SELECT CONVERT(VARCHAR, created_at, 101) AS created_at
FROM signature_requests_raw;
```

**Common style codes:**

| Code | Format              | Example              |
|------|---------------------|-----------------------|
| 101  | mm/dd/yyyy           | 09/16/2026            |
| 103  | dd/mm/yyyy (UK)      | 16/09/2026            |
| 112  | yyyymmdd             | 20260916              |
| 120  | yyyy-mm-dd hh:mi:ss  | 2026-09-16 14:30:00   |

## Converting a Unix epoch column to a readable date

`created_at` (and similar timestamp columns from APIs) is often stored as
**Unix epoch time** — a raw number counting seconds since January 1, 1970 —
not a real date/datetime value. To make it readable, you have to convert it
in two nested steps.

```sql
SELECT
  CONVERT(VARCHAR, DATEADD(SECOND, created_at, '1970-01-01'), 101) AS created_at
FROM signature_requests_raw;
```

Reading it inside-out, three layers:

**1. `DATEADD(SECOND, created_at, '1970-01-01')`**
Takes the starting date (`'1970-01-01'`, the epoch) and adds `created_at`
worth of time onto it. Result: a real SQL datetime value, not just a number
anymore.

**2. `CONVERT(VARCHAR, <that datetime>, 101)`**
Takes the datetime from step 1 and turns it into formatted text — `VARCHAR`
says convert to text, `101` (the style code) says use `MM/DD/YYYY` layout.
This has to happen *after* step 1 — `CONVERT` needs an actual date value to
format, not a raw epoch number.

**3. `AS created_at`**
Just renames the resulting expression's column header back to `created_at`
instead of showing the whole formula as the label.

So the chain is: **raw number → real date (`DATEADD`) → formatted text
(`CONVERT`) → labeled column (`AS`)**. Each step depends on the one before it.

### What the `SECOND` argument is doing

`DATEADD` always takes three arguments: a **unit**, an **amount**, and a
**starting date** — `SECOND` tells it what unit the amount represents. Since
`created_at` counts *seconds* since 1970 (not days, not minutes), you have to
say `SECOND` so the math adds the right thing. Using `DAY` instead would add
`created_at` as a number of *days*, giving a wildly wrong date.

### How to know a column is stored in seconds (not milliseconds)

Two ways to confirm, don't just assume:

1. **Check the source API's docs.** Dropbox Sign's API documents its
   timestamps as Unix time in seconds — that's the authoritative answer when
   available.
2. **Sanity-check the digit count of an actual value.** A timestamp like
   `1,788,965,571` is 10 digits. Unix time in *seconds* for the current era
   (2020s) is in the 1.7-1.8 billion range — 10 digits. If the same moment
   were stored in *milliseconds* instead, it would be a 13-digit number
   (`1,788,965,571,000`). Counting digits on a real sample value is a fast way
   to tell seconds from milliseconds even without docs in hand.

## Finding and inspecting duplicate rows (subquery with GROUP BY + HAVING)

To find *which* IDs are duplicated, and then pull the full duplicated rows
themselves (not just the count), nest two queries — read the inner one
first, since it runs conceptually first.

```sql
SELECT *
FROM dbo.signature_requests_raw
WHERE signature_request_id IN (
    SELECT signature_request_id
    FROM dbo.signature_requests_raw
    GROUP BY signature_request_id
    HAVING COUNT(*) > 1
)
ORDER BY signature_request_id;
```

**Inner query (the subquery):**
```sql
SELECT signature_request_id
FROM dbo.signature_requests_raw
GROUP BY signature_request_id
HAVING COUNT(*) > 1
```
Finds *which IDs* are duplicated. `GROUP BY` collapses rows into one group
per unique ID, `COUNT(*)` counts rows per group, and `HAVING COUNT(*) > 1`
keeps only groups with more than one row — i.e. only the duplicated IDs.
Result: just a short list of the problem ID values, not their full data.

(`HAVING` is like `WHERE`, but for filtering *after* grouping/aggregating —
`WHERE` can't reference `COUNT(*)`, `HAVING` can.)

**Outer query:**
```sql
SELECT *
FROM dbo.signature_requests_raw
WHERE signature_request_id IN (...)
ORDER BY signature_request_id;
```
A normal `SELECT *`, but only keeping rows whose `signature_request_id` is
found in the inner list. `IN (...)` means "matches any value in this set."
This gets every full row belonging to those duplicated IDs, instead of just
knowing which IDs repeat.

`ORDER BY signature_request_id` sorts the output so duplicate pairs land
next to each other, easy to visually compare.

**Why nest it like this instead of one simple query:** `GROUP BY` alone
can't return `SELECT *` — once you group, SQL only lets you select the
grouped column or aggregates, not arbitrary other columns. So the inner
query does the "which IDs repeat" math, and the outer query goes back to
the full, ungrouped table to fetch everything about those specific IDs.

### Alternative: two separate queries instead of nesting

The same result can be done as two manual steps instead of one nested query.

```sql
-- Step 1: find which IDs are duplicated
SELECT signature_request_id
FROM dbo.signature_requests_raw
GROUP BY signature_request_id
HAVING COUNT(*) > 1;

-- Step 2: manually paste those ID values in, get their full rows
SELECT *
FROM dbo.signature_requests_raw
WHERE signature_request_id IN ('id1', 'id2', 'id3', 'id4')
ORDER BY signature_request_id;
```

**Difference:** the nested version automates copying step 1's results into
step 2 — it dynamically finds whatever duplicates exist right now, with no
manual work, and stays correct if the data changes later. The two-query
version requires reading step 1's output and retyping those exact values
into step 2 by hand — more manual, and it goes stale if the duplicates
change. Same output, nesting just automates the hand-off between the two.

## CASE statements

A `CASE` statement is SQL's version of if/elif/else logic, used inside a
`SELECT` to turn column values into something more readable, computed row by
row. It checks each `WHEN` condition top to bottom and returns the value
from the **first** one that's true for that row. If none of the conditions
match, it falls through to `ELSE`.

```sql
SELECT
  signature_request_id,
  CASE
    WHEN is_complete = 1 THEN 'Completed'
    WHEN is_declined = 1 THEN 'Declined'
    WHEN has_error = 1 THEN 'Error'
    ELSE 'Pending'
  END AS status
FROM dbo.signature_requests_raw;
```

Here it collapses three separate boolean columns (`is_complete`,
`is_declined`, `has_error`) into one readable `status` label per row,
instead of having to eyeball three True/False columns yourself.

## The `AS` keyword is optional

These two are identical — `AS` just improves readability, it isn't required:

```sql
SELECT CONVERT(VARCHAR, created_at, 101) AS created_at FROM signature_requests_raw;
SELECT CONVERT(VARCHAR, created_at, 101) created_at FROM signature_requests_raw;
```
