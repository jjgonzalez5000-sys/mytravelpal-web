# MyTravelPal admin dashboard

Local Grafana container that reads Fly-hosted Postgres (`mytravelpal-db`)
through a `flyctl proxy` tunnel that runs in the same compose stack
(service `fly-proxy`). Shows total users, weekly actives,
plans-per-user and the latest feedback / suggestions.

## Quick start (after the first-time setup below)

```bash
make dashboard-up      # Grafana + the database tunnel, one command
# open http://localhost:3007  ->  Dashboards -> Browse -> MyTravelPal Admin
make dashboard-logs    # follow both containers
make dashboard-down    # stop everything
```

## First-time setup

1. Copy the env template and fill in the Postgres credentials:

   ```bash
   cp dashboard/.env.example dashboard/.env
   ```

   Grab the DB creds with:

   ```bash
   flyctl postgres users list -a mytravelpal-db
   flyctl secrets list -a mytravelpal-db
   ```

   Paste `PG_USER` and `PG_PASSWORD` into `dashboard/.env`.
   `PG_DATABASE` is the database name inside Postgres (usually
   `mytravelpal_api`; confirm with `flyctl ssh console -a mytravelpal-db`
   then `psql -l` if unsure).

2. Create a Fly token for the tunnel and put it in `dashboard/.env` as
   `FLY_API_TOKEN` (the file is gitignored):

   ```bash
   flyctl tokens create deploy -a mytravelpal-db
   ```

   If the proxy container then logs that it is not authorised for the
   app, create an org token instead (`flyctl tokens create org`).

3. `make dashboard-up` from the repo root (or `docker compose up -d`
   from `dashboard/`). This starts Grafana and the tunnel together.

4. Open <http://localhost:3007> — login `admin` / `admin` (or your
   `GRAFANA_ADMIN_PASSWORD`). Force reset on first login.

5. Menu → Dashboards → Browse → **MyTravelPal Admin**.

## Notes

- The tunnel runs as its own container (`mytravelpal-db-proxy`) and
  binds loopback only, so the database is not exposed to the LAN. It
  needs a Fly token in `dashboard/.env`; treat that file as a secret.
  Do not also run `flyctl proxy 5432` on the host: both would bind the
  same port.
- If the panels show connection errors, check the tunnel first:
  `docker logs mytravelpal-db-proxy`.
- `admin.json` under `grafana/dashboards/` is auto-provisioned on
  container boot. Edit the JSON to add panels, then re-`docker
  compose restart grafana` — or use the Grafana UI to edit and
  export the JSON back.
- Emails come from the `users` table (populated on OAuth callback
  since backend 0.2.11+15). Users that predate that release show
  up as `anon` in the tables until they re-authenticate.
