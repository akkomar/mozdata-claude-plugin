Here's a BigQuery query to get Firefox Daily Active Users (DAU).

### Query explanation

This query counts the number of distinct users (by `client_id`) per day from Mozilla's telemetry data in BigQuery. It uses the `main` ping table which contains the primary telemetry data sent by Firefox.

### Key points

- **`COUNT(DISTINCT client_id)`** gives you the number of unique users per day
- **`submission_timestamp`** is used for the date partition
- Adjust the `INTERVAL 30 DAY` to change the lookback window
- You may want to add filters for specific channels (release, beta, nightly) or countries

### Customization

To break down by country or channel:

```sql
SELECT
  DATE(submission_timestamp) AS date,
  country,
  normalized_channel,
  COUNT(DISTINCT client_id) AS daily_active_users
FROM
  `moz-fx-data-shared-prod.telemetry.main`
WHERE
  DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY date, country, normalized_channel
ORDER BY date DESC, daily_active_users DESC
```

Note: For large-scale production reporting, Mozilla may have pre-aggregated tables that would be more efficient than scanning raw telemetry data.
