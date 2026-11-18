-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SEO when the ranking does not move and the clicks disappear (needs enable_search_console)

-- 1) the pages that lost the most clicks with the same ranking, against last year
SELECT page_path, ANY_VALUE(page_clicks_lost) AS clicks_lost, ANY_VALUE(page_collapsed_queries) AS collapsed_queries
FROM `your-gcp-project.ga4_seo.seo_ctr_collapse`
WHERE base_period = 'last_year' AND is_ctr_collapse
GROUP BY 1
ORDER BY clicks_lost DESC
LIMIT 30;

-- 2) the collapsed queries with the details (position kept, impressions kept, CTR gone)
SELECT query, query_intent, page_path, impressions_now, impressions_before, position_now, position_before, ctr_now, ctr_before, clicks_lost
FROM `your-gcp-project.ga4_seo.seo_ctr_collapse`
WHERE base_period = 'last_year' AND is_ctr_collapse
ORDER BY clicks_lost DESC
LIMIT 100;

-- 3) which intents suffer: informational queries are the first ones eaten by AI answers
SELECT query_intent, base_period, COUNT(*) AS pairs, COUNTIF(is_ctr_collapse) AS collapsed, SUM(clicks_lost) AS clicks_lost
FROM `your-gcp-project.ga4_seo.seo_ctr_collapse`
GROUP BY 1, 2
ORDER BY 2, clicks_lost DESC;

-- 4) the demand by intent month by month (the content plan starts here)
SELECT month, intent, queries, impressions, clicks, ctr, avg_position, click_share_of_month, ctr_change_vs_previous_month
FROM `your-gcp-project.ga4_seo.seo_query_intent`
ORDER BY month DESC, clicks DESC;
