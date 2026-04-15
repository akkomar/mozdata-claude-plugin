-- Firefox Desktop DAU from the official Single Source of Truth table
-- Includes 28-day moving average (standard KPI reporting metric)
SELECT
  submission_date,
  SUM(dau) AS dau,
  SUM(wau) AS wau,
  SUM(mau) AS mau,
  AVG(SUM(dau)) OVER (
    ORDER BY submission_date ASC
    ROWS BETWEEN 27 PRECEDING AND CURRENT ROW
  ) AS dau_28ma
FROM
  `moz-fx-data-shared-prod.telemetry.active_users_aggregates`
WHERE
  app_name = 'Firefox Desktop'
  AND submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
GROUP BY submission_date
ORDER BY submission_date
