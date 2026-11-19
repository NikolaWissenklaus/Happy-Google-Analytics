-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: banks, fintechs, credit cards, loans, insurance, telecom plans
-- nobody buys a loan in one click. The person simulates, leaves, compares, comes back, starts the
-- application, gets scared with the documents step and maybe finishes in the app three days later.
-- The questions: where the application dies, how many sessions the decision takes, which amount
-- scares people, which channel brings APPROVED customers (not simulations) and what each costs.
-- Set the event names below (the same of cfg_extras.banking if you turned the mart on).
-- With the mart on: ga4_funnels.fnl_banking_application_daily has query 1 ready, per day.

DECLARE simulate_event STRING DEFAULT 'simulation_complete';
DECLARE start_event STRING DEFAULT 'application_start';
DECLARE submit_event STRING DEFAULT 'application_submit';
DECLARE approved_event STRING DEFAULT 'application_approved';
DECLARE product_param STRING DEFAULT 'product_type';

-- 1) the funnel per product and device, people (not events), last 90 days
WITH steps AS (
  SELECT
    e.user_key,
    COALESCE((SELECT value.string_value FROM UNNEST(e.event_params) WHERE key = product_param), '(not set)') AS product,
    e.device_category,
    e.event_name
  FROM `your-gcp-project.ga4_core.fct_events` AS e
  WHERE e.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND e.event_name IN (simulate_event, start_event, submit_event, approved_event)
),
per_user AS (
  SELECT
    user_key,
    ARRAY_AGG(product ORDER BY IF(product = '(not set)', 1, 0) LIMIT 1)[OFFSET(0)] AS product,
    ANY_VALUE(device_category) AS device_category,
    LOGICAL_OR(event_name = simulate_event) AS simulated,
    LOGICAL_OR(event_name = start_event) AS started,
    LOGICAL_OR(event_name = submit_event) AS submitted,
    LOGICAL_OR(event_name = approved_event) AS approved
  FROM steps
  GROUP BY user_key
)
SELECT
  product,
  device_category,
  COUNTIF(simulated) AS simulated,
  COUNTIF(started) AS started,
  COUNTIF(submitted) AS submitted,
  COUNTIF(approved) AS approved,
  SAFE_DIVIDE(COUNTIF(started), COUNTIF(simulated)) AS simulate_to_start,
  SAFE_DIVIDE(COUNTIF(submitted), COUNTIF(started)) AS start_to_submit,
  SAFE_DIVIDE(COUNTIF(approved), COUNTIF(submitted)) AS approval_rate,
  -- people that skip the simulator are a different public (they already decided)
  SAFE_DIVIDE(COUNTIF(started AND NOT simulated), COUNTIF(started)) AS share_started_without_simulating
FROM per_user
GROUP BY 1, 2
HAVING COUNTIF(simulated OR started) >= 50
ORDER BY simulated DESC;

-- 2) how many sessions and days the decision takes (first simulation -> submit), per first channel
WITH firsts AS (
  SELECT
    user_key,
    MIN(IF(event_name = simulate_event, event_ts, NULL)) AS first_simulation_ts,
    MIN(IF(event_name = submit_event, event_ts, NULL)) AS first_submit_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
    AND event_name IN (simulate_event, submit_event)
  GROUP BY user_key
),
sessions_between AS (
  SELECT f.user_key, COUNT(DISTINCT s.session_key) AS sessions_to_decide
  FROM firsts AS f
  JOIN `your-gcp-project.ga4_core.fct_sessions` AS s
    ON s.user_key = f.user_key
    AND s.session_start_ts BETWEEN TIMESTAMP_SUB(f.first_simulation_ts, INTERVAL 30 MINUTE) AND f.first_submit_ts
  WHERE s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
    AND f.first_submit_ts > f.first_simulation_ts
  GROUP BY f.user_key
)
SELECT
  u.first_channel,
  COUNT(*) AS deciders,
  APPROX_QUANTILES(b.sessions_to_decide, 100)[OFFSET(50)] AS median_sessions_to_decide,
  APPROX_QUANTILES(TIMESTAMP_DIFF(f.first_submit_ts, f.first_simulation_ts, HOUR), 100)[OFFSET(50)] AS median_hours_to_decide,
  SAFE_DIVIDE(COUNTIF(b.sessions_to_decide = 1), COUNT(*)) AS share_decided_in_one_session
FROM firsts AS f
JOIN sessions_between AS b USING (user_key)
JOIN `your-gcp-project.ga4_core.dim_users` AS u USING (user_key)
GROUP BY 1
HAVING COUNT(*) >= 30
ORDER BY deciders DESC;
-- median of 4 sessions = the remarketing window matters more than the landing page

-- 3) the amount that scares: submit rate by simulated amount band (the 'value' param of the simulation)
WITH sims AS (
  SELECT
    user_key,
    MAX((SELECT COALESCE(value.double_value, CAST(value.int_value AS FLOAT64)) FROM UNNEST(event_params) WHERE key = 'value')) AS amount
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND event_name = simulate_event
  GROUP BY user_key
),
submits AS (
  SELECT DISTINCT user_key
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND event_name = submit_event
)
SELECT
  CASE
    WHEN s.amount IS NULL THEN '(no amount)'
    WHEN s.amount < 1000 THEN '01 < 1k'
    WHEN s.amount < 5000 THEN '02 1k-5k'
    WHEN s.amount < 20000 THEN '03 5k-20k'
    WHEN s.amount < 100000 THEN '04 20k-100k'
    ELSE '05 100k+'
  END AS amount_band,
  COUNT(*) AS simulators,
  COUNTIF(b.user_key IS NOT NULL) AS submitted,
  SAFE_DIVIDE(COUNTIF(b.user_key IS NOT NULL), COUNT(*)) AS submit_rate
FROM sims AS s
LEFT JOIN submits AS b USING (user_key)
GROUP BY 1
ORDER BY 1;

-- 4) the page where the application dies: last page of the sessions that started and did not submit
WITH started_not_submitted AS (
  SELECT session_key
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name IN (start_event, submit_event)
  GROUP BY session_key
  HAVING LOGICAL_OR(event_name = start_event) AND NOT LOGICAL_OR(event_name = submit_event)
)
SELECT
  pv.page_path AS exit_page,
  COUNT(*) AS dead_applications,
  AVG(pv.time_on_page_sec) AS avg_seconds_on_exit_page,
  AVG(pv.max_percent_scrolled) AS avg_scroll_on_exit_page,
  SAFE_DIVIDE(COUNTIF(pv.is_reload), COUNT(*)) AS reload_share
FROM `your-gcp-project.ga4_core.fct_page_views` AS pv
JOIN started_not_submitted USING (session_key)
WHERE pv.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND pv.is_exit
GROUP BY 1
ORDER BY dead_applications DESC
LIMIT 25;
-- "documentos" or "selfie" page on top with reloads = the upload is broken on some phones

-- 5) cost per APPROVED customer per campaign (the agency optimizes for simulations, finance pays for approvals)
WITH approvals AS (
  SELECT
    LOWER(COALESCE(session_campaign, '(not set)')) AS campaign,
    COUNT(DISTINCT user_key) AS approved_customers
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name = approved_event
  GROUP BY 1
),
simulations AS (
  SELECT LOWER(COALESCE(session_campaign, '(not set)')) AS campaign, COUNT(DISTINCT user_key) AS simulators
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name = simulate_event
  GROUP BY 1
),
costs AS (
  SELECT campaign, SUM(cost) AS cost
  FROM `your-gcp-project.ga4_core.fct_ad_costs_daily`
  WHERE cost_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY 1
)
SELECT
  c.campaign,
  c.cost,
  COALESCE(s.simulators, 0) AS simulators,
  COALESCE(a.approved_customers, 0) AS approved_customers,
  SAFE_DIVIDE(c.cost, s.simulators) AS cost_per_simulation,
  SAFE_DIVIDE(c.cost, a.approved_customers) AS cost_per_approved,
  SAFE_DIVIDE(a.approved_customers, s.simulators) AS simulation_to_approved,
  RANK() OVER (ORDER BY SAFE_DIVIDE(c.cost, s.simulators)) AS rank_by_cost_per_simulation,
  RANK() OVER (ORDER BY SAFE_DIVIDE(c.cost, a.approved_customers)) AS rank_by_cost_per_approved
FROM costs AS c
LEFT JOIN simulations AS s USING (campaign)
LEFT JOIN approvals AS a USING (campaign)
WHERE c.cost > 0
ORDER BY c.cost DESC;
-- the campaigns where the two ranks disagree are the conversation with the agency
