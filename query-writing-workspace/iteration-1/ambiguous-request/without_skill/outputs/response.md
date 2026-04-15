Here's a query to find how many people use Firefox on Android.

### Approach

Firefox for Android (codenamed "Fenix") sends a baseline ping each time the app is opened. By counting distinct `client_id` values per day, we get the Daily Active Users count.

The table `org_mozilla_firefox.baseline` contains the baseline pings for the release version of Firefox for Android.

### What you get

- **daily_active_users**: The number of unique Firefox Android users per day over the last 30 days

### Important notes

- This counts unique client IDs, which approximates unique users (one user could have multiple devices)
- For a single recent number, change the WHERE clause to a specific date
- There are also other Firefox Android variants: `org_mozilla_firefox_beta` (beta channel) and `org_mozilla_fenix` (older builds)
- For a most-recent single day count, you could do:

```sql
SELECT COUNT(DISTINCT client_id) AS active_users
FROM `moz-fx-data-shared-prod.org_mozilla_firefox.baseline`
WHERE DATE(submission_timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
```
