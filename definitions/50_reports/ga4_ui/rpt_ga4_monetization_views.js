// author: Francisco Lucas / Nikola Wissenklaus / Chico

// GA4 Reports > Monetization replicas that are just the right columns of tables we already have.
// Views on purpose: no extra cost, always in sync with the marts.

const schema = constants.SCHEMAS.reports_ga4;

publish("rpt_ga4_ecommerce_purchases_daily", {
  type: "view",
  schema,
  description: "GA4 Reports > Monetization > Ecommerce purchases with the GA4 column names: items viewed, added to cart, purchased, item revenue, list views / clicks per item per day",
  tags: ["reports", "ga4_report", "daily", "ecommerce"]
}).query(ctx => `
SELECT
  event_date,
  item_id,
  item_name,
  item_brand,
  item_category,
  detail_views AS items_viewed,
  units_added_to_cart AS items_added_to_cart,
  units_sold AS items_purchased,
  item_revenue,
  item_refund_value AS item_refund_amount,
  list_impressions AS items_viewed_in_list,
  list_clicks AS items_clicked_in_list,
  list_ctr AS item_list_click_through_rate,
  SAFE_DIVIDE(units_added_to_cart, detail_views) AS cart_to_view_rate,
  SAFE_DIVIDE(units_sold, detail_views) AS purchase_to_view_rate
FROM ${ctx.ref("ecom_item_performance_daily")}`);

publish("rpt_ga4_promotions_daily", {
  type: "view",
  schema,
  description: "GA4 Reports > Monetization > Promotions: items viewed / clicked in promotion and promotion CTR per promotion, creative and slot",
  tags: ["reports", "ga4_report", "daily", "promotions"]
}).query(ctx => `
SELECT
  event_date,
  promotion_id,
  promotion_name,
  creative_name,
  creative_slot,
  promotion_views AS items_viewed_in_promotion,
  promotion_clicks AS items_clicked_in_promotion,
  ctr AS item_promotion_click_through_rate,
  revenue_sessions_with_click AS revenue_of_sessions_with_click
FROM ${ctx.ref("promo_internal_promotions_daily")}`);

// in-app purchases and ad revenue come as events on app streams (and ad_impression on web with AdSense / GAM)
publish("rpt_ga4_in_app_and_ads_daily", {
  type: "table",
  schema,
  description: "GA4 Reports > Monetization > In-app purchases (in_app_purchase events by product) and Publisher ads (ad_impression / ad_click by ad unit, format and source), last 90 days, one table with report = in_app_purchases | publisher_ads",
  bigquery: { partitionBy: "event_date", labels: { layer: "reports", flavor: "ga4" } },
  tags: ["reports", "ga4_report", "daily", "app"]
}).query(ctx => `
-- params extracted first: BigQuery does not group by expressions that contain subqueries
WITH
monetization_events AS (
  SELECT
    event_date,
    event_name,
    user_pseudo_id,
    event_value,
    event_value_in_usd,
    ${ga4.paramStr("product_id")} AS product_id,
    ${ga4.paramInt("quantity")} AS quantity,
    ${ga4.paramStr("ad_unit_name")} AS ad_unit_name,
    ${ga4.paramStr("ad_format")} AS ad_format,
    COALESCE(${ga4.paramStr("ad_source")}, ${ga4.paramStr("ad_platform")}) AS ad_source
  FROM ${ctx.ref("stg_ga4__events")}
  WHERE event_date >= DATE_SUB(CURRENT_DATE('${constants.TIMEZONE}'), INTERVAL 90 DAY)
    AND event_name IN ('in_app_purchase', 'ad_impression', 'ad_click')
)

SELECT
  event_date,
  'in_app_purchases' AS report,
  COALESCE(product_id, '(not set)') AS object_name,
  CAST(NULL AS STRING) AS detail,
  COUNT(*) AS events,
  SUM(COALESCE(quantity, 1)) AS quantity,
  SUM(COALESCE(event_value_in_usd, event_value, 0)) AS revenue,
  COUNT(DISTINCT user_pseudo_id) AS users,
  CURRENT_TIMESTAMP() AS loaded_at
FROM monetization_events
WHERE event_name = 'in_app_purchase'
GROUP BY event_date, object_name

UNION ALL

SELECT
  event_date,
  'publisher_ads',
  COALESCE(ad_unit_name, '(not set)') AS object_name,
  CONCAT(COALESCE(ad_format, '?'), ' / ', COALESCE(ad_source, '?')) AS detail,
  COUNTIF(event_name = 'ad_impression'),
  COUNTIF(event_name = 'ad_click'),
  SUM(IF(event_name = 'ad_impression', COALESCE(event_value, 0), 0)),
  COUNT(DISTINCT user_pseudo_id),
  CURRENT_TIMESTAMP()
FROM monetization_events
WHERE event_name IN ('ad_impression', 'ad_click')
GROUP BY event_date, object_name, detail`);
