-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the naming convention of the campaigns as data, and the ads that send people to the wrong page

-- 1) compliance of the convention (cfg_insights.campaign_taxonomy) in the last 90 days
SELECT campaigns, sessions, compliant_session_share, revenue, cost, roas
FROM `your-gcp-project.ga4_marketing.mkt_campaign_taxonomy`
WHERE row_type = 'summary';

-- 2) the campaigns out of the convention, with what is wrong (send to the agency)
SELECT campaign, sessions, revenue, cost, ARRAY_TO_STRING(problems, ', ') AS problems, ARRAY_TO_STRING(source_mediums, ', ') AS source_mediums
FROM `your-gcp-project.ga4_marketing.mkt_campaign_taxonomy`
WHERE row_type = 'campaign' AND NOT is_compliant
ORDER BY sessions DESC;

-- 3) performance by field of the name: objective, funnel stage, audience, offer... no spreadsheet needed
SELECT field_name, field_value, campaigns, sessions, conversion_rate, revenue, cost, roas
FROM `your-gcp-project.ga4_marketing.mkt_campaign_taxonomy`
WHERE row_type = 'field_value'
ORDER BY field_name, revenue DESC;

-- 4) message match: does the conversion fall when the landing page does not mention the search?
SELECT channel, match_bucket, sessions, engagement_rate, conversion_rate, revenue_per_session, reference_revenue_per_session
FROM `your-gcp-project.ga4_marketing.mkt_message_match`
WHERE row_type = 'bucket'
ORDER BY channel, match_bucket;

-- 5) the keyword x landing page pairs to fix first (traffic, bad match, money on the table)
SELECT term, landing_page_path, landing_page_title, sessions, term_coverage, conversion_rate, revenue_opportunity
FROM `your-gcp-project.ga4_marketing.mkt_message_match`
WHERE row_type = 'term_page' AND term_coverage < 0.5
ORDER BY revenue_opportunity DESC
LIMIT 50;
