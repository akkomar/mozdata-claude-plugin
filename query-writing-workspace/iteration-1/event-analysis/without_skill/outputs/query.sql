-- Activity Stream click events in Firefox Desktop, last 7 days, by country
SELECT
  DATE(submission_timestamp) AS date,
  metadata.geo.country AS country,
  event.category AS event_category,
  event.name AS event_name,
  COUNT(*) AS event_count,
  COUNT(DISTINCT client_id) AS unique_users
FROM
  `moz-fx-data-shared-prod.firefox_desktop.events`,
  UNNEST(events) AS event
WHERE
  DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND event.category = 'activity_stream'
  AND event.name = 'click'
GROUP BY
  date,
  country,
  event_category,
  event_name
ORDER BY
  date DESC,
  event_count DESC
