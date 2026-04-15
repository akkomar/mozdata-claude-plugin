### A note on terminology

Your question asks "how many people use Firefox on Android" — an important clarification: Mozilla's telemetry tracks **client profiles**, not individual people. One person can have multiple profiles, and one profile can run on multiple devices. So what we can measure is **Daily Active Clients (DAC)**, not actual users. The industry-standard term "DAU" is used in the tables, but it represents client profiles.

### Table choice

This query uses `moz-fx-data-shared-prod.telemetry.active_users_aggregates`, the **Single Source of Truth** for DAU/WAU/MAU across all Mozilla products. It's pre-aggregated (fastest, cheapest) and not affected by data shredding, so historical counts remain stable.

The `app_name = 'Fenix'` filter selects Firefox for Android. "Fenix" is the codename for the current Firefox Android app.

### What the query returns

| Column | Description |
|--------|-------------|
| `submission_date` | The date |
| `daily_active_clients` | DAU for Firefox Android |
| `weekly_active_clients` | WAU (7-day window) |
| `monthly_active_clients` | MAU (28-day window) |
| `dau_28_day_moving_avg` | DAU smoothed over 28 days (standard KPI metric) |

### If you need other Android products

Firefox Android ecosystem includes several apps:

```sql
-- All Firefox Android products combined
WHERE app_name IN ('Fenix', 'Focus Android')

-- Or individual products:
-- 'Fenix' = Firefox for Android (main browser)
-- 'Focus Android' = Firefox Focus for Android (privacy browser)
```

### For the latest single-day count

If you just want today's number:

```sql
SELECT SUM(dau) AS daily_active_clients
FROM `moz-fx-data-shared-prod.telemetry.active_users_aggregates`
WHERE app_name = 'Fenix'
  AND submission_date = DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
```

Note: we use `INTERVAL 2 DAY` because data from 2 days ago is typically complete and stable.
