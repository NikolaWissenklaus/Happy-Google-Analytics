// author: Francisco Lucas / Nikola Wissenklaus / Chico

// UA Conversions reports (Goals, Ecommerce, Multi-Channel Funnels) as views over the marts.
// Same numbers as the marts, only with the names people remember from UA.

const schema = constants.SCHEMAS.reports_ua;
const view = (name, description, query) => publish(name, {
  type: "view",
  schema,
  description,
  tags: ["reports", "ua_report", "daily", "conversions"]
}).query(query);

view("rpt_ua_goals_overview_daily",
  "UA Conversions > Goals > Overview: goal completions, goal value and goal conversion rate (completions / sessions of the day) per goal (= key event)",
  ctx => `
WITH sessions_per_day AS (
  SELECT session_date, SUM(sessions) AS sessions
  FROM ${ctx.ref("rpt_ua_audience_overview_daily")}
  GROUP BY 1
),
goals AS (
  SELECT event_date, key_event_name, SUM(key_events) AS goal_completions, SUM(key_event_value) AS goal_value
  FROM ${ctx.ref("rpt_ga4_key_events_daily")}
  GROUP BY 1, 2
)
SELECT
  g.event_date,
  g.key_event_name AS goal,
  g.goal_completions,
  g.goal_value,
  s.sessions,
  SAFE_DIVIDE(g.goal_completions, s.sessions) AS goal_conversion_rate
FROM goals AS g
LEFT JOIN sessions_per_day AS s ON s.session_date = g.event_date`);

view("rpt_ua_ecommerce_overview_daily",
  "UA Conversions > Ecommerce > Overview: ecommerce conversion rate, transactions, revenue, average order value, quantity, average price and average quantity per day",
  ctx => `
SELECT
  kpi_date AS date,
  sessions,
  orders AS transactions,
  valid_revenue AS revenue,
  conversion_rate AS ecommerce_conversion_rate,
  average_order_value,
  items_sold AS quantity,
  SAFE_DIVIDE(valid_revenue, items_sold) AS avg_price,
  items_per_order AS avg_quantity,
  refunded_value AS refund_amount
FROM ${ctx.ref("ecom_daily_kpis")}`);

view("rpt_ua_product_performance_daily",
  "UA Conversions > Ecommerce > Product Performance: product revenue, unique purchases, quantity, avg price, avg qty, product refund amount, cart-to-detail and buy-to-detail rates",
  ctx => `
SELECT
  event_date AS date,
  item_id AS product_sku,
  item_name AS product,
  item_category AS product_category,
  item_brand AS product_brand,
  item_revenue AS product_revenue,
  unique_purchases,
  units_sold AS quantity,
  avg_price_sold AS avg_price,
  avg_quantity AS avg_qty,
  item_refund_value AS product_refund_amount,
  cart_to_detail_rate,
  buy_to_detail_rate
FROM ${ctx.ref("ecom_item_performance_daily")}`);

view("rpt_ua_sales_performance",
  "UA Conversions > Ecommerce > Sales Performance: by transaction id and date, revenue, tax, shipping, refund amount and quantity",
  ctx => `
SELECT
  transaction_date AS date,
  transaction_id,
  revenue,
  tax_value AS tax,
  shipping_value AS shipping,
  refunded_value AS refund_amount,
  item_quantity AS quantity,
  CONCAT(COALESCE(session_source, '(direct)'), ' / ', COALESCE(session_medium, '(none)')) AS session_source_medium,
  is_valid_for_revenue
FROM ${ctx.ref("fct_transactions")}`);

view("rpt_ua_mcf_overview",
  "UA Conversions > Multi-Channel Funnels > Overview / Assisted Conversions for the last 3 months: last interaction conversions, assisted conversions and their ratio per channel",
  ctx => `
SELECT
  key_event_name AS conversion,
  channel AS mcf_channel_grouping,
  SUM(last_click_conversions) AS last_click_or_direct_conversions,
  SUM(assisted_conversions) AS assisted_conversions,
  SUM(first_click_conversions) AS first_interaction_conversions,
  SAFE_DIVIDE(SUM(assisted_conversions), SUM(last_click_conversions)) AS assisted_last_click_ratio,
  SUM(assisted_value) AS assisted_conversion_value
FROM ${ctx.ref("attr_assisted_conversions")}
WHERE conversion_month >= DATE_SUB(DATE_TRUNC(CURRENT_DATE('${constants.TIMEZONE}'), MONTH), INTERVAL 3 MONTH)
GROUP BY 1, 2`);
