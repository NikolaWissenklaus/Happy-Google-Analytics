// author: Francisco Lucas / Nikola Wissenklaus / Chico

// UA content reports that are just a different cut of rpt_ua_all_pages_daily (views, no cost)

const schema = constants.SCHEMAS.reports_ua;

publish("rpt_ua_content_drilldown_daily", {
  type: "view",
  schema,
  description: "UA Behavior > Site Content > Content Drilldown: page path level 1 / 2 / 3 / 4 with pageviews, unique pageviews, avg time on page, bounce rate and % exit (sum the levels you need in the BI)",
  tags: ["reports", "ua_report", "daily"]
}).query(ctx => `
SELECT
  a.event_date,
  COALESCE(p.path_level_1, '/') AS page_path_level_1,
  p.path_level_2 AS page_path_level_2,
  p.path_level_3 AS page_path_level_3,
  p.path_level_4 AS page_path_level_4,
  SUM(a.pageviews) AS pageviews,
  SUM(a.unique_pageviews) AS unique_pageviews,
  SAFE_DIVIDE(SUM(a.time_on_page_sum_sec), SUM(a.pageviews) - SUM(a.exits)) AS avg_time_on_page_sec,
  SAFE_DIVIDE(SUM(a.bounces), SUM(a.entrances)) AS bounce_rate,
  SAFE_DIVIDE(SUM(a.exits), SUM(a.pageviews)) AS pct_exit
FROM ${ctx.ref("rpt_ua_all_pages_daily")} AS a
LEFT JOIN ${ctx.ref("dim_pages")} AS p USING (page_path)
GROUP BY 1, 2, 3, 4, 5`);

publish("rpt_ua_exit_pages_daily", {
  type: "view",
  schema,
  description: "UA Behavior > Site Content > Exit Pages: exits, pageviews and % exit per page and day",
  tags: ["reports", "ua_report", "daily"]
}).query(ctx => `
SELECT event_date, page_path, page_title, exits, pageviews, pct_exit
FROM ${ctx.ref("rpt_ua_all_pages_daily")}
WHERE exits > 0`);
