-- Firefox Android Daily Active Users
SELECT
  DATE(submission_timestamp) AS date,
  COUNT(DISTINCT client_id) AS daily_active_users
FROM
  `moz-fx-data-shared-prod.org_mozilla_firefox.baseline`
WHERE
  DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY date
ORDER BY date DESC
