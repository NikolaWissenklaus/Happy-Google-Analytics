<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# insights

The models with the tag `insights`: one more floor on top of `labs` (docs/labs.md), `frontier`
(docs/frontier.md) and `attribution_extended` (docs/attribution_extended.md), organized by the
level of who asks. Some are the first table a junior analyst should open ("is the average session
lying to me?"), some are what a specialist would build in a notebook (Cox regression, synthetic
control, Bass diffusion, Louvain communities, Poisson bootstrap), here inside BigQuery, in SQL and
JS UDFs, on the same contract tables as the rest of the project.

Same rules as everything else: they read the core tables (and a few marts), drop bots with
`helpers.martSessionFilter()`, every knob lives in `includes/cfg_insights.js`, user level tables
live in personal data datasets (`ga4_segments`, `ga4_data_science`, `ga4_cro`) and every table has
a BigQuery label `level` (junior / mid / senior / specialist), so
`INFORMATION_SCHEMA.TABLE_OPTIONS` can list them by level.

## run it

| what | how |
|---|---|
| everything | `dataform run --tags insights` (the 12 new UDFs have the tag too) |
| schedule | 27 models are `daily` (2 of them need Search Console); 6 heavier ones are `weekly` (`prod_dwell_time_mixture`, `ds_bootstrap_channel_metrics`, `ds_second_purchase_cox`, `ds_feature_impact_cem`, `ecom_product_communities`, `ops_event_storage_footprint`): schedule the `weekly` tag on sunday even without `enable_bqml` |
| first run | the runbook's full refresh of everything, once: daily models read weekly ones (`biz_insights_feed`) |
| SEO | `seo_ctr_collapse` and `seo_query_intent` need `enable_search_console` (they compile out without it) |
| tests of the UDFs | `cd tools && node tests/test_insights_udfs.js ../definitions/01_udfs` (separate file, `npm run check` stays as it was) |
| assertions | `definitions/90_assertions/assertions_insights.js` (7 checks, tag `assertions`) |
| ready queries | `analyses/53_*.sql` to `analyses/70_*.sql` (`analyses/README.md`) |

The project now has 578 actions. On a slow or busy machine `dataform compile` can pass the 60s
default of the CLI: `dataform compile .. --timeout=3m` (same for `--json`).

## the ladder

### junior: the questions of the first weeks

| question | table | idea |
|---|---|---|
| Is the average session lying to me? | `prod_session_distribution_daily` | p10..p99 of engagement, views and events per day, device and channel, mean vs median |
| What is trend, what is weekday, what is noise? | `ds_kpi_decomposition` | centered moving average x weekday index x residual, seasonally adjusted value |
| Are we going to hit the target? | `biz_target_hit_probability` | month to date + weekday profile of the rest, P(month end >= target) |
| How do people move through the site? | `prod_flow_sankey` | edges `step k: type -> step k+1: type` ready for any Sankey chart |
| What should I read on monday? | `biz_insights_feed` | the other tables turned into ranked sentences per audience |

### mid: the analyst that already knows the basics

| question | table | idea |
|---|---|---|
| What was the visit FOR? | `prod_session_intent_taxonomy` | Broder's search taxonomy applied to sessions, plus later purchases of non buyers |
| How do PEOPLE (not sessions) go down the funnel? | `coh_user_funnel_by_cohort` | weekly acquisition cohorts, share reaching each step in 0 / 1 / 7 / 14 / 30 days |
| Can this page be A/B tested? | `cro_test_capacity_planner` | MDE in 14 / 28 / 56 days and days needed for +5 / 10 / 20% |
| Forecast without BQML? | `ds_kpi_forecast_holt_winters` | damped Holt-Winters with backtest and prediction intervals |
| Why did revenue move, branch by branch? | `biz_kpi_tree_weekly` | users x frequency x conversion x items x price, LMDI, WoW and YoY |
| Which products must never break, which to delist? | `ecom_abc_xyz_classification` | ABC by revenue x XYZ by demand variability + Syntetos-Boylan |
| Does the agency follow the naming convention? | `mkt_campaign_taxonomy` | utm_campaign split in fields, validated, performance by field |
| Does the landing page say what was searched? | `mkt_message_match` | share of the words of the term found on the landing page |
| Which campaign brings customers that pay back? | `mkt_cohort_roas_by_campaign` | ROAS D0 / D7 / D30 / D90 / D180 of the acquired users, payback day |
| Which customers are getting sick? | `seg_customer_health_score` | recency vs own rhythm, order and visit trends, friction, discount |
| Will the GA4 export stop? | `dq_export_limit_headroom` | events per day vs the 1M limit, trend, drop candidates |
| Who eats the bytes of the export? | `ops_event_storage_footprint` | logical bytes per event and param, GiB and USD per month |
| What do the organic searches want? | `seo_query_intent` | brand / navigational / transactional / commercial / informational / local |

### senior: the decision is on the table

| question | table | idea |
|---|---|---|
| Which funnel step broke this week? | `cro_funnel_weekly_step_changes` | weekly z tests vs baseline with Benjamini-Hochberg, revenue impact |
| Did the test work the same for everybody? | `cro_ab_test_segments` | effect per segment with q values and Cochran's Q heterogeneity |
| Where do buyers browse differently? | `prod_flow_divergence_buyers` | Jensen-Shannon divergence of the next step, buyers vs others |
| Which dimension explains the purchase? | `ds_conversion_drivers_information` | mutual information, Theil's U (Miller-Madow corrected), Cramer's V |
| What is the next real of media worth? | `mkt_spend_response_curves` | revenue = a + b ln(1 + spend), marginal ROAS, headroom |
| How should the same budget be split? | `mkt_budget_reallocation` | equalize the marginal ROAS (KKT) inside +-50% of the current spend |
| Which departments do the customers draw? | `ecom_product_communities` | Louvain communities of the co-view graph, misplaced products |
| Same ranking, fewer clicks? | `seo_ctr_collapse` | CTR collapse with stable position: AI Overviews and SERP features |

### specialist: what a data scientist would build

| question | table | idea |
|---|---|---|
| When did the level of each KPI change? | `ds_kpi_regimes` | PELT change points on the deseasonalized series, possible causes |
| Who reads and who skims each page? | `prod_dwell_time_mixture` | two component gaussian mixture on log(time on page) |
| Is this channel really better? | `ds_bootstrap_channel_metrics` | Poisson bootstrap by hash buckets, interval of the difference vs the site |
| What in the first order brings people back sooner? | `ds_second_purchase_cox` | Cox proportional hazards, hazard ratios adjusted for each other |
| Does the feature cause purchases? | `ds_feature_impact_cem` | coarsened exact matching, ATT vs naive difference |
| Did the regional campaign work? | `ds_geo_synthetic_control` | synthetic control state + placebo in space inference |
| How does each launch spread? | `ecom_launch_bass_diffusion` | Bass model: innovation p, imitation q, market m, peak |

## new functions in ga4_udf

| function | type | what |
|---|---|---|
| `pelt_changepoints(series, penalty_multiplier, min_segment_length)` | JS | regimes of a series (PELT, gaussian mean change, robust to one day outliers) |
| `holt_winters_forecast(series, season_length, horizon, holdout)` | JS | damped additive Holt-Winters, grid search, backtest, intervals |
| `gaussian_mixture_1d(sample_values, iterations)` | JS | two component mixture by EM, BIC 1 vs 2, separation, threshold |
| `fit_cox_ph(subjects, covariate_names, l2, iterations)` | JS | Cox regression, Breslow ties, Newton-Raphson, Harrell's C |
| `synthetic_control_weights(treated, donors, iterations)` | JS | donor weights on the simplex (FISTA + simplex projection) |
| `fit_bass_diffusion(adoptions, horizon)` | JS | Bass p, q, m by grid + Nelder-Mead, peak, forecast |
| `louvain_communities(edges, max_levels)` | JS | Louvain communities of a weighted graph + modularity |
| `inverse_normal_cdf(p)` | SQL | z of a probability (Acklam), the missing NORM.S.INV |
| `sample_size_proportions(baseline, relative_mde, alpha, power)` | SQL | units per variant for a two proportions test |
| `mde_proportions(baseline, n_per_group, alpha, power)` | SQL | relative minimum detectable effect of a test |
| `poisson_bootstrap_weight(unit_key, replicate)` | SQL | deterministic Poisson(1) weight for bootstrap in plain SQL |
| `token_overlap(text_a, text_b)` | SQL | Jaccard and coverage of words (accents and plurals handled) |

All of them work in any query of the analysts, not only in the pipeline (examples in
`analyses/58_can_we_test_this.sql`, `analyses/60_is_the_channel_really_better.sql`,
`analyses/70_analyst_training_exercises.sql`).

## the math, short

**Distributions.** `APPROX_QUANTILES(x, 100)` per day and segment, with the totals computed in the
same pass (percentiles can not be added later). `mean_to_median_ratio` above ~2 = a few long
sessions carry the mean.

**Intent.** Features per session (distinct products, page type counts, service pages by the post
purchase patterns of `cfg_labs`, cart / checkout / purchase flags) and an ordered list of SQL
conditions in the config, first match wins. `later_purchase_rate` = non buying sessions whose
`user_key` bought within `later_purchase_days`.

**Readers and skimmers.** `log(time on page + 0.5)` (TIMESTAMP_DIFF truncates seconds) of up to
`sample_per_page` views per page, EM for two gaussians. Two audiences when BIC(2) < BIC(1) - 10 and
Ashman's `D = sqrt(2) |mu1 - mu2| / sqrt(s1^2 + s2^2) >= 2`. The threshold is the point between
the means where `w1 N1 = w2 N2` (closed form of the quadratic). UA style time on page: the exit
view has none, so pages that are mostly exits are underrepresented.

**Flow divergence.** Only the moves before the first cart / checkout / thank you page. For each
page type, next step distributions `P` (buyers) and `Q` (others), `JSD = 1/2 KL(P||M) + 1/2
KL(Q||M)`, `M = (P + Q) / 2`, base 2 (0 to 1). Browsing moves (no decision, no exit) are measured
apart, otherwise the decision itself dominates.

**Funnel weekly.** Closed funnel over the `fct_sessions` flags. Baseline = pooled counts of the
`baseline_weeks` weeks before (RANGE windows on the day number, gaps do not shift it). z test vs
baseline, then Benjamini-Hochberg inside the week: `q(i) = min over j >= i of p(j) m / j`.
`revenue_impact = (rate - baseline) x entered x (baseline revenue of the sessions that passed /
sessions that passed)`.

**User funnel.** Cohort = `dim_users.first_seen_date` with a non bot session that day. Days to each
step = first session with the flag. A horizon is reported only when the youngest user of the week
lived it.

**Test capacity.** Sessions split 50/50, `n = daily x days / 2`. `sample_size_proportions`
(Fleiss, pooled under H0) and `mde_proportions` (its inverse by fixed point, tested to agree within
1%).

**A/B heterogeneity.** Effect per segment `d = p_t - p_c`, variance `p_t(1-p_t)/n_t + p_c(1-p_c)/n_c`,
fixed effect pooled `d* = sum(d/v) / sum(1/v)`, `Q = sum((d - d*)^2 / v)`, `df = segments - 1`,
`I^2 = (Q - df) / Q`. People exposed to more than one variant are left out.

**Regimes.** Weekday factor = mean of the weekday / mean of the KPI. PELT (Killick et al. 2012)
minimizes `sum cost + beta x segments` exactly, `beta = multiplier x 2 ln n`, cost = sum of squares
around the segment mean / sigma^2, sigma from the MAD of the first differences. Before the
segmentation each point is clipped to 3 sigma around the median of its neighbourhood (one outlier
day never becomes a regime). Means of the regimes are of the real values.

**Decomposition.** Multiplicative: `trend = centered 7 day MA`, `index(weekday) = mean(value /
trend)` normalized to average 1, `residual = value / (trend x index)`, robust z with the MAD.

**Holt-Winters.** Additive with damped trend; alpha / beta / gamma / phi by grid (about 1.5k
combinations) on the one step squared error after the first season. The last `holdout_days` are
forecast from the past (that is `holdout_mape`), then the model is refit on everything. Interval
multipliers `1 + sum c_j^2`, `c_j = a (1 + b (phi + ... + phi^j)) + g [j mod m = 0]` (Hyndman et
al. 2008, approximate with damping).

**Bootstrap.** Sessions hashed in `buckets` buckets, one Poisson(1) weight per bucket and replicate
(the same for every channel, so the difference channel - site is resampled consistently), percentile
intervals of `replicates` replicates. `bootstrap_to_normal_width` compares with the textbook
interval.

**Drivers.** `MI = sum p(d, y) log2(p(d, y) / (p(d) p(y)))`, Miller-Madow bias `(k - 1) / (2 n ln 2)`
removed, `U = MI / H(Y)`, `V = sqrt(chi2 / n)` (Y is binary). Values with fewer than
`min_sessions_per_value` sessions are grouped before (cardinality inflates MI).

**Cox.** Breslow partial likelihood, Newton-Raphson with step halving and a small L2, covariates
standardized inside and returned in the original units. Duration = days from the first to the
second purchase, censored at today or `max_followup_days`. Concordance on an even sample of 2000.
Proportional hazards is an assumption: a covariate whose effect fades in time gets an average
hazard ratio.

**CEM.** Strata = first channel x first device x tenure x sessions in the window x sessions before x
bought before. `ATT = sum_s (n_t,s / N_t) (y_t,s - y_c,s)` over strata with treated and controls,
`Var = sum_s (n_t,s / N_t)^2 (v_t,s / n_t,s + v_c,s / n_c,s)`. `selection_bias_removed = naive -
ATT`. Only observed confounders are matched.

**Synthetic control.** Every series divided by its own pre period mean. Weights `w >= 0, sum w = 1`
minimizing the pre period squared error (FISTA with the Euclidean projection on the simplex).
Placebo in space: each donor is treated as the test with the other donors; `p = (1 + #(ratio >=
treated ratio)) / (1 + placebos)`, ratio = post RMSPE / pre RMSPE.

**Bass.** `F(t) = (1 - e^-(p+q)t) / (1 + (q/p) e^-(p+q)t)`, weekly new adopters `= m (F(t) - F(t-1))`.
m by least squares for each (p, q), floored at the adopters seen (`m_at_lower_bound`). Peak at
`t* = ln(q/p) / (p + q)`.

**Communities.** Co-view pairs of sessions (at most `max_items_per_session` items), lift = `co x N
/ (n_a x n_b)`, only pairs with lift >= `min_lift`. Louvain (Blondel et al. 2008), weight =
co-sessions; modularity `Q = sum_c [L_c / m - (D_c / 2m)^2]`.

**ABC-XYZ.** A = items while the cumulative revenue share before them is below 80%. `cv` of the weekly
units with zero weeks included. Syntetos-Boylan: `ADI = weeks / weeks with sales` vs 1.32, `CV^2`
of the non zero weeks vs 0.49.

**Response curves.** OLS of daily revenue on `ln(1 + spend)`: `b = cov / var`, `t = b / sqrt((1 -
R^2) var(y) / ((n - 2) var(x)))`. Marginal ROAS `b / (1 + s)`. Budget split: `max sum b_i ln(1 +
s_i)` with `sum s_i = budget` gives `s_i = b_i / lambda - 1`, clipped to the bounds; lambda by a log
grid of `grid_points`.

**Cohort ROAS.** Revenue of the users acquired by the campaign up to day N after their first visit
(any channel, stitched user) over the cost of the campaign in the acquisition month (matched by
lower case name). Payback = first day the cumulative revenue x `assumed_gross_margin` >= cost.

**KPI tree.** `R = U x F x C x I x P` exactly. LMDI: `L = (R1 - R0) / (ln R1 - ln R0)`, effect of X =
`L ln(X1 / X0)`, the five effects add up to `R1 - R0` (an assertion checks it).

**Target probability.** Remaining days ~ independent normals with the mean and variance of the same
weekday in the last `history_weeks`, variance inflated by `variance_inflation` (good days come
together). `P = 1 - Phi((target - MTD - E) / sqrt(V))`.

**Health.** `recency = 100 exp(-max(0, days since last order / usual gap - 1))`, trends as `50 + 50
(a - b) / (a + b)`, friction from refunds and support / returns pages in the 30 days after the last
order. Weighted sum, bands and the component that costs the most weighted points.

**Export limit.** Exported rows per day = `SUM(duplicate_count)` of the daily shards (the export
counts the duplicates). OLS trend of the last `trend_days` days, crossing date = `(limit - last 7
days average) / slope`.

**Storage.** BigQuery logical size rules: STRING = 2 bytes + UTF-8 length, INT64 / FLOAT64 = 8,
NULL = 0. Params are exact from `stg_ga4__event_params`; the fixed columns and the items are an
estimate (`other_columns_bytes`, `item_row_bytes`).

**CTR collapse.** Query x page, last 28 days vs the same 28 days 52 weeks before and vs the 28 days
before. Collapse = position change <= `max_position_change`, impressions >= 80% of before, CTR down
>= `min_relative_ctr_drop`. `clicks_lost = impressions now x (CTR before - CTR now)`.

**Message match.** `coverage = shared words / words of the term`, words of 3+ letters, lower case,
no accents, final plural `s` removed (`token_overlap`). Reference = revenue per session of the fully
matched sessions of the same channel.

**Insights feed.** Each source table becomes sentences with a fixed rule and a priority (0-100):
data risks first (export limit), then targets in danger, broken funnel steps, forecast misses, at
risk customers, budget moves, regimes, the rest. Thresholds in `cfg_insights.insights_feed`.

## limits (honest)

- Validated like the rest: compile with every module off and on, every statement parsed with
  sqlglot (BigQuery dialect) and, for these models, every column reference resolved against the
  schemas of the upstream tables. The JS UDFs recover known parameters of simulated data in
  `tools/tests/test_insights_udfs.js`. Nothing here ran against a real export yet: read the first
  results with somebody that knows the store.
- Most models are observational. CEM, synthetic control and the response curves get closer to
  causal answers, they do not replace a holdout (`ga4_lifts`) or an A/B test (`ga4_cro`).
- Revenue is GA4 revenue (last non-direct click for the channel tables). With the CRM module the
  core already uses the paid status; media decisions should still be confirmed with the platforms.
- Consent mode: everything describes the people that accepted the cookies.
- The JS UDFs hold their input in memory: the models sample (`sample_per_page`, `max_subjects`,
  `max_items`) to stay well inside the BigQuery limits. Raise them with care.
