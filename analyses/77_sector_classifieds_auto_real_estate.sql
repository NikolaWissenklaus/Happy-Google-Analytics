-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: classifieds, cars, real estate, rentals, job boards, services directories
-- nothing is sold on the site: the value is the CONTACT (whatsapp, phone, form, schedule a visit).
-- The questions: which listings get views but no contact (bad photos / price), how the demand per
-- price band compares with the supply, which neighborhoods / models are hot, and which channel
-- brings people that contact more than one listing (real buyers) vs one look and leave.
-- Listing = view_item (item_id = listing id, item_category = type / brand, price = asking price).

DECLARE contact_events ARRAY<STRING> DEFAULT ['generate_lead', 'whatsapp_click', 'phone_click', 'contact', 'schedule_visit'];

-- 1) listings with views and no contact (last 30 days): the "fix the listing" list
WITH views AS (
  SELECT
    item_id,
    ANY_VALUE(item_name) AS listing,
    ANY_VALUE(item_category) AS category,
    AVG(price) AS asking_price,
    COUNT(*) AS views,
    COUNT(DISTINCT session_key) AS sessions
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name = 'view_item'
  GROUP BY item_id
),
contacts AS (
  -- the contact belongs to the last listing viewed in the session before it
  SELECT
    ARRAY_AGG(i.item_id ORDER BY i.event_ts DESC LIMIT 1)[OFFSET(0)] AS item_id,
    e.event_id
  FROM `your-gcp-project.ga4_core.fct_events` AS e
  JOIN `your-gcp-project.ga4_core.fct_item_interactions` AS i
    ON i.session_key = e.session_key AND i.event_ts <= e.event_ts AND i.event_name = 'view_item'
  WHERE e.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND i.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND e.event_name IN UNNEST(contact_events)
  GROUP BY e.event_id
)
SELECT
  v.item_id,
  v.listing,
  v.category,
  v.asking_price,
  v.sessions,
  COUNT(c.event_id) AS contacts,
  SAFE_DIVIDE(COUNT(c.event_id), v.sessions) AS contact_rate,
  -- price vs the median of the same category
  SAFE_DIVIDE(v.asking_price, PERCENTILE_CONT(v.asking_price, 0.5) OVER (PARTITION BY v.category)) - 1 AS price_vs_category_median
FROM views AS v
LEFT JOIN contacts AS c USING (item_id)
GROUP BY v.item_id, v.listing, v.category, v.asking_price, v.sessions
HAVING v.sessions >= 50 AND COUNT(c.event_id) = 0
ORDER BY v.sessions DESC
LIMIT 100;
-- price_vs_category_median > 20% and no contacts: the advertiser needs the price talk, not more traffic

-- 2) demand x supply per price band: share of views vs share of listings (where buyers look and the
-- stock is thin = raise the price, or recruit listings in that band)
WITH v AS (
  SELECT item_id, item_category, price
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name = 'view_item'
    AND price > 0
),
banded AS (
  SELECT
    item_category,
    item_id,
    NTILE(10) OVER (PARTITION BY item_category ORDER BY price) AS price_decile,
    price
  FROM (SELECT item_category, item_id, AVG(price) AS price FROM v GROUP BY 1, 2)
),
view_counts AS (
  SELECT item_id, COUNT(*) AS views FROM v GROUP BY 1
)
SELECT
  b.item_category,
  b.price_decile,
  MIN(b.price) AS from_price,
  MAX(b.price) AS to_price,
  COUNT(*) AS listings,
  SUM(vc.views) AS views,
  SAFE_DIVIDE(SUM(vc.views), SUM(SUM(vc.views)) OVER (PARTITION BY b.item_category)) AS share_of_views,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER (PARTITION BY b.item_category)) AS share_of_listings,
  SAFE_DIVIDE(SUM(vc.views), COUNT(*)) AS views_per_listing
FROM banded AS b
JOIN view_counts AS vc USING (item_id)
GROUP BY 1, 2
ORDER BY 1, 2;
-- deciles are equal in listings, so share_of_views far above 10% = the hot band

-- 3) real buyers per channel: people that contacted 2+ listings in 30 days, per first channel
WITH contacts AS (
  SELECT user_key, COUNT(*) AS contacts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name IN UNNEST(contact_events)
  GROUP BY 1
),
visitors AS (
  SELECT DISTINCT user_key, session_default_channel_group
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND session_number = 1
)
SELECT
  v.session_default_channel_group AS first_channel,
  COUNT(*) AS new_visitors,
  SAFE_DIVIDE(COUNTIF(c.contacts >= 1), COUNT(*)) AS contacted_any,
  SAFE_DIVIDE(COUNTIF(c.contacts >= 2), COUNT(*)) AS contacted_2_or_more,
  SAFE_DIVIDE(COUNTIF(c.contacts >= 2), COUNTIF(c.contacts >= 1)) AS serious_buyer_share
FROM visitors AS v
LEFT JOIN contacts AS c USING (user_key)
GROUP BY 1
HAVING COUNT(*) >= 200
ORDER BY contacted_2_or_more DESC;

-- 4) hot neighborhoods / models: week over week growth of views per category2 (bairro, modelo...)
WITH w AS (
  SELECT
    COALESCE(item_category2, '(not set)') AS segment,
    COUNTIF(event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)) AS views_last_7d,
    COUNTIF(event_date < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)) / 3 AS avg_views_previous_weeks
  FROM `your-gcp-project.ga4_core.fct_item_interactions`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 28 DAY)
    AND event_date < CURRENT_DATE()
    AND event_name = 'view_item'
  GROUP BY 1
)
SELECT *, SAFE_DIVIDE(views_last_7d, avg_views_previous_weeks) - 1 AS growth
FROM w
WHERE avg_views_previous_weeks >= 30
ORDER BY growth DESC
LIMIT 30;
