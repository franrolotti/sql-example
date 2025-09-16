-- init/02_schema_jobmatch.sql
SET search_path TO jm, public;

-- Core entities
CREATE TABLE candidates (
  candidate_id   BIGINT PRIMARY KEY,
  country        TEXT NOT NULL,
  signup_date    DATE NOT NULL,
  experience_yrs INT  NOT NULL DEFAULT 0,
  specialty      TEXT NOT NULL  -- e.g. nurse, caregiver, admin
);

CREATE TABLE employers (
  employer_id BIGINT PRIMARY KEY,
  name        TEXT NOT NULL,
  country     TEXT NOT NULL,
  signup_date DATE NOT NULL
);

CREATE TABLE jobs (
  job_id        BIGINT PRIMARY KEY,
  employer_id   BIGINT NOT NULL REFERENCES employers(employer_id),
  title         TEXT   NOT NULL,
  specialty     TEXT   NOT NULL,   -- target profile
  location      TEXT   NOT NULL,
  created_ts    TIMESTAMPTZ NOT NULL,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  salary_eur    NUMERIC(12,2)
);

-- Applications as a first-class table 
CREATE TABLE applications (
  application_id BIGINT PRIMARY KEY,
  job_id         BIGINT NOT NULL REFERENCES jobs(job_id),
  candidate_id   BIGINT NOT NULL REFERENCES candidates(candidate_id),
  applied_ts     TIMESTAMPTZ NOT NULL,
  status         TEXT NOT NULL CHECK (status IN (
                  'submitted','contacted','interview','hired','rejected')),
  source         TEXT NOT NULL DEFAULT 'organic'  -- organic / email / ad / referral
);

-- Event tracking for user actions (candidates and employers)
-- Event names emulate an ecommerce funnel for job apps:
-- 'job_view' -> 'apply_start' -> 'application_submit' -> 'employer_contact'
CREATE TABLE events (
  user_type   TEXT NOT NULL CHECK (user_type IN ('candidate','employer')),
  user_id     BIGINT NOT NULL,     -- candidate_id or employer_id (depending on user_type)
  session_id  TEXT NOT NULL,
  event_ts    TIMESTAMPTZ NOT NULL,
  event_name  TEXT NOT NULL CHECK (event_name IN (
                'job_view','apply_start','application_submit','employer_contact')),
  job_id      BIGINT,              -- mainly for job-related events
  meta        JSONB DEFAULT '{}'::jsonb
);

-- Employer plans (catalog)
CREATE TABLE employer_plans (
  plan_id     BIGINT PRIMARY KEY,
  plan_name   TEXT NOT NULL,
  monthly_eur NUMERIC(10,2) NOT NULL
);

CREATE TABLE employer_subscriptions (
  employer_id BIGINT NOT NULL REFERENCES employers(employer_id),
  plan_id     BIGINT NOT NULL REFERENCES employer_plans(plan_id),
  start_date  DATE NOT NULL,
  end_date    DATE,
  PRIMARY KEY (employer_id, plan_id, start_date)
);

-- Helpful indexes
CREATE INDEX ON jobs(created_ts);
CREATE INDEX ON jobs(employer_id);
CREATE INDEX ON applications(candidate_id);
CREATE INDEX ON applications(job_id);
CREATE INDEX ON applications(status);
CREATE INDEX ON events(event_ts);
CREATE INDEX ON events(event_name);
CREATE INDEX ON events(user_type, user_id, event_ts);
CREATE INDEX ON events(job_id) WHERE job_id IS NOT NULL;
