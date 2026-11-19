-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: NGOs, churches, crowdfunding, political campaigns, causes (and any "pay what you want")
-- a donation is a purchase with feelings. The questions: one time vs recurring donors, the amount
-- people choose (and the suggested amounts that anchor it), which campaign / story brings donors
-- that give again, and the calendar (end of year, disasters, Giving Tuesday).
-- Donation = purchase. Recurring = the item_variant / item_name says monthly (change the regex).

DECLARE recurring_regex STRING DEFAULT r'(?i)(mensal|monthly|recorrente|recurring|assinatura)';

-- 1) donors and amounts, one time vs recurring, per month
WITH donations AS (
  SELECT
    t.transaction_date,
    t.user_key,
    t.revenue,
    EXISTS (SELECT 1 FROM UNNEST(t.items) AS i WHERE REGEXP_CONTAINS(CONCAT(COALESCE(i.item_name, ''), ' ', COALESCE(i.item_variant, '')), recurring_regex)) AS is_recurring
  FROM `your-gcp-project.ga4_core.fct_transactions` AS t
  WHERE t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 18 MONTH)
    AND t.is_valid_for_revenue
)
SELECT
  DATE_TRUNC(transaction_date, MONTH) AS month_start,
  COUNT(DISTINCT IF(is_recurring, user_key, NULL)) AS recurring_donors,
  COUNT(DISTINCT IF(NOT is_recurring, user_key, NULL)) AS one_time_donors,
  SUM(IF(is_recurring, revenue, 0)) AS recurring_amount,
  SUM(IF(NOT is_recurring, revenue, 0)) AS one_time_amount,
  APPROX_QUANTILES(IF(NOT is_recurring, revenue, NULL), 100 IGNORE NULLS)[OFFSET(50)] AS median_one_time_gift,
  APPROX_QUANTILES(IF(is_recurring, revenue, NULL), 100 IGNORE NULLS)[OFFSET(50)] AS median_recurring_gift
FROM donations
GROUP BY 1
ORDER BY 1;

-- 2) the anchor: how many gifts land exactly on round numbers (the suggested buttons)
SELECT
  ROUND(revenue) AS amount,
  COUNT(*) AS gifts,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) AS share_of_gifts,
  SAFE_DIVIDE(SUM(revenue), SUM(SUM(revenue)) OVER ()) AS share_of_amount
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  AND is_valid_for_revenue
GROUP BY 1
HAVING COUNT(*) >= 20
ORDER BY gifts DESC
LIMIT 25;
-- if 40% give the FIRST suggested button, testing a higher first button is the cheapest fundraising there is

-- 3) campaigns that bring donors that give again (second gift within 180 days of the first)
WITH firsts AS (
  SELECT user_key, transaction_date AS first_date, revenue AS first_gift,
    COALESCE(session_campaign, '(not set)') AS campaign, session_default_channel_group AS channel
  FROM `your-gcp-project.ga4_core.fct_transactions`
  WHERE transaction_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 540 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
    AND is_valid_for_revenue AND is_first_purchase
),
later AS (
  SELECT f.user_key, COUNT(t.transaction_id) AS later_gifts, SUM(t.revenue) AS later_amount
  FROM firsts AS f
  JOIN `your-gcp-project.ga4_core.fct_transactions` AS t
    ON t.user_key = f.user_key AND t.transaction_date > f.first_date AND t.transaction_date <= DATE_ADD(f.first_date, INTERVAL 180 DAY)
  WHERE t.is_valid_for_revenue AND t.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 540 DAY)
  GROUP BY 1
)
SELECT
  f.channel,
  f.campaign,
  COUNT(*) AS first_time_donors,
  AVG(f.first_gift) AS avg_first_gift,
  SAFE_DIVIDE(COUNTIF(l.later_gifts > 0), COUNT(*)) AS gave_again_180d,
  AVG(f.first_gift + COALESCE(l.later_amount, 0)) AS value_per_donor_180d
FROM firsts AS f
LEFT JOIN later AS l USING (user_key)
GROUP BY 1, 2
HAVING COUNT(*) >= 30
ORDER BY value_per_donor_180d DESC;
-- the emergency campaign brings many donors that never come back; the story campaign brings fewer, loyal ones

-- 4) the donation page: conversion of the sessions that reached it, by device and the scroll of the page
-- (long stories with the button at the end lose the mobile donors)
SELECT
  pv.device_category,
  CASE
    WHEN pv.max_percent_scrolled IS NULL THEN 'no scroll event'
    WHEN pv.max_percent_scrolled < 90 THEN 'did not reach the end'
    ELSE 'reached 90%'
  END AS scroll,
  COUNT(DISTINCT pv.session_key) AS sessions_on_donation_page,
  SAFE_DIVIDE(COUNT(DISTINCT IF(pv.session_has_purchase, pv.session_key, NULL)), COUNT(DISTINCT pv.session_key)) AS donation_rate
FROM `your-gcp-project.ga4_core.fct_page_views` AS pv
WHERE pv.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY)
  AND REGEXP_CONTAINS(pv.page_path, r'(?i)(doe|doar|donate|donation|apoie|contribua)')
GROUP BY 1, 2
ORDER BY 1, 2;
