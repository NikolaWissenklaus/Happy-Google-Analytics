-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- does the brazilian calendar move my revenue? payday (5th business day), 13th salary,
-- holidays, long weekends, Black Friday. Plan promotions, stock and media budget around the
-- days that sell by themselves, and do not waste discount on them.

-- 1) salary window vs the rest of the month, by payment method
SELECT
  c.is_salary_window,
  t.payment_type,
  COUNT(DISTINCT c.date_day) AS days,
  COUNT(*) AS orders,
  SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT c.date_day)) AS orders_per_day,
  SAFE_DIVIDE(SUM(t.revenue), COUNT(DISTINCT c.date_day)) AS revenue_per_day,
  AVG(t.revenue) AS aov
FROM `your-gcp-project.ga4_core.fct_transactions` AS t
JOIN `your-gcp-project.ga4_core.dim_calendar` AS c ON c.date_day = t.transaction_date
WHERE t.is_valid_for_revenue
  AND t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
GROUP BY 1, 2
ORDER BY 2, 1;

-- 2) revenue per day by day of the month: the monthly "salary curve" of your customers
SELECT
  EXTRACT(DAY FROM transaction_date) AS day_of_month,
  COUNT(*) AS orders,
  SUM(revenue) AS revenue,
  SAFE_DIVIDE(SUM(revenue), AVG(SUM(revenue)) OVER ()) AS index_vs_average_day
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
GROUP BY 1
ORDER BY 1;

-- 3) holidays and retail events against the same weekday of the 4 previous weeks
-- (does the holiday sell more, or less? "Dia das Maes" vs "Carnaval")
WITH daily AS (
  SELECT transaction_date AS date_day, SUM(revenue) AS revenue, COUNT(*) AS orders
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 800 DAY)
  GROUP BY 1
)
SELECT
  c.date_day,
  ANY_VALUE(COALESCE(c.holiday_name, c.retail_event)) AS event_name,
  ANY_VALUE(d.revenue) AS revenue,
  AVG(b.revenue) AS baseline_revenue,
  SAFE_DIVIDE(ANY_VALUE(d.revenue), AVG(b.revenue)) - 1 AS lift_vs_baseline
FROM `your-gcp-project.ga4_core.dim_calendar` AS c
JOIN daily AS d USING (date_day)
LEFT JOIN daily AS b
  ON b.date_day < c.date_day
  AND b.date_day >= DATE_SUB(c.date_day, INTERVAL 28 DAY)
  AND MOD(DATE_DIFF(c.date_day, b.date_day, DAY), 7) = 0
WHERE c.is_special_day
GROUP BY c.date_day
ORDER BY c.date_day DESC;

-- 4) Black Friday: the curve of the 30 days before and the hangover after, year by year.
-- shows if people are WAITING for BF (revenue drops before it) and how long the hangover lasts
SELECT
  EXTRACT(YEAR FROM c.date_day) AS year,
  c.days_to_black_friday,
  SUM(t.revenue) AS revenue,
  COUNT(*) AS orders
FROM `your-gcp-project.ga4_core.fct_transactions` AS t
JOIN `your-gcp-project.ga4_core.dim_calendar` AS c ON c.date_day = t.transaction_date
WHERE t.is_valid_for_revenue
  AND c.days_to_black_friday BETWEEN -14 AND 30
GROUP BY 1, 2
ORDER BY 1, 2 DESC;
