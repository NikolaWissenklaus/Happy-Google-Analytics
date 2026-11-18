-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- how much money is the mobile experience leaving on the table?
-- most of the traffic is mobile, most of the conversion is desktop. The gap, multiplied by the
-- mobile traffic, is the size of the prize of a mobile CRO project (a ceiling: part of the gap is
-- people researching on the phone and buying on the computer, see ga4_segments.seg_cross_device).

-- 1) the gap per channel, and the revenue if mobile converted at half of the gap
WITH by_device AS (
  SELECT
    session_default_channel_group AS channel,
    device_category,
    COUNT(*) AS sessions,
    SUM(transactions) AS orders,
    SUM(revenue) AS revenue,
    SAFE_DIVIDE(SUM(transactions), COUNT(*)) AS conversion_rate,
    SAFE_DIVIDE(SUM(revenue), SUM(transactions)) AS aov
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND NOT is_bot_suspect
    AND device_category IN ('mobile', 'desktop')
  GROUP BY 1, 2
)
SELECT
  m.channel,
  m.sessions AS mobile_sessions,
  d.sessions AS desktop_sessions,
  m.conversion_rate AS mobile_conversion,
  d.conversion_rate AS desktop_conversion,
  SAFE_DIVIDE(m.conversion_rate, d.conversion_rate) AS mobile_vs_desktop,
  m.aov AS mobile_aov,
  d.aov AS desktop_aov,
  -- extra revenue per month if mobile closed HALF of the gap (keeping the mobile AOV)
  GREATEST(0, m.sessions * (d.conversion_rate - m.conversion_rate) * 0.5 * m.aov) AS prize_half_gap_30d
FROM by_device AS m
JOIN by_device AS d ON d.channel = m.channel AND d.device_category = 'desktop'
WHERE m.device_category = 'mobile'
  AND m.sessions >= 500
ORDER BY prize_half_gap_30d DESC;

-- 2) where in the funnel the mobile loses: step by step rates per device
SELECT
  device_category,
  COUNT(*) AS sessions,
  SAFE_DIVIDE(COUNTIF(has_view_item), COUNT(*)) AS product_view_rate,
  SAFE_DIVIDE(COUNTIF(has_add_to_cart), COUNTIF(has_view_item)) AS add_to_cart_rate,
  SAFE_DIVIDE(COUNTIF(has_begin_checkout), COUNTIF(has_add_to_cart)) AS cart_to_checkout_rate,
  SAFE_DIVIDE(COUNTIF(has_add_shipping_info), COUNTIF(has_begin_checkout)) AS checkout_to_shipping_rate,
  SAFE_DIVIDE(COUNTIF(has_add_payment_info), COUNTIF(has_add_shipping_info)) AS shipping_to_payment_rate,
  SAFE_DIVIDE(COUNTIF(has_purchase), COUNTIF(has_add_payment_info)) AS payment_to_purchase_rate
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND NOT is_bot_suspect
GROUP BY device_category
ORDER BY sessions DESC;

-- 3) the worst mobile landing pages (lots of mobile traffic, much worse than the same page on desktop)
WITH pages AS (
  SELECT landing_page_path, device_category, COUNT(*) AS sessions,
         SAFE_DIVIDE(COUNTIF(is_engaged), COUNT(*)) AS engagement_rate,
         SAFE_DIVIDE(SUM(transactions), COUNT(*)) AS conversion_rate
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND NOT is_bot_suspect
    AND device_category IN ('mobile', 'desktop')
  GROUP BY 1, 2
)
SELECT
  m.landing_page_path,
  m.sessions AS mobile_sessions,
  m.engagement_rate AS mobile_engagement,
  d.engagement_rate AS desktop_engagement,
  m.conversion_rate AS mobile_conversion,
  d.conversion_rate AS desktop_conversion,
  m.sessions * GREATEST(0, d.conversion_rate - m.conversion_rate) AS orders_lost_30d
FROM pages AS m
JOIN pages AS d ON d.landing_page_path = m.landing_page_path AND d.device_category = 'desktop'
WHERE m.device_category = 'mobile' AND m.sessions >= 300 AND d.sessions >= 100
ORDER BY orders_lost_30d DESC
LIMIT 30;

-- the in-app browsers (Instagram, TikTok...) are a big part of this gap: ga4_marketing.mkt_in_app_browser_gap
