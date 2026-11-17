<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# labs

The models with the tag `labs`: things the GA4 export can answer and no GA4 report ever will.
They live in the dataset of their area (a `prod_` model is in `ga4_product`, and so on), follow
the same rules of the rest of the project and only read the contract tables. Every knob is in
`includes/cfg_labs.js`.

Run them alone with `dataform run --tags labs` (after the daily run, they depend on core).

## what is here

| question | table | idea |
|---|---|---|
| Which pages hold the site together? | `prod_internal_pagerank` | PageRank over the real navigation (`ga4_udf.pagerank`) |
| How much is each step of the journey worth? | `prod_journey_state_values` | absorbing Markov chain: P(purchase) of being in each page type |
| How many simultaneous users at the peak? | `prod_traffic_load_profile` | busiest minute of each day, percentiles, peak / median |
| How many sessions are one visit cut in two? | `prod_session_timeout_splits` | sessions resumed after the 30 minute timeout |
| Which words mean the same for my customers? | `prod_search_reformulations` | consecutive searches without a click = synonym / typo pairs |
| What happens after the thank you page? | `prod_post_purchase_behavior` | tracking, support and return page visits per order |
| Who has a habit, and who just broke it? | `seg_visit_rhythm` | burstiness, streaks, trend, expected next visit |
| Do prices ending in ,90 sell more here? | `ecom_price_ending_psychology` | cart rate by price ending inside price bands |
| Which product deserves a better position? | `ecom_list_position_bias` | clicks over expected clicks (COEC) |
| Who steals the sale from whom? | `ecom_item_switching` | viewed A, bought B: substitutes and trade up / down |
| Where does the freight kill the checkout? | `ecom_freight_shock` | death at the shipping step by UF and cart value |
| When will this customer need it again? | `ecom_replenishment_cycles` | repurchase cycle per item / category, customers due now |
| What is rising before the revenue shows it? | `ecom_item_momentum` | life cycle by views, hidden gems, traffic eaters |
| How many "users" are a new cookie of somebody? | `mkt_cookie_churn_inflation` | cookies per logged in person, per browser |
| Where does each channel send people next? | `mkt_channel_return_matrix` | channel of the next session, or no return |
| What was that spike at 21h? | `mkt_traffic_bursts` | minute level bursts per channel with probable cause |
| What do in-app browsers cost me? | `mkt_in_app_browser_gap` | conversion gap of webviews against real browsers |
| How big is the audience I never see? | `biz_market_size_capture_recapture` | Chapman capture-recapture between months |
| Did conversion change, or the mix? | `biz_simpson_paradox_watch` | exact mix / rate split, paradox alarm |
| Is this rate real or luck? | `cro_empirical_bayes_rates` | beta-binomial shrinkage with a learned prior |
| Can I stop this test today? | `cro_ab_test_sequential` | always valid p value (`ga4_udf.msprt_p_value`) |
| Can the test end sooner? | `cro_ab_test_cuped` | CUPED variance reduction with pre exposure behaviour |
| What is the real unit of a purchase decision? | `ds_shopping_missions` (+ `_summary`) | sessions glued in missions, closed by the purchase |
| Which orders deserve a second look? | `ds_order_risk_signals` | behaviour signals before the payment, 0-100 score |
| Was the site (or the tag) down? | `dq_tracking_blackouts` | silent minutes against the usual hour of the week |
| Why does BigQuery not match the GA4 screen? | `dq_ui_vs_bigquery_explainer` | size of each known cause per day |
| What is in our query strings? | `gov_url_parameter_inventory` | every url parameter, classified |

## the math, short

**PageRank** (`pagerank` UDF). `r = (1 - d) / n + d * (M r + dangling / n)`, `d = 0.85`, edges weighted
by the number of navigations. Only the `max_pages` most viewed pages enter (JS UDF memory). Compare
`pagerank_share` with `views_share` and `entrance_share`: the difference is the finding, not the rank.

**State values** (`absorbing_markov_values` UDF). States are page types, `(purchase)` and `(exit)`
absorb. `v(s) = sum P(s -> t) v(t)` solved by iteration. `probability_delta` of a transition is
`v(to) - v(from)`. It is a first order Markov chain: it does not know how the session got to the
state. Read the big deltas with volume, ignore the small ones.

**Burstiness.** `B = (sd - mean) / (sd + mean)` of the days between visits (Goh and Barabasi, 2008).
`-1` a metronome, `0` a Poisson process, towards `+1` long silences and bursts. Needs
`min_active_days`, with 4 or 5 visits it is noisy: use `rhythm_type`, not the decimals.

**Trend without building empty weeks.** Slope of 8 weekly points where the weeks without a visit are
zero: with `x` = weeks ago, `cov(x, y) = sum(x y) / 8 - 3.5 sum(y) / 8` and `var(x) = 5.25`. The same
trick is in `ecom_item_momentum`.

**Bursts.** Baseline of a minute = session starts of the hour before (skipping the last 5 minutes) / 60.
`z = (sessions - baseline) / sqrt(max(baseline, 1))`, a Poisson z score. Hot minutes closer than
`merge_gap_minutes` are one burst. A burst longer than an hour raises its own baseline and may be
cut in two. The cause is a label from the channel and the bot share, a hint and not a proof.

**Blackouts.** Expected events per minute = median, over the baseline days, of the hourly volume of
the same weekday and hour (UTC). A run of `min_gap_minutes` or more silent minutes where the
expectation is at least `min_expected_events_per_minute` is a blackout. `chance_probability =
exp(-expected_events)`. It cannot tell a site outage from a tag outage: the first loses the revenue,
the second only the measurement. Compare with the orders of the backend (`crm_order_reconciliation`).

**Cookie inflation.** People identified by a real login, same device category + OS + browser, 90
days: `cookies_per_person = cookies / people`. Biased on purpose to the customers that log in, who
visit more than the anonymous ones (more chances to lose a cookie) but also log in again (more
chances to be seen). Use it to compare browsers and as an order of magnitude, not as an exact count.

**Capture-recapture.** Chapman: `N = (n1 + 1)(n2 + 1) / (m + 1) - 1`, variance
`(n1 + 1)(n2 + 1)(n1 - m)(n2 - m) / ((m + 1)^2 (m + 2))`. Assumes a closed population and tags that
do not fall. Cookies fall (see above), so `visitors` is a ceiling. `buyers` is the one to quote.

**Mix and rate.** `total change = sum (s2 - s1)(r1 - R1) + sum s2 (r2 - r1)`, with `s` the share of
sessions and `r` the conversion of the segment. Exact, no residual. Simpson paradox = the total and
the sum of the rate effects have opposite signs.

**Empirical Bayes.** Prior `Beta(alpha, beta)` per entity type by the method of moments over the
entities with `min_sessions_for_prior` or more, after removing the average binomial noise from the
variance of the raw rates. `shrunk = (purchases + alpha) / (sessions + alpha + beta)`.
`prior_strength = alpha + beta` is the number of sessions an entity needs to speak for itself.

**Sequential test.** mSPRT with a `N(0, tau^2)` prior on the difference:
`lambda = sqrt(V / (V + tau^2)) exp(tau^2 diff^2 / (2 V (V + tau^2)))`, p of the day `= 1 / lambda`,
always valid p `=` running minimum. In the simulation of `tools/tests/test_labs_udfs.js` (no real
effect, 30 daily looks) the classic z-test "finds a winner" in about 30% of the experiments and this
one in under 2%. The price: it needs more data than a fixed horizon test looked at once.

**CUPED.** `y_adj = y - theta (x - mean x)`, `theta = cov(x, y) / var(x)` over all the variants
together, `x` measured only BEFORE the first exposure. Variance falls by `corr(x, y)^2`. Does nothing
for users with no history, look at `share_without_history`.

**COEC.** `expected clicks = sum over the impressions of the item of the click rate of the position`
(same list). `coec = clicks / expected`. Needs `item_list_index` in `view_item_list` and `select_item`.

**Missions.** A new mission starts at the first session, after a pause longer than `max_gap_days`, or
right after a purchase. Missions whose last session is more recent than `max_gap_days` are `open` and
stay out of the rates of `ds_shopping_missions_summary`.

**Order risk.** Additive score of the weights in `cfg_labs.order_risk.weights`. It is a queue for a
human, built with behaviour only. It never saw a card, an address or a chargeback: calibrate the
weights against the real fraud of the backend before anybody acts on it, and do not block orders
automatically with it. The table is user level (personal data, dataset `ga4_data_science`).

## limits (honest)

- Like the rest of the project, these were validated for syntax (compile + sqlglot, modules off and
  on) and the JS UDFs have tests, but nothing here ran against a real export yet.
- The thresholds in `cfg_labs.js` were chosen for a mid size store. On a small property raise the
  windows, on a big one lower `mart_window_days` first.
- `prod_traffic_load_profile`, `dq_tracking_blackouts`, `dq_ui_vs_bigquery_explainer`,
  `gov_url_parameter_inventory` and `prod_search_reformulations` read `stg_ga4__events` on purpose
  (they need the hits core filters out, or the raw order of the events). They are the heavy ones.
- Sessions exist only for hits with cookie. With consent mode denying a big share of the traffic,
  everything session or user based here describes the people who accepted.
