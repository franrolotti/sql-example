SET search_path TO jm, public;

-- 1) Candidates (~3k)
WITH c AS (
  SELECT gs AS candidate_id,
         (ARRAY['DE','ES','GB','FR','IT'])[(random()*4)::int+1] AS country,
         (CURRENT_DATE - ((random()*120)::int))::date           AS signup_date,
         (random()*15)::int AS experience_yrs,
         (ARRAY['nurse','caregiver','medical assistant','admin'])[(random()*3)::int+1] AS specialty
  FROM generate_series(1, 3000) gs
)
INSERT INTO candidates SELECT * FROM c;

-- 2) Employers (~300)
WITH e AS (
  SELECT gs AS employer_id,
         'Employer '||gs AS name,
         (ARRAY['DE','ES','GB','FR','IT'])[(random()*4)::int+1] AS country,
         (CURRENT_DATE - ((random()*365)::int))::date AS signup_date
  FROM generate_series(1, 300) gs
)
INSERT INTO employers SELECT * FROM e;

-- 3) Jobs (~2k) across employers
WITH j AS (
  SELECT gs AS job_id,
         ((random()*299)::int + 1) AS employer_id,
         (ARRAY['Registered Nurse','Caregiver','Clinic Admin','ICU Nurse','Home Care Nurse'])[(random()*4)::int+1] AS title,
         (ARRAY['nurse','caregiver','medical assistant','admin'])[(random()*3)::int+1] AS specialty,
         (ARRAY['Berlin','Munich','Hamburg','Madrid','Paris','Rome'])[(random()*5)::int+1] AS location,
         NOW() - ((random()*60*24*30)::int || ' minutes')::interval AS created_ts, -- ~last 30 days
         TRUE AS is_active,
         round((2400 + random()*2600)::numeric, 2) AS salary_eur
  FROM generate_series(1, 2000) gs
)
INSERT INTO jobs SELECT * FROM j;

-- 4) Employer plans + subscriptions (tiny)
INSERT INTO employer_plans(plan_id, plan_name, monthly_eur) VALUES
  (1,'Starter',199.00),
  (2,'Growth',499.00),
  (3,'Pro',999.00);

INSERT INTO employer_subscriptions(employer_id, plan_id, start_date)
SELECT employer_id,
       (ARRAY[1,2,3])[(random()*2)::int+1],
       (CURRENT_DATE - ((random()*120)::int))::date
FROM employers
WHERE random() < 0.7; -- ~70% subscribed

-- 5) Applications (~10k). 
WITH base AS (
  SELECT
    gs AS application_id,
    ((random()*1999)::int + 1) AS job_id,
    ((random()*2999)::int + 1) AS candidate_id,
    NOW() - ((random()*60*24*20)::int || ' minutes')::interval AS applied_ts, -- last ~20 days
    (ARRAY['submitted','contacted','interview','hired','rejected'])[
      CASE WHEN r < 0.65 THEN 1
           WHEN r < 0.78 THEN 2
           WHEN r < 0.90 THEN 3
           WHEN r < 0.94 THEN 4
           ELSE 5 END
    ] AS status,
    (ARRAY['organic','email','ad','referral'])[(random()*3)::int+1] AS source
  FROM (
    SELECT gs, random() AS r FROM generate_series(1, 10000) gs
  ) t
)
INSERT INTO applications
SELECT * FROM base;


TRUNCATE TABLE jm.events;

-- 6) Events (~60k job views; drop-off through the funnel)
WITH sessions AS (
  SELECT
    encode(gen_random_bytes(8),'hex')                 AS session_id,
    ((random()*2999)::int + 1)                        AS candidate_id,
    ((random()*1999)::int + 1)                        AS job_id,
    NOW() - ((random()*60*24*7)::int || ' minutes')::interval AS t0
  FROM generate_series(1, 60000)
),
views AS (
  SELECT
    'candidate'::text                                  AS user_type,
    s.candidate_id                                     AS user_id,
    s.session_id                                       AS session_id,
    s.t0                                               AS event_ts,
    'job_view'::text                                   AS event_name,
    s.job_id                                           AS job_id,
    jsonb_build_object('source',
      (ARRAY['organic','email','ad','referral'])[(random()*3)::int+1]) AS meta
  FROM sessions s
),
apply_start AS (
  -- ~40% start applying within 0–20 mins
  SELECT
    'candidate'::text                                  AS user_type,
    s.candidate_id                                     AS user_id,
    s.session_id                                       AS session_id,
    s.t0 + ((random()*20)::int || ' minutes')::interval AS event_ts,
    'apply_start'::text                                AS event_name,
    s.job_id                                           AS job_id,
    '{}'::jsonb                                        AS meta
  FROM sessions s
  WHERE random() < 0.40
),
submit AS (
  -- ~60% of starters submit within 0–30 mins
  SELECT
    'candidate'::text                                  AS user_type,
    a.user_id                                          AS user_id,
    a.session_id                                       AS session_id,
    a.event_ts + ((random()*30)::int || ' minutes')::interval AS event_ts,
    'application_submit'::text                         AS event_name,
    a.job_id                                           AS job_id,
    '{}'::jsonb                                        AS meta
  FROM apply_start a
  WHERE random() < 0.60
),
contact AS (
  -- ~35% of submitters get contacted within 30–240 mins (employer event)
  SELECT
    'employer'::text                                   AS user_type,
    j.employer_id::bigint                              AS user_id,
    s.session_id                                       AS session_id,
    s.event_ts + ((30 + (random()*210))::int || ' minutes')::interval AS event_ts,
    'employer_contact'::text                           AS event_name,
    s.job_id                                           AS job_id,
    '{}'::jsonb                                        AS meta
  FROM submit s
  JOIN jm.jobs j USING (job_id)
  WHERE random() < 0.35
)
INSERT INTO jm.events (user_type, user_id, session_id, event_ts, event_name, job_id, meta)
SELECT * FROM views
UNION ALL SELECT * FROM apply_start
UNION ALL SELECT * FROM submit
UNION ALL SELECT * FROM contact;
