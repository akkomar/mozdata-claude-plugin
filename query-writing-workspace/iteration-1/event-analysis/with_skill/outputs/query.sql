-- Activity Stream click events in Firefox Desktop, last 7 days, by country
-- Table: events_stream (pre-flattened, clustered by event_category)
-- Partition filter: DATE(submission_timestamp) for cost control
-- sample_id = 0 for 1% dev sample — remove for production
SELECT
  DATE(submission_timestamp) AS submission_date,
  normalized_country_code AS country,
  event_name,
  COUNT(*) AS event_count,
  COUNT(DISTINCT client_id) AS unique_clients
FROM
  mozdata.firefox_desktop.events_stream
WHERE
  DATE(submission_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND event_category = 'activity_stream'
  AND event_name = 'click'
  AND sample_id = 0  -- 1% sample for development; remove for full data
GROUP BY
  submission_date,
  country,
  event_name
ORDER BY
  submission_date DESC,
  event_count DESC
