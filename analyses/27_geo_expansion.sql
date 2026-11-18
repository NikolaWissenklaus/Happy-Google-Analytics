-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- where should the store grow geographically?
-- revenue per 100 thousand inhabitants (IBGE 2022) shows the penetration of each state. A state
-- with LOW penetration and GOOD conversion is a media opportunity (people like you there, they
-- just do not know you). Low penetration and bad conversion = freight / delivery time problem.

WITH by_uf AS (
  SELECT
    geo_uf,
    COUNT(*) AS sessions,
    SUM(transactions) AS orders,
    SUM(revenue) AS revenue,
    COUNT(DISTINCT user_key) AS people,
    SAFE_DIVIDE(SUM(transactions), COUNT(*)) AS conversion_rate,
    SAFE_DIVIDE(COUNTIF(has_add_shipping_info AND NOT has_purchase), COUNTIF(has_add_shipping_info)) AS death_after_shipping_rate
  FROM `your-gcp-project.ga4_core.fct_sessions`
  WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND geo_uf IS NOT NULL
    AND NOT is_bot_suspect
  GROUP BY geo_uf
),
national AS (
  SELECT SAFE_DIVIDE(SUM(b.revenue), SUM(s.population_2022)) * 100000 AS revenue_per_100k_brazil,
         SAFE_DIVIDE(SUM(b.orders), SUM(b.sessions)) AS conversion_brazil
  FROM by_uf AS b
  JOIN `your-gcp-project.ga4_seeds.seed_br_states` AS s ON s.uf = b.geo_uf
)
SELECT
  b.geo_uf,
  s.state_name,
  s.macro_region,
  s.population_2022,
  b.sessions,
  b.orders,
  b.revenue,
  SAFE_DIVIDE(b.revenue, s.population_2022) * 100000 AS revenue_per_100k_inhabitants,
  SAFE_DIVIDE(SAFE_DIVIDE(b.revenue, s.population_2022) * 100000, n.revenue_per_100k_brazil) AS penetration_index,
  b.conversion_rate,
  SAFE_DIVIDE(b.conversion_rate, n.conversion_brazil) AS conversion_index,
  b.death_after_shipping_rate,
  CASE
    WHEN SAFE_DIVIDE(SAFE_DIVIDE(b.revenue, s.population_2022) * 100000, n.revenue_per_100k_brazil) < 0.7
      AND SAFE_DIVIDE(b.conversion_rate, n.conversion_brazil) >= 0.9 THEN 'grow_media_here'
    WHEN SAFE_DIVIDE(SAFE_DIVIDE(b.revenue, s.population_2022) * 100000, n.revenue_per_100k_brazil) < 0.7 THEN 'fix_freight_or_delivery_first'
    WHEN SAFE_DIVIDE(b.conversion_rate, n.conversion_brazil) < 0.8 THEN 'traffic_without_conversion'
    ELSE 'mature'
  END AS recommendation,
  -- revenue if the state reached the national penetration (the size of the prize)
  GREATEST(0, n.revenue_per_100k_brazil * s.population_2022 / 100000 - b.revenue) AS gap_to_national_penetration_90d
FROM by_uf AS b
JOIN `your-gcp-project.ga4_seeds.seed_br_states` AS s ON s.uf = b.geo_uf
CROSS JOIN national AS n
ORDER BY gap_to_national_penetration_90d DESC;

-- top cities by revenue and the ones with traffic but no sales (delivery area? price?)
SELECT geo_uf, geo_city, COUNT(*) AS sessions, SUM(transactions) AS orders, SUM(revenue) AS revenue,
       SAFE_DIVIDE(SUM(transactions), COUNT(*)) AS conversion_rate
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY) AND NOT is_bot_suspect
  AND geo_country = 'Brazil' AND geo_city IS NOT NULL AND geo_city != '(not set)'
GROUP BY 1, 2
HAVING COUNT(*) >= 300
ORDER BY conversion_rate ASC
LIMIT 50;
