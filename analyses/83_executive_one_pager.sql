-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- THE BOARD ONE PAGER: one query, one table, month to date vs the same days of last month and of
-- last year. Revenue, orders, AOV, sessions, conversion, new customers, marketing cost, MER, CAC,
-- share of revenue from returning customers and the identified share. Then the 5 channels that
-- moved the most money. Paste it in the monthly deck as it is.
-- "same days" = day 1 to yesterday of each month, so a half month is never compared to a full one.

DECLARE yesterday DATE DEFAULT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY);
DECLARE mtd_start DATE DEFAULT DATE_TRUNC(yesterday, MONTH);

-- 1) the KPI table
WITH periods AS (
  SELECT 'this month' AS period, 1 AS sort, mtd_start AS d_from, yesterday AS d_to
  UNION ALL SELECT 'last month', 2, DATE_SUB(mtd_start, INTERVAL 1 MONTH), DATE_SUB(yesterday, INTERVAL 1 MONTH)
  UNION ALL SELECT 'last year', 3, DATE_SUB(mtd_start, INTERVAL 1 YEAR), DATE_SUB(yesterday, INTERVAL 1 YEAR)
),
orders AS (
  SELECT
    p.period,
    SUM(t.revenue) AS revenue,
    COUNT(*) AS orders,
    COUNTIF(t.is_first_purchase) AS new_customers,
    SUM(IF(NOT t.is_first_purchase, t.revenue, 0)) AS returning_revenue,
    SUM(COALESCE(t.refunded_value, 0)) AS refunds
  FROM periods AS p
  JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.transaction_date BETWEEN p.d_from AND p.d_to
  WHERE t.is_valid_for_revenue
  GROUP BY 1
),
traffic AS (
  SELECT
    p.period,
    COUNT(*) AS sessions,
    COUNTIF(s.is_identified_user) AS identified_sessions,
    COUNT(DISTINCT s.user_pseudo_id) AS users
  FROM periods AS p
  JOIN `your-gcp-project.ga4_core.fct_sessions` AS s
    ON s.session_date BETWEEN p.d_from AND p.d_to
  WHERE NOT s.is_bot_suspect
  GROUP BY 1
),
costs AS (
  SELECT p.period, SUM(c.cost) AS marketing_cost
  FROM periods AS p
  JOIN `your-gcp-project.ga4_core.fct_ad_costs_daily` AS c
    ON c.cost_date BETWEEN p.d_from AND p.d_to
  GROUP BY 1
)
SELECT
  p.period,
  p.d_from,
  p.d_to,
  o.revenue,
  o.orders,
  SAFE_DIVIDE(o.revenue, o.orders) AS aov,
  t.sessions,
  t.users,
  SAFE_DIVIDE(o.orders, t.sessions) AS conversion_rate,
  o.new_customers,
  SAFE_DIVIDE(o.returning_revenue, o.revenue) AS returning_revenue_share,
  SAFE_DIVIDE(o.refunds, o.revenue) AS refund_rate,
  c.marketing_cost,
  SAFE_DIVIDE(o.revenue, c.marketing_cost) AS mer,
  SAFE_DIVIDE(c.marketing_cost, o.new_customers) AS blended_cac,
  SAFE_DIVIDE(t.identified_sessions, t.sessions) AS identified_session_share
FROM periods AS p
LEFT JOIN orders AS o USING (period)
LEFT JOIN traffic AS t USING (period)
LEFT JOIN costs AS c USING (period)
ORDER BY p.sort;

-- 2) the 5 channels that moved the most money vs last year (same days), and why: traffic, conversion or ticket
WITH s AS (
  SELECT
    session_default_channel_group AS channel,
    IF(session_date >= mtd_start, 'now', 'ly') AS period,
    COUNT(*) AS sessions,
    SUM(transactions) AS orders,
    SUM(revenue) AS revenue
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE (session_date BETWEEN mtd_start AND yesterday
     OR session_date BETWEEN DATE_SUB(mtd_start, INTERVAL 1 YEAR) AND DATE_SUB(yesterday, INTERVAL 1 YEAR))
    AND NOT is_bot_suspect
  GROUP BY 1, 2
),
w AS (
  SELECT
    channel,
    SUM(IF(period = 'now', sessions, 0)) AS sessions_now, SUM(IF(period = 'ly', sessions, 0)) AS sessions_ly,
    SUM(IF(period = 'now', orders, 0)) AS orders_now, SUM(IF(period = 'ly', orders, 0)) AS orders_ly,
    SUM(IF(period = 'now', revenue, 0)) AS revenue_now, SUM(IF(period = 'ly', revenue, 0)) AS revenue_ly
  FROM s
  GROUP BY 1
)
SELECT
  channel,
  revenue_now,
  revenue_ly,
  revenue_now - revenue_ly AS revenue_change,
  -- the revenue change split in 3 (log decomposition, the 3 parts add up to the total change)
  SAFE_DIVIDE(revenue_now - revenue_ly, LN(SAFE_DIVIDE(revenue_now, revenue_ly))) * LN(SAFE_DIVIDE(sessions_now, sessions_ly)) AS from_traffic,
  SAFE_DIVIDE(revenue_now - revenue_ly, LN(SAFE_DIVIDE(revenue_now, revenue_ly))) * LN(SAFE_DIVIDE(SAFE_DIVIDE(orders_now, sessions_now), SAFE_DIVIDE(orders_ly, sessions_ly))) AS from_conversion,
  SAFE_DIVIDE(revenue_now - revenue_ly, LN(SAFE_DIVIDE(revenue_now, revenue_ly))) * LN(SAFE_DIVIDE(SAFE_DIVIDE(revenue_now, orders_now), SAFE_DIVIDE(revenue_ly, orders_ly))) AS from_ticket
FROM w
WHERE revenue_now > 0 AND revenue_ly > 0 AND orders_now > 0 AND orders_ly > 0 AND revenue_now != revenue_ly
ORDER BY ABS(revenue_now - revenue_ly) DESC
LIMIT 5;
-- "Paid Search -R$ 120k: -R$ 20k traffic, -R$ 95k conversion, -R$ 5k ticket" = look at the landing
-- pages and the checkout of the paid search sessions, not at the budget
