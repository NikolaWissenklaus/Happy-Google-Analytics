-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- the monday meeting in one query: biz_insights_feed turns the insights models into sentences

-- 1) the feed in the order to read it
SELECT insight_rank, area, audience, level, headline, detail, impact_value, priority_score, source_table
FROM `your-gcp-project.ga4_business.biz_insights_feed`
ORDER BY insight_rank;

-- 2) one feed per team (paste in the channel of each one)
SELECT area, ARRAY_AGG(CONCAT('- ', headline) ORDER BY insight_rank LIMIT 5) AS top_5
FROM `your-gcp-project.ga4_business.biz_insights_feed`
GROUP BY 1;

-- 3) a Slack / e-mail ready text of the top 10
SELECT STRING_AGG(CONCAT(CAST(insight_rank AS STRING), '. ', headline, '\n   ', detail), '\n' ORDER BY insight_rank) AS message
FROM `your-gcp-project.ga4_business.biz_insights_feed`
WHERE insight_rank <= 10;
