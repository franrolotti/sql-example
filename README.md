# Job-Matching SQL Practice (Postgres + Docker)

Reproducible PostgreSQL environment modeling a **job-matching platform** (candidates, employers, jobs, applications) with an ecommerce-like funnel:
`job_view → apply_start → application_submit → employer_contact → hire`.

## 🚀 Quickstart

```bash
docker-compose up -d   # or: docker compose up -d (newer Docker)
```

Postgres

* Host: localhost, Port: 5432
* DB: practice
* User: admin
* Password: admin

pgAdmin

* URL: http://localhost:8080
* Email: example@gmail.com
* Password: admin


Init scripts run **once** (first boot of the volume). To rebuild from scratch:

```bash
docker-compose down -v && docker-compose up -d
```


Once containers are running, open a `psql` session:

```bash
docker exec -it pg-practice psql -U admin -d practice
```

## 🧪 Try these



```sql
-- Funnel conversion
\i sql/03_funnel.sql

-- Latest application per candidate
\i sql/02_windows.sql

-- Top employers by applications (14 days)
\i sql/01_drills.sql
```


## 📂 Structure

* `init/` – schema + synthetic seed data (auto-loaded)
* `data/` – optional CSVs (`events_sample.csv`)
* `sql/` – queries: drills, windows, funnel, 90-day activity

## 📊 Entities

* `jm.candidates`, `jm.employers`, `jm.jobs`
* `jm.applications` (status lifecycle)
* `jm.events` (job\_view/apply\_start/application\_submit/employer\_contact)
* Optional: `jm.employer_plans`, `jm.employer_subscriptions`



> Timezone is pinned to **Europe/Madrid** for consistent timestamps.


