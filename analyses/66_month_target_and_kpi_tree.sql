-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the two questions of every board meeting: are we going to hit the target, and why did revenue move?

-- 1) the chance of hitting each target of the month, and the effort still needed
SELECT kpi, target, month_to_date, projected_month_end, projected_low_80, projected_high_80, probability_of_hitting_target,
       needed_per_remaining_day, expected_per_remaining_day, extra_effort_needed, remaining_days
FROM `your-gcp-project.ga4_business.biz_target_hit_probability`
ORDER BY kpi;

-- 2) last week vs the week before and vs last year, split in the 5 branches of the revenue tree
SELECT comparison, revenue, base_revenue, revenue_change, revenue_change_pct,
       effect_users, effect_frequency, effect_conversion, effect_items_per_order, effect_price_per_item, biggest_driver
FROM `your-gcp-project.ga4_business.biz_kpi_tree_weekly`
WHERE segment = '(all)'
  AND week_start = (SELECT MAX(week_start) FROM `your-gcp-project.ga4_business.biz_kpi_tree_weekly`)
ORDER BY comparison;

-- 3) the trend of the branches YoY (12 weeks), for a stacked bar chart
SELECT week_start, effect_users, effect_frequency, effect_conversion, effect_items_per_order, effect_price_per_item, revenue_change
FROM `your-gcp-project.ga4_business.biz_kpi_tree_weekly`
WHERE segment = '(all)' AND comparison = 'yoy'
ORDER BY week_start;

-- 4) the same tree by device: is mobile growing by more people or by better conversion?
SELECT segment, comparison, revenue_change_pct, effect_users, effect_conversion, effect_price_per_item, biggest_driver
FROM `your-gcp-project.ga4_business.biz_kpi_tree_weekly`
WHERE segment != '(all)'
  AND week_start = (SELECT MAX(week_start) FROM `your-gcp-project.ga4_business.biz_kpi_tree_weekly`)
ORDER BY segment, comparison;
