<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# anomaly detection

Monday 9h, revenue of the weekend is down 30%. Was it the site, the tracking, the campaign, or
just a holiday? This layer answers that before somebody asks.

## the series

`anom_metric_series_daily`: every metric of `cfg_anomaly.js` (sessions, users, purchases,
revenue, conversion rate, add to cart rate, AOV...) per day and per breakdown (all, device,
channel, platform), long format. Bots are NOT removed here on purpose: a bot attack must show
up as an anomaly.

## 8 methods (+1)

| # | table | method | good for |
|---|---|---|---|
| 1 | `anom_zscore` | z-score vs the previous 28 days | big, sudden spikes |
| 2 | `anom_same_weekday` | z-score vs the same weekday of 8 weeks | weekly seasonality (most e-commerce) |
| 3 | `anom_mad` | modified z-score, median and MAD (Iglewicz & Hoaglin) | series with outliers in the history |
| 4 | `anom_iqr` | Tukey fences (Q1 - 1.5 IQR, Q3 + 1.5 IQR) | skewed metrics, revenue |
| 5 | `anom_ewma` | EWMA forecast +- L sigma | trending series |
| 6 | `anom_cusum` | two sided tabular CUSUM | small persistent shifts (-8% for 10 days) |
| 7 | `anom_spc_nelson_rules` | Nelson rules (SPC) | patterns: 9 in a row on one side, trends |
| 8 | `anom_level_shift` | Welch t test, last 7 vs 28 days before | change points (new level after a deploy) |
| + | `ds_kpi_forecast_anomalies` | BQML ARIMA_PLUS with BR holidays (`enable_bqml`) | everything above, with a real forecast |

## the judge: anom_ensemble

One method alone gives too many false alarms. The ensemble counts the votes of every method and
raises an alert only when enough of them agree. Holidays and retail dates (`dim_calendar`:
Black Friday, Dia das Mães, salary days...) need more votes, so the Black Friday spike is not an
incident. Severity comes from the votes and the size of the deviation.

## root cause: anom_root_cause

For every alert of an additive metric, it splits the change by each dimension of
`cfg_anomaly.root_cause_dimensions` (browser, device, channel, UF, landing page type, app
version...) against the same weekday of the 4 weeks before, and ranks the values that explain the
change. "Revenue -32%: 71% of the drop is device_browser = Safari" is way more useful than
"revenue -32%".

## the alert

`anom_alert_feed` has one human message per alert of the last 3 days. `tools/alerts/send_alerts.py`
sends them (Slack, Google Chat, Teams, e-mail) and remembers what was sent:

```
pip install google-cloud-bigquery
export SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
python tools/alerts/send_alerts.py --project my-project --sources anomalies,changes,lgpd --dry-run
```

With `include_intraday`, `anom_hourly_intraday` + the `hourly` tag compares today hour by hour
with the same hour of the same weekday. The checkout broke at 10h, you know at 11h.

## tuning

- Too many alerts: raise `ensemble_min_votes` (and `ensemble_min_votes_on_special_days`) in `cfg_anomaly.js`, or remove breakdowns that are too small
  (a channel with 30 sessions a day is noise).
- Missed something real: look at which methods flagged it in `anom_ensemble.methods_flagged`. If
  only CUSUM / level shift saw it, it was a slow drift: lower the vote threshold for those metrics.
- Every method keeps its own table, so you can always see why it voted.
