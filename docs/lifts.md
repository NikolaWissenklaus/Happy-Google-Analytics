<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# lifts

"It went up 20%" is not a lift. A lift is the difference against what would have happened
anyway. The project measures it in five ways, and `lift_registry` puts them together with an
`evidence_level` so nobody mixes a holdout with a before / after.

| evidence | lift_type | table | how |
|---|---|---|---|
| 1 | `ab_test` | `cro_ab_test_results` | randomized split of the site (cfg_experiments.js): z-test, Bayesian, SRM check |
| 1 | `activation_holdout` | `lift_activation_holdouts` | a random part of each audience / CRM trigger is never sent, compared with the treated part |
| 2 | `geo_experiment` | `ds_geo_experiment_did` | test UFs vs control UFs, difference in differences |
| 2 / 3 | `intervention` | `lift_interventions` | interrupted time series of a dated change, with a control series (2) or with the pre period trend (3) |
| 3 | `promotion` | `promo_calendar_lift` | baseline vs during vs after (pull forward) |
| - | behaviours | `lift_behaviors_adjusted` | association, adjusted by Mantel-Haenszel. Not causal, not in the registry |

## holdouts (the real thing)

`cfg_lifts.holdout`, OFF by default because it means not sending to some people:

1. Marketing agrees on the % (default 10% per audience and per CRM trigger, an audience can
   override with `holdout_pct` in `cfg_audiences.js`).
2. Set `enabled: true` and `start_date` = the day you turn it on.
3. From then on `act_audience_exports` and `act_crm_triggers` leave the holdout out. The split is
   deterministic (FARM_FINGERPRINT of program + user_key): the same person is always in the same
   group of the same program, no table to keep.
4. After `outcome_window_days`, `lift_activation_holdouts` compares the purchases of the treated
   and of the holdout of every program: absolute and relative lift, p value, incremental buyers
   and incremental revenue.

Before that date the holdout did not exist, so the cohorts before `start_date` are not used.

## interventions

Register the change in `cfg_lifts.interventions` (it can be in the past):

```js
{
  name: "one_page_checkout_mobile",
  description: "New one page checkout, mobile only",
  start_date: "2026-03-10", end_date: null,
  pre_days: 56, post_days: 28,
  metrics: ["conversion_rate", "revenue", "checkout_rate"],
  segment: { dimension: "device_category", value: "mobile" },   // optional: only this part changed
  control: { dimension: "device_category", value: "desktop" }   // optional: a part that did NOT change
}
```

- With `control`: counterfactual = control series x (treated / control of the same weekday in the
  pre period). Better, because it absorbs seasonality, campaigns and holidays that hit both.
- Without `control`: weekday level + linear trend of the pre period.
- `lift_interventions_daily` is the chart (actual vs counterfactual), `lift_interventions` the
  answer, with a verdict that also says when the pre period fit is too poor to trust (MAPE > 25%).
- The interval assumes independent days: treat the p value as optimistic. Two weeks of a clear
  effect in the chart are worth more than a p value.

## behaviours

`lift_behaviors_adjusted`: purchase rate of sessions that did X vs that did not, raw and adjusted by
device x new / returning x channel x landing page type (Mantel-Haenszel risk ratio, Greenland &
Robins interval). `confounding_ratio` far from 1 means the raw lift was mostly "who does this
already wanted to buy". Use it to choose what to A/B test, never as proof.
