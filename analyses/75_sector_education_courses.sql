-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- SECTOR: universities, online courses, language schools, bootcamps, prep courses (vestibular, concursos)
-- the decision is long, seasonal (enrollment windows) and very sensitive to payday. The questions:
-- which course pages create leads that enroll, how the enrollment season builds, which content
-- (blog, free class, simulator of fees) helps, and when to call the lead.
-- Leads = generate_lead (or your form event), enrollment = purchase (or your enrollment event).

DECLARE lead_event STRING DEFAULT 'generate_lead';
DECLARE enroll_event STRING DEFAULT 'purchase';

-- 1) course page -> lead -> enrollment, per course (the course is the first path level after /cursos/)
WITH course_views AS (
  SELECT
    user_key,
    REGEXP_EXTRACT(page_path, r'^/(?:cursos?|graduacao|pos|curso)/([^/]+)') AS course,
    MIN(event_ts) AS first_view_ts
  FROM `your-gcp-project.ga4_core.fct_page_views`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
  GROUP BY 1, 2
),
leads AS (
  SELECT user_key, MIN(event_ts) AS lead_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND event_name = lead_event
  GROUP BY 1
),
enrolls AS (
  SELECT user_key, MIN(event_ts) AS enroll_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND event_name = enroll_event
  GROUP BY 1
)
SELECT
  c.course,
  COUNT(*) AS visitors,
  COUNTIF(l.lead_ts >= c.first_view_ts) AS leads,
  COUNTIF(e.enroll_ts >= c.first_view_ts) AS enrollments,
  SAFE_DIVIDE(COUNTIF(l.lead_ts >= c.first_view_ts), COUNT(*)) AS visitor_to_lead,
  SAFE_DIVIDE(COUNTIF(e.enroll_ts >= c.first_view_ts), COUNTIF(l.lead_ts >= c.first_view_ts)) AS lead_to_enrollment,
  APPROX_QUANTILES(IF(e.enroll_ts >= l.lead_ts, TIMESTAMP_DIFF(e.enroll_ts, l.lead_ts, DAY), NULL), 100 IGNORE NULLS)[OFFSET(50)] AS median_days_lead_to_enroll
FROM course_views AS c
LEFT JOIN leads AS l USING (user_key)
LEFT JOIN enrolls AS e USING (user_key)
WHERE c.course IS NOT NULL
GROUP BY 1
HAVING COUNT(*) >= 100
ORDER BY enrollments DESC;
-- a course with many leads and low lead_to_enrollment: the price or the modality surprises in the call

-- 2) the enrollment season: weekly leads and enrollments with the same week of last year
WITH weekly AS (
  SELECT
    DATE_TRUNC(event_date, WEEK(MONDAY)) AS week_start,
    COUNT(DISTINCT IF(event_name = lead_event, user_key, NULL)) AS leads,
    COUNT(DISTINCT IF(event_name = enroll_event, user_key, NULL)) AS enrollments
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 400 DAY)
    AND event_name IN (lead_event, enroll_event)
  GROUP BY 1
)
SELECT
  w.week_start,
  w.leads,
  w.enrollments,
  ly.leads AS leads_last_year,
  ly.enrollments AS enrollments_last_year,
  SAFE_DIVIDE(w.leads, ly.leads) - 1 AS leads_yoy,
  SAFE_DIVIDE(w.enrollments, ly.enrollments) - 1 AS enrollments_yoy
FROM weekly AS w
LEFT JOIN weekly AS ly ON ly.week_start = DATE_SUB(w.week_start, INTERVAL 52 WEEK)
WHERE w.week_start >= DATE_SUB(CURRENT_DATE(), INTERVAL 26 WEEK)
ORDER BY w.week_start;

-- 3) the content that helps: pages seen by enrolled people BEFORE the enrollment vs by leads that did not enroll
WITH enrolled AS (
  SELECT user_key, MIN(event_ts) AS enroll_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY) AND event_name = enroll_event
  GROUP BY 1
),
lead_only AS (
  SELECT DISTINCT l.user_key
  FROM `your-gcp-project.ga4_core.fct_events` AS l
  LEFT JOIN enrolled AS e USING (user_key)
  WHERE l.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY) AND l.event_name = lead_event AND e.user_key IS NULL
),
pages AS (
  SELECT pv.page_path, pv.user_key, 'enrolled' AS grp
  FROM `your-gcp-project.ga4_core.fct_page_views` AS pv
  JOIN enrolled AS e ON e.user_key = pv.user_key AND pv.event_ts < e.enroll_ts
  WHERE pv.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
  UNION ALL
  SELECT pv.page_path, pv.user_key, 'lead_only'
  FROM `your-gcp-project.ga4_core.fct_page_views` AS pv
  JOIN lead_only USING (user_key)
  WHERE pv.event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
),
sizes AS (
  SELECT
    (SELECT COUNT(*) FROM enrolled) AS enrolled_users,
    (SELECT COUNT(*) FROM lead_only) AS lead_only_users
)
SELECT
  page_path,
  SAFE_DIVIDE(COUNT(DISTINCT IF(grp = 'enrolled', user_key, NULL)), ANY_VALUE(sz.enrolled_users)) AS reach_enrolled,
  SAFE_DIVIDE(COUNT(DISTINCT IF(grp = 'lead_only', user_key, NULL)), ANY_VALUE(sz.lead_only_users)) AS reach_lead_only,
  SAFE_DIVIDE(
    SAFE_DIVIDE(COUNT(DISTINCT IF(grp = 'enrolled', user_key, NULL)), ANY_VALUE(sz.enrolled_users)),
    SAFE_DIVIDE(COUNT(DISTINCT IF(grp = 'lead_only', user_key, NULL)), ANY_VALUE(sz.lead_only_users))
  ) AS enrollment_index
FROM pages
CROSS JOIN sizes AS sz
GROUP BY page_path
HAVING COUNT(DISTINCT user_key) >= 50
ORDER BY enrollment_index DESC
LIMIT 40;
-- "valor da mensalidade", "bolsas", "FIES", "free class" with index 2+: put them in the lead nurturing emails

-- 4) when to call: enrollment rate by hours between the lead and the next session of the person
WITH leads AS (
  SELECT user_key, session_key, MIN(event_ts) AS lead_ts
  FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    AND event_name = lead_event
  GROUP BY 1, 2
),
came_back AS (
  SELECT l.user_key, l.lead_ts, MIN(s.session_start_ts) AS next_session_ts
  FROM leads AS l
  LEFT JOIN `your-gcp-project.ga4_core.fct_sessions` AS s
    ON s.user_key = l.user_key AND s.session_start_ts > l.lead_ts AND s.session_key != l.session_key
    AND s.session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY)
  GROUP BY 1, 2
),
enrolls AS (
  SELECT DISTINCT user_key FROM `your-gcp-project.ga4_core.fct_events`
  WHERE event_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 120 DAY) AND event_name = enroll_event
)
SELECT
  CASE
    WHEN c.next_session_ts IS NULL THEN '5 never came back'
    WHEN TIMESTAMP_DIFF(c.next_session_ts, c.lead_ts, HOUR) < 2 THEN '1 < 2h'
    WHEN TIMESTAMP_DIFF(c.next_session_ts, c.lead_ts, HOUR) < 24 THEN '2 same day'
    WHEN TIMESTAMP_DIFF(c.next_session_ts, c.lead_ts, DAY) < 7 THEN '3 within the week'
    ELSE '4 later'
  END AS came_back,
  COUNT(*) AS leads,
  SAFE_DIVIDE(COUNTIF(e.user_key IS NOT NULL), COUNT(*)) AS enrollment_rate
FROM came_back AS c
LEFT JOIN enrolls AS e USING (user_key)
GROUP BY 1
ORDER BY 1;
-- leads that come back in 2h are comparing schools right now: that is the call queue priority
