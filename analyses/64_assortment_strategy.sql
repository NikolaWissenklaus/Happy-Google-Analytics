-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the assortment with supply chain, network science and diffusion models, all from GA4

-- 1) the ABC x XYZ matrix of the catalog (count and revenue per cell)
SELECT abc_class, xyz_class, COUNT(*) AS items, SUM(revenue) AS revenue, ANY_VALUE(suggested_policy) AS policy
FROM `your-gcp-project.ga4_ecommerce.ecom_abc_xyz_classification`
GROUP BY 1, 2
ORDER BY 1, 2;

-- 2) big and unpredictable, but the interest is stable: a stock / price problem, not a demand problem
SELECT item_name, item_category, revenue, cv_weekly_units, cv_weekly_views, demand_pattern, suggested_policy
FROM `your-gcp-project.ga4_ecommerce.ecom_abc_xyz_classification`
WHERE abc_class = 'A' AND stable_interest_unstable_sales
ORDER BY revenue DESC;

-- 3) the departments the customers draw: communities of products viewed together
SELECT community_name, community_size, dominant_category, community_purity, categories_in_community, ARRAY_TO_STRING(top_items_of_community, ' | ') AS top_items
FROM `your-gcp-project.ga4_ecommerce.ecom_product_communities`
WHERE item_id = community
ORDER BY community_view_sessions DESC
LIMIT 30;

-- 4) products shopped with another category (check the menu, the filters and the cross sell)
SELECT item_name, item_category, dominant_category AS shopped_with, community_name, community_purity, view_sessions
FROM `your-gcp-project.ga4_ecommerce.ecom_product_communities`
WHERE is_misplaced
ORDER BY view_sessions DESC
LIMIT 50;

-- 5) the launches: who spreads by word of mouth, who needs media, where each one is in its life
SELECT item_name, metric, launch_date, weeks_observed, adopters_total, p_innovation, q_imitation, q_over_p, market_size,
       share_of_market_reached, peak_date, phase, diffusion_type, next_weeks_adopters_total
FROM `your-gcp-project.ga4_ecommerce.ecom_launch_bass_diffusion`
WHERE metric = 'buyers'
ORDER BY launch_date DESC;
