<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# data science

Everything runs inside BigQuery (SQL, JS UDFs and BigQuery ML). No notebook in production, no
python job to babysit. The BQML part only exists with `enable_bqml = true`; without it the
heuristic scores keep audiences and activation working.

## feature store: ds_feature_snapshots

One row per user per weekly snapshot (`cfg_ds.features`): features computed ONLY with data before
the snapshot, labels ONLY with data after it (`will_purchase_7d`, `churned_30d`,
`future_revenue_90d`). That is the whole trick against leakage. The current snapshot (today) has
features and no labels, it is the one we score. `future_revenue_90d` is NULL for snapshots
younger than 90 days, so the LTV model never learns from half baked labels.

## models

| model | type | target | output |
|---|---|---|---|
| purchase propensity | BQML LOGISTIC_REG (or BOOSTED_TREE, `cfg_ds`) | purchase in 7 days | `ds_scores_purchase_propensity`, evaluation, gains on an out of time holdout |
| churn | BQML classifier | no session in 30 days (customers) | `ds_scores_churn` |
| LTV | BQML BOOSTED_TREE_REGRESSOR | revenue next 90 days | `ds_scores_ltv` (deciles for value based bidding) |
| clusters | BQML KMEANS (k = 6) | behaviour | `ds_user_clusters` with profiles to name them |
| KPI forecast | BQML ARIMA_PLUS, holiday_region BR | sessions, orders, revenue | `ds_kpi_forecast` + the 9th vote of the anomaly ensemble |
| MMM-lite | BQML LINEAR_REG over adstock + log saturation | daily revenue | `ds_mmm_contributions`, incremental ROAS by platform |
| BTYD | BG/NBD + Gamma-Gamma fitted by maximum likelihood in JS UDFs (Nelder-Mead) | purchases and spend | `ds_btyd_customer_clv`: p_alive, expected purchases, CLV |
| heuristic scores | bayesian smoothed rates of "users like you" | purchase / churn | `ds_heuristic_scores` (always on, the fallback) |

Training runs with the `weekly` tag, scoring with `daily`. The newest training snapshot is kept out
of the training (`ds_propensity_gains` uses it): if the top decile does not have a lift of 3x or
more, the model is not worth the bytes, use the heuristic.

## statistics (no ML)

| table | question it answers |
|---|---|
| `ds_metric_correlations` | does metric A move with metric B? (Pearson and Spearman) |
| `ds_lagged_correlations` | how many days does each channel take to turn into revenue? |
| `ds_event_cooccurrence` | which behaviours happen together (lift, phi) |
| `ds_category_transitions` | after category X, which category is bought next and when |
| `ds_survival_first_purchase` | Kaplan-Meier from first visit to first purchase, by channel |
| `ds_geo_experiment_did` | geo experiments by UF, difference in differences |
| `ds_search_term_ngrams` | what people search (n-grams, pt stopwords, no accents) and how it converts |
| `cro_ab_test_results` (marts) | A/B tests: z-test, Wilson intervals, Bayesian P(B > A), SRM check |

## math inside the UDFs

`normal_cdf`, `wilson_interval`, `z_test_proportions`, `chi_square_pvalue`, `welch_t_test`,
`prob_b_beats_a` (Beta posterior by simulation), `benford_expected`, `fit_bg_nbd`,
`bg_nbd_predict`, `fit_gamma_gamma`, `gamma_gamma_expected_value`, `markov_removal_effects`,
`shapley_values`, `cusum`. They are persistent functions in `ga4_udf`, analysts can call them in
any query. The JS ones have tests with synthetic data (`npm run test:udfs`).

## costs

BQML training is billed by bytes processed (and the k-means / boosted trees are the expensive
ones). With `training_snapshots = 20` and a mid size e-commerce it is a few dollars a week. Look
at `ops_job_costs` after the first month and reduce `cfg_ds.features.training_snapshots` if
needed.
