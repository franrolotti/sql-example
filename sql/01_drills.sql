-- Active jobs by country and specialty (+ optional filters)
-- Params (all optional):
--   :active_only, :min_created_ts, :country, :specialty, :min_salary, :max_salary
WITH base AS (
  SELECT
      e.country,
      COALESCE(j.specialty, 'unspecified') AS specialty,
      j.created_ts,
      j.is_active,
      j.salary_eur
  FROM jm.jobs j
  JOIN jm.employers e USING (employer_id)
  WHERE
    -- active_only: if NULL, keep both; if boolean, filter
    COALESCE(CAST(:active_only AS boolean), j.is_active) = j.is_active
    -- created_ts lower bound (NULL => no lower bound)
    AND j.created_ts >= COALESCE(CAST(:min_created_ts AS timestamptz), '-infinity'::timestamptz)
    -- country filter (NULL => no filter)
    AND ( CAST(:country   AS text) IS NULL OR e.country   = CAST(:country   AS text) )
    -- specialty filter (NULL => no filter)
    AND ( CAST(:specialty AS text) IS NULL OR j.specialty = CAST(:specialty AS text) )
    -- salary bounds (NULL => no bound)
    AND j.salary_eur >= COALESCE(CAST(:min_salary AS numeric), j.salary_eur)
    AND j.salary_eur <= COALESCE(CAST(:max_salary AS numeric), j.salary_eur)
)
SELECT
    country,
    specialty,
    COUNT(*)                           AS jobs,
    ROUND(AVG(salary_eur)::numeric, 2) AS avg_salary_eur
FROM base
GROUP BY country, specialty
ORDER BY jobs DESC, country, specialty;
