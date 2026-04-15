Here is a query to get Firefox Desktop DAU (Daily Active Users).

### Table choice

This query uses `moz-fx-data-shared-prod.telemetry.active_users_aggregates`, which is the **Single Source of Truth** for DAU/WAU/MAU at Mozilla. It sits at the top of the aggregation hierarchy (Level 1 — pre-aggregated), meaning it is the fastest and cheapest option. This table is also not affected by client data shredding, so historical counts remain stable.

### What the query returns

| Column | Description |
|--------|-------------|
| `submission_date` | The date |
| `dau` | Daily Active Clients for Firefox Desktop |
| `wau` | Weekly Active Clients (7-day window) |
| `mau` | Monthly Active Clients (28-day window) |
| `dau_28ma` | DAU 28-day moving average — the standard KPI reporting metric |

The query covers the last 60 days. Adjust the `INTERVAL 60 DAY` clause to change the date range.

### Key notes

- The `app_name = 'Firefox Desktop'` filter selects only desktop Firefox. For mobile products, use `'Fenix'` (Android), `'Firefox iOS'`, `'Focus Android'`, or `'Focus iOS'`.
- The 28-day moving average (`dau_28ma`) smooths out daily variance and is the standard metric used in KPI reporting.
- This table uses `submission_date` (a DATE field) as its partition key, not `submission_timestamp`.
- DAU counts from this table represent **client profiles**, not individual users — one person may have multiple profiles.
- For the official Confluence definition of DAU and related calculation guidance, see: https://mozilla-hub.atlassian.net/wiki/spaces/DATA/pages/314704478

### Customization options

To break down by additional dimensions (country, channel, OS), add them to both `SELECT` and `GROUP BY`:

```sql
SELECT
  submission_date,
  country,
  SUM(dau) AS dau
FROM
  `moz-fx-data-shared-prod.telemetry.active_users_aggregates`
WHERE
  app_name = 'Firefox Desktop'
  AND submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
GROUP BY submission_date, country
ORDER BY submission_date, dau DESC
```

For **development/testing**, add `AND sample_id = 0` to work with a 1% sample for faster iteration. Note that `active_users_aggregates` is already pre-aggregated, so sample_id filtering is not needed for cost savings here — it is more relevant when querying client-level tables.
