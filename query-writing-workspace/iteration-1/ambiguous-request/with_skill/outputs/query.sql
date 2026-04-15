-- Firefox Android (Fenix) Daily Active Clients over the last 30 days
-- Source of truth: active_users_aggregates (pre-aggregated, not affected by shredding)
SELECT
  submission_date,
  SUM(dau) AS daily_active_clients,
  SUM(wau) AS weekly_active_clients,
  SUM(mau) AS monthly_active_clients,
  AVG(SUM(dau)) OVER (
    ORDER BY submission_date ASC
    ROWS BETWEEN 27 PRECEDING AND CURRENT ROW
  ) AS dau_28_day_moving_avg
FROM
  `moz-fx-data-shared-prod.telemetry.active_users_aggregates`
WHERE
  app_name = 'Fenix'
  AND submission_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY
  submission_date
ORDER BY
  submission_date DESC
