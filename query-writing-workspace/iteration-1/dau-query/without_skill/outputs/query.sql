-- Firefox Daily Active Users
SELECT
  DATE(submission_timestamp) AS date,
  COUNT(DISTINCT client_id) AS daily_active_users
FROM
  `moz-fx-data-shared-prod.telemetry.main`
WHERE
  DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND app_name = 'Firefox'
GROUP BY date
ORDER BY date DESC
