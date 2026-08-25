# Deploying the backend (Fly.io)

Deploys the FastAPI backend to a stable public HTTPS URL — but
**without exposing your source code** and **without letting strangers
use your compute**. This is Option C from
[apk_distribution.md](apk_distribution.md).

## What "not exposing" means here

Three levels of privacy, and how this setup handles each:

| Level | Concern | This setup |
|---|---|---|
| Source code | GitHub / other public git host | **Not required.** Fly deploys from the local `Dockerfile` via `fly deploy`. Your code stays on your machine. |
| Deployed binaries | Public API URL | Unavoidable — the URL has to exist so the APK can reach it. Fly gives it HTTPS automatically. |
| Random-stranger usage | Someone finds the URL and racks up your Anthropic / TollGuru bill | **API key gate**: the middleware in [app/api/api_key.py](../backend/app/api/api_key.py) requires `X-MyTravelPal-Api-Key` on every `/v1/*` request when `MYTRAVELPAL_API_KEY` is set. The APK carries the key; the internet doesn't. |

The key is baked into the APK bytecode via `--dart-define=API_KEY=…`.
Someone determined enough to reverse the APK can extract it — this is
a **rate-limit-by-obscurity** gate, not real per-user auth. For real
per-user protection, the JWT flow (already in place) is what matters.

## One-time setup

```bash
# 1. Install the Fly CLI (macOS/Linux)
curl -L https://fly.io/install.sh | sh

# 2. Sign up / log in
fly auth signup           # first time, or `fly auth login`

# 3. From the backend directory
cd backend

# 4. Bootstrap the app (creates the Fly app, DON'T let it overwrite fly.toml)
fly launch --no-deploy --copy-config

# 5. Generate + store secrets
fly secrets set \
    MYTRAVELPAL_API_KEY="$(openssl rand -hex 32)" \
    MYTRAVELPAL_JWT_SECRET="$(openssl rand -hex 32)"

# Optional real providers — set only the ones you have keys for
fly secrets set ANTHROPIC_API_KEY="sk-ant-..."     # AI narrative
fly secrets set TOLLGURU_API_KEY="..."             # Real toll pricing
fly secrets set GOOGLE_CLIENT_ID="...apps.googleusercontent.com"
fly secrets set FACEBOOK_APP_SECRET="..."
fly secrets set APPLE_APP_ID="com.mytravelpal.app"

# 6. Ship it
fly deploy
```

Fly prints the URL — something like `https://mytravelpal-api.fly.dev`.
Test it:

```bash
curl https://mytravelpal-api.fly.dev/health
# {"status":"ok"}
```

Confirm the gate works (this must fail):

```bash
curl -X POST https://mytravelpal-api.fly.dev/v1/trips/plan \
    -H "Content-Type: application/json" -d '{}'
# {"error":"api_key_required", ...}
```

## Retrieve the API key for the APK build

```bash
# Fly doesn't display secrets after set, so save it locally when you
# create it. If you lost it, rotate:
fly secrets set MYTRAVELPAL_API_KEY="$(openssl rand -hex 32)"
# then note the value BEFORE running the command (echo it first) or
# store it in your password manager.
```

Once you have the URL + key, build the APK:

```bash
cd mobile
flutter build apk --release --split-per-abi \
    --dart-define=API_BASE_URL=https://mytravelpal-api.fly.dev \
    --dart-define=API_KEY=<your-generated-key>
```

Family installs the APK → app talks to your fly.dev URL → API key
proves they're using your official APK.

## Free-tier costs

Fly's free tier at time of writing gives you:
- Up to 3 shared-CPU-1x machines with 256 MB RAM (we ask for 512 MB —
  one machine)
- Auto-sleep when idle (see `fly.toml`, `auto_stop_machines = "stop"`)
- Free HTTPS, free custom domain

Realistic usage for a handful of family testers: **€0/month**. If it
starts costing anything, `fly dashboard` shows the bill.

## Updating

Every time you change backend code:

```bash
cd backend
fly deploy
```

Every time you rotate a secret:

```bash
fly secrets set MYTRAVELPAL_API_KEY="$(openssl rand -hex 32)"
# then rebuild the APK with the new --dart-define=API_KEY
```

## Alternative: same recipe on Railway / Render / Hetzner

Every provider that accepts a `Dockerfile` works with this setup — the
API-key gate + secrets pattern is provider-agnostic. Fly is
recommended because deployment is `fly deploy` from your terminal,
without pushing to a git host. Railway needs a git repo (private is
fine). Render needs a git repo. A raw VPS (Hetzner €4/mo) needs manual
Docker + reverse proxy setup but gives you full control.

## What's NOT included

- **Custom domain** (`api.mytravelpal.app`). Buy one and `fly certs
  create api.mytravelpal.app` when you're ready. Until then, the
  `mytravelpal-api.fly.dev` URL works.
- **Backup / DB**. Nothing persists yet — user-marked adverse events
  and JWT-authenticated users' data live in-memory. When we add
  cloud sync of trips (see [`project_deferred_features`](../.claude/projects/-home-blu3-Apps-MyTravelPal/memory/project_deferred_features.md))
  we'll need Fly Postgres or an external Postgres.
- **Rate limiting** beyond the API key gate. If a real leak happens,
  add `slowapi` (FastAPI-native) or Cloudflare in front.
- **Deploy from CI** (GitHub Actions running `fly deploy` on push).
  Deferred until we set up a real repo.
