# Tools

Small, self-contained scripts for **planning and analysis** — not shipped
with the app.

## `ad_revenue_calculator.py`

Estimates monthly / annual ad revenue for MyTravelPal under different
assumptions. Calibrated for a Travel/Nav app in CH/FR/IT/ES (2025).

### Quick starts

```bash
# One of the three preset scenarios
python tools/ad_revenue_calculator.py --scenario conservative --mau 20000
python tools/ad_revenue_calculator.py --scenario moderate --mau 20000
python tools/ad_revenue_calculator.py --scenario aggressive --mau 100000

# Sensitivity table across MAU
python tools/ad_revenue_calculator.py --scenario moderate --sweep-mau

# Custom mix
python tools/ad_revenue_calculator.py --mau 50000 --sessions 4 \
    --formats banner,native --premium-conversion 0.03

# CH-heavy geo bumps eCPM 20 %
python tools/ad_revenue_calculator.py --scenario moderate --mau 20000 \
    --geo-multiplier 1.2
```

Run with `--help` for every flag.

### Parameters that move the needle

| Flag | Meaning | Typical range |
|---|---|---|
| `--mau` | Monthly active users (not downloads) | Depends on ambition |
| `--sessions` | Sessions per MAU / month. Nav apps are episodic | 3 – 8 |
| `--formats` | `banner,native,interstitial,rewarded,app_open` | 1 – 5 |
| `--ecpm-position` | 0 low, 0.5 mid, 1 high within each format's range | 0.25 – 0.75 |
| `--fill-rate` | AdMob + mediation typical | 0.88 – 0.97 |
| `--consent-penalty` | 1.0 = full personalized ads, 0.5 = half revenue lost to EU consent | 0.6 – 0.9 |
| `--premium-conversion` | Fraction of MAU on the ad-free tier | 0.005 – 0.05 |
| `--geo-multiplier` | Adjust eCPM for geo mix. CH-heavy > 1.0; ES/IT-heavy < 1.0 | 0.8 – 1.3 |

### Scenarios

- **conservative** — banner-only, low sessions, weak CMP, <1 % premium.
- **moderate** — banner + native + interstitial, decent sessions,
  2 % premium.
- **aggressive** — every format including app-open + rewarded, invested
  in CMP, 4 % premium.

Use them as anchors. Real numbers will land somewhere in between and
shift over time.

### Caveats worth knowing

- eCPMs are 2025 benchmarks for Travel/Nav in EU-4. They **will drift** —
  update the `FORMATS` dict at the top of the script when you have real
  post-launch data.
- The model assumes ads are eligible on every session. If you gate some
  screens (e.g. no ads during turn-by-turn), reduce `--sessions`
  proportionally.
- `--premium-conversion` reduces the ad-eligible base but does *not*
  add subscription revenue on top. Model that separately.
- Nothing here forecasts **downloads → MAU**. Marketing / retention are
  a whole other model.

## `subscription_revenue_calculator.py`

Estimates premium (ad-free) subscription revenue. Blends monthly and
annual pricing, accounts for Apple/Google store cut, intro discounts,
and churn.

```bash
python tools/subscription_revenue_calculator.py --scenario moderate --mau 20000
python tools/subscription_revenue_calculator.py --mau 50000 \
    --monthly-price 3.99 --annual-price 29.99 --annual-mix 0.55 \
    --churn 0.05 --store-cut 0.15
python tools/subscription_revenue_calculator.py --scenario aggressive --sweep-mau
```

Outputs gross monthly, net monthly (post-store), net annual, and
per-user LTV.

## `funnel_calculator.py`

End-to-end: monthly installs → activation → steady-state MAU → ad
revenue + subscription revenue. Composes the two calculators above.

```bash
python tools/funnel_calculator.py --installs 50000 --scenario moderate
python tools/funnel_calculator.py --installs 100000 \
    --scenario aggressive --geo-multiplier 1.15
python tools/funnel_calculator.py --scenario conservative --sweep-installs
```

Preset `--scenario` fixes funnel + ads + subs to the same tier;
override any of them with `--funnel`, `--ads`, `--subs`.

## Tests

```bash
backend/.venv/bin/pytest tools/ -q
```

68 tests total, covering pure math, validation, scenario ordering, and
CLI smoke for all three calculators.
