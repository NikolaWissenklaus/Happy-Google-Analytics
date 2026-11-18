-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- how people move through the site: the Sankey, where buyers browse differently, and which pages are read

-- 1) the Sankey of the site (Looker Studio: Sankey community visualization, source = source_node,
--    target = target_node, metric = sessions). Change the segment to compare mobile x desktop or bought x did not
SELECT source_node, target_node, sessions, share_of_source, purchase_rate
FROM `your-gcp-project.ga4_product.prod_flow_sankey`
WHERE segment_type = 'all'
ORDER BY step, sessions DESC;

-- 2) the drop off of each step: where do the sessions leave?
SELECT source_node, sessions AS exits, share_of_source AS exit_share
FROM `your-gcp-project.ga4_product.prod_flow_sankey`
WHERE segment_type = 'all' AND is_exit_edge
ORDER BY exits DESC
LIMIT 20;

-- 3) the moves of the buyers: transitions much more common among the sessions that bought (before the cart)
SELECT from_type, to_type, lift_browsing, p_buyer_browsing, p_other_browsing, purchase_rate_of_sessions_with_move, site_purchase_rate
FROM `your-gcp-project.ga4_product.prod_flow_divergence_buyers`
WHERE device_category = '(all)' AND is_buyer_pattern
ORDER BY lift_browsing DESC
LIMIT 20;

-- 4) where buyers and non buyers browse the MOST differently (Jensen-Shannon divergence per page type)
SELECT DISTINCT device_category, from_type, jsd_browsing_moves, jsd_all_moves, buyer_decision_share, other_decision_share, other_exit_share
FROM `your-gcp-project.ga4_product.prod_flow_divergence_buyers`
WHERE device_category IN ('(all)', 'mobile', 'desktop')
ORDER BY jsd_browsing_moves DESC;

-- 5) pages with two audiences: few read, and the readers buy much more. Make them readable
SELECT page_path, page_type, timed_views, readers_share, skimmer_typical_sec, reader_typical_sec, reader_purchase_lift, page_reading_profile
FROM `your-gcp-project.ga4_product.prod_dwell_time_mixture`
WHERE has_two_audiences
ORDER BY timed_views * COALESCE(reader_purchase_lift, 1) DESC
LIMIT 30;
