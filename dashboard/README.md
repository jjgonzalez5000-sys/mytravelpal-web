# MyTravelPal admin dashboard

Local Grafana container that reads Fly-hosted Postgres (`mytravelpal-db`)
through a `flyctl proxy` tunnel. Shows total users, weekly actives,
plans-per-user and the latest feedback / suggestions.

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

2. Start the Fly proxy in a separate terminal (leave running):

   ```bash
   flyctl proxy 5432 -a mytravelpal-db
   ```

3. `docker compose up -d` from `dashboard/` (or `make dashboard-up`
   from the repo root).

4. Open <http://localhost:3007> — login `admin` / `admin` (or your
   `GRAFANA_ADMIN_PASSWORD`). Force reset on first login.

5. Menu → Dashboards → Browse → **MyTravelPal Admin**.

## Notes

- The proxy tunnel isn't in the container so we don't have to embed
  the Fly token. Restarting Grafana without the proxy running just
  makes the panels error out until the tunnel comes back.
- `admin.json` under `grafana/dashboards/` is auto-provisioned on
  container boot. Edit the JSON to add panels, then re-`docker
  compose restart grafana` — or use the Grafana UI to edit and
  export the JSON back.
- Emails come from the `users` table (populated on OAuth callback
  since backend 0.2.11+15). Users that predate that release show
  up as `anon` in the tables until they re-authenticate.
