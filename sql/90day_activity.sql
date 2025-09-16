-- Daily activity metrics (new users/jobs/apps/hires) for a given window
-- Params: :start_date, :end_date
WITH params AS (
  SELECT
    COALESCE(CAST(:start_date AS timestamptz), now() - interval '90 days') AS start_ts,
    COALESCE(CAST(:end_date   AS timestamptz), now())                       AS end_ts
),
days AS (
  SELECT generate_series(
           date_trunc('day', (SELECT start_ts FROM params))::date,
           date_trunc('day', (SELECT end_ts   FROM params))::date,
           '1 day'::interval
         )::date AS d
),
c AS (
  SELECT signup_date::date AS d, COUNT(*) AS new_candidates
  FROM jm.candidates, params
  WHERE signup_date >= params.start_ts::date AND signup_date < params.end_ts::date
  GROUP BY 1
),
e AS (
  SELECT signup_date::date AS d, COUNT(*) AS new_employers
  FROM jm.employers, params
  WHERE signup_date >= params.start_ts::date AND signup_date < params.end_ts::date
  GROUP BY 1
),
j AS (
  SELECT date_trunc('day', created_ts)::date AS d, COUNT(*) AS new_jobs
  FROM jm.jobs, params
  WHERE created_ts >= params.start_ts AND created_ts < params.end_ts
  GROUP BY 1
),
a AS (
  SELECT date_trunc('day', applied_ts)::date AS d, COUNT(*) AS applications
  FROM jm.applications, params
  WHERE applied_ts >= params.start_ts AND applied_ts < params.end_ts
  GROUP BY 1
),
h AS (
  SELECT date_trunc('day', applied_ts)::date AS d, COUNT(*) AS hires
  FROM jm.applications, params
  WHERE status = 'hired'
    AND applied_ts >= params.start_ts AND applied_ts < params.end_ts
  GROUP BY 1
)
SELECT
  d.d,
  COALESCE(c.new_candidates, 0) AS new_candidates,
  COALESCE(e.new_employers, 0)  AS new_employers,
  COALESCE(j.new_jobs, 0)       AS new_jobs,
  COALESCE(a.applications, 0)   AS applications,
  COALESCE(h.hires, 0)          AS hires
FROM days d
LEFT JOIN c USING (d)
LEFT JOIN e USING (d)
LEFT JOIN j USING (d)
LEFT JOIN a USING (d)
LEFT JOIN h USING (d)
ORDER BY d;
