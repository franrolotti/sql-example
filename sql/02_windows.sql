-- 7-day moving average of application submissions per day (in a date range)
-- Params: :start_date, :end_date
WITH params AS (
  SELECT
    CAST(:start_date AS timestamptz) AS start_ts,
    CAST(:end_date   AS timestamptz) AS end_ts
),
daily AS (
  SELECT
      date_trunc('day', applied_ts)::date AS d,
      COUNT(*) AS submits
  FROM jm.applications, params p
  WHERE status IN ('submitted','contacted','interview','hired','rejected')
    AND applied_ts >= COALESCE(p.start_ts, '1900-01-01'::timestamptz)
    AND applied_ts <  COALESCE(p.end_ts,   now())
  GROUP BY 1
)
SELECT
    d,
    submits,
    AVG(submits) OVER (ORDER BY d ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS submits_ma7
FROM daily
ORDER BY d;
