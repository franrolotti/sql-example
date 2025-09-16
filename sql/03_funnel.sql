-- Funnel: distinct sessions by stage and conversion rates
-- Params: :start_ts, :end_ts
WITH params AS (
  SELECT
    COALESCE(CAST(:start_ts AS timestamptz), now() - interval '7 days') AS start_ts,
    COALESCE(CAST(:end_ts   AS timestamptz), now())                      AS end_ts
),
stage_sessions AS (
  SELECT e.event_name, e.session_id
  FROM jm.events e, params p
  WHERE e.event_ts >= p.start_ts
    AND e.event_ts <  p.end_ts
    AND e.event_name IN ('job_view','apply_start','application_submit','employer_contact')
),
dedup AS (
  SELECT event_name, session_id FROM stage_sessions GROUP BY 1,2
),
counts AS (
  SELECT event_name, COUNT(*)::bigint AS sessions
  FROM dedup
  GROUP BY 1
),
ordered AS (
  SELECT
    event_name,
    sessions,
    CASE event_name
      WHEN 'job_view'           THEN 1
      WHEN 'apply_start'        THEN 2
      WHEN 'application_submit' THEN 3
      WHEN 'employer_contact'   THEN 4
    END AS stage_order
  FROM counts
)
SELECT
  event_name AS stage,
  sessions,
  ROUND(100.0 * sessions / NULLIF((SELECT sessions FROM ordered WHERE stage_order = 1),0), 2) AS overall_rate_pct,
  ROUND(100.0 * sessions / NULLIF(LAG(sessions) OVER (ORDER BY stage_order),0),               2) AS step_rate_pct
FROM ordered
ORDER BY stage_order;
