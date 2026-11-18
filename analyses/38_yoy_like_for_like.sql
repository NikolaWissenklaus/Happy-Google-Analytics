-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- are we really growing against last year?
-- comparing "November vs November" mixes different weekdays, Black Friday on different dates and
-- holidays that moved. Here every day is compared with the SAME WEEKDAY of the same week last
-- year (dim_calendar.same_weekday_last_year), and the special days are flagged.

WITH daily AS (
  SELECT session_date AS date_day, COUNT(*) AS sessions, SUM(transactions) AS orders, SUM(revenue) AS revenue,
         COUNTIF(is_new_user) AS new_users
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 800 DAY) AND NOT is_bot_suspect
  GROUP BY 1
)
SELECT
  c.week_start,
  SUM(d.sessions) AS sessions,
  SUM(ly.sessions) AS sessions_last_year,
  SUM(d.orders) AS orders,
  SUM(ly.orders) AS orders_last_year,
  SUM(d.revenue) AS revenue,
  SUM(ly.revenue) AS revenue_last_year,
  SAFE_DIVIDE(SUM(d.revenue) - SUM(ly.revenue), SUM(ly.revenue)) AS revenue_yoy,
  SAFE_DIVIDE(SUM(d.sessions) - SUM(ly.sessions), SUM(ly.sessions)) AS sessions_yoy,
  SAFE_DIVIDE(SAFE_DIVIDE(SUM(d.orders), SUM(d.sessions)) - SAFE_DIVIDE(SUM(ly.orders), SUM(ly.sessions)),
              SAFE_DIVIDE(SUM(ly.orders), SUM(ly.sessions))) AS conversion_yoy,
  LOGICAL_OR(c.is_special_day) AS week_has_special_day,
  STRING_AGG(DISTINCT COALESCE(c.holiday_name, c.retail_event), ', ') AS special_days
FROM `your-gcp-project.ga4_core.dim_calendar` AS c
JOIN daily AS d ON d.date_day = c.date_day
LEFT JOIN daily AS ly ON ly.date_day = c.same_weekday_last_year
WHERE c.date_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 26 WEEK)
  AND c.date_day < CURRENT_DATE()
GROUP BY c.week_start
ORDER BY c.week_start;

-- year to date like for like (same weekdays), the number to show the board
WITH daily AS (
  SELECT transaction_date AS date_day, SUM(revenue) AS revenue
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 800 DAY)
  GROUP BY 1
)
SELECT
  SUM(d.revenue) AS revenue_ytd,
  SUM(ly.revenue) AS revenue_same_days_last_year,
  SAFE_DIVIDE(SUM(d.revenue) - SUM(ly.revenue), SUM(ly.revenue)) AS ytd_growth_like_for_like
FROM `your-gcp-project.ga4_core.dim_calendar` AS c
JOIN daily AS d ON d.date_day = c.date_day
LEFT JOIN daily AS ly ON ly.date_day = c.same_weekday_last_year
WHERE c.date_day >= DATE_TRUNC(CURRENT_DATE(), YEAR) AND c.date_day < CURRENT_DATE();
