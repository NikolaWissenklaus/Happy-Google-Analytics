<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# attribution, extended

The models with the tag `attribution_extended`. The original attribution of `docs/attribution.md`
(7 rule based models, Markov, Shapley, MCF) is untouched; these sit next to it in `ga4_attribution`,
from the simplest rule to models fitted by maximum likelihood inside BigQuery. Knobs in
`includes/cfg_attribution_extended.js`. Run with `dataform run --tags attribution_extended`.

## the ladder

| level | table | model |
|---|---|---|
| rules | `attr_credits_rule_based_extended` | first non-direct, last paid, last engaged, J-shaped, inverse J, full path (Z), engagement weighted, geometric position, funnel progress, learned time decay |
| rules | `attr_channel_by_model_extended` | the 10 above in the long format of `attr_channel_by_model` (UNION both: 17 models) |
| base | `attr_user_journeys` | converting AND non converting journeys with the timing of every touch |
| probabilistic | `attr_probabilistic_shao_li` | Shao and Li (2011) simple probabilistic model + presence lift |
| probabilistic | `attr_channel_synergy` | pairs of channels: synergy or cannibalization |
| Markov | `attr_markov_higher_order` | Markov chains of order 1, 2 and 3 (`markov_removal_effects_k_order` UDF) |
| survival | `attr_additive_hazard` | additive hazard model (Zhang, Wei and Ren 2014), baseline vs channels, conversions per touch (`additive_hazard_attribution` UDF) |
| ML (optional) | `attr_model_journey_logit` + `attr_logistic_regression_credits` | BQML logistic regression of the journeys (needs `enable_bqml`, weekly) |
| synthesis | `attr_model_consensus` | every model of the project side by side, consensus and disagreement per channel |

All of them work on the primary key event (`cfg_key_events.js`) of the last 90 days, except the
rule based tables, which cover every key event like the originals.

## the math, short

**Rules.** Credits of a conversion sum 1. Full path: 22.5% to each milestone (first touch, first
session with `add_to_cart`, first with `begin_checkout`, last), 10% to the rest, normalized when
milestones coincide. Funnel progress: stage of a session (1 visit, 2 product view, 3 cart, 4 checkout,
5 the converting session), credit proportional to `max(0, stage - best stage before it)`. Learned
time decay: half life = median age (days before the conversion) of the touches that are not the last,
bounded by `learned_half_life_bounds_days`. Geometric: `ratio^(steps before the conversion)`.

**Journeys.** Converting: the touches of the lookback window (`conversion_lookback_days`) before a
conversion. Non converting: people with touches in the window and no conversion, the touches up to
the lookback before their last touch (at most `max_touches_per_journey`), censored at last touch +
lookback or now. A converter's touches after the conversion are not used (same as the originals).

**Shao-Li.** `C(i) = P(y|i) + 1/(2 N_i) sum_j [P(y|i,j) - P(y|i) - P(y|j)]` over the channels j that
co-occur with i at least `min_journeys_per_pair` times. Shares = positive contributions normalized.
`presence_lift = P(y|i) / P(y|not i)` is correlation: people that touch more channels convert more.

**Synergy.** Independence benchmark `1 - (1 - p_i alone)(1 - p_j alone)` against `p_both`. It needs
the non converting journeys, otherwise every pair looks perfect.

**Markov of order k.** The state is the tuple of the last k channels. Removing channel c sends to
null every state that contains c. Order 1 reproduces `markov_removal_effects` exactly (tested).
Higher orders split the data in more states: check `median_state_visits` (below ~30 the order is
too high for your volume). A big `share_change_vs_order_1` means the sequence matters for the channel.

**Additive hazard.** `lambda(t) = b0 + sum_j beta[c_j] w exp(-w (t - t_j))`, the kernel integrates to 1,
so `beta[c]` is the number of conversions ONE touch of c produces. Likelihood of converted and
censored journeys, maximized by EM for each half life of the grid (`ln 2 / w`), best likelihood wins.
The credit of a conversion is the share of `lambda` at the conversion time owed to each touch and to
the baseline. `(baseline)` = conversions the model expects without any touch: it is the only model
here that does not force all the credit on the channels. The UDF runs on a deterministic sample
(`max_converting_journeys`, `max_non_converting_journeys`) with weights, and the totals are rescaled.
The simulation in `tools/tests/test_attribution_udfs.js` recovers the true betas, baseline and half
life of synthetic data.

**Logistic regression.** `logit P(convert) = a + sum_c b_c * touches_c` (touches capped). Credit of a
journey proportional to `max(b_c, 0) * touches_c`, linear when no positive coefficient is present.
Channels of `logistic.channels` that never appear in your data make constant features: remove them
from the list if BQML complains.

**Consensus.** Every model gives a share per channel (0 when it gives nothing). `consensus_share` =
median across models, `disagreement_cv` = sd / mean, `data_driven_vs_last_click` = average share of
the data driven models / last non-direct share.

## tests

`node tools/tests/test_attribution_udfs.js definitions/01_udfs` (from the project root): Markov of
order 1 equals the original UDF, order 2 fixes a case where order 1 gives credit to a useless
channel, and the hazard model recovers the parameters of a simulated population. It is a separate
file so `npm run check` stays as it was; run it after changing the UDFs.

## limits (honest)

- Every model here is observational. They disagree for good reasons: use the consensus to decide
  where to TEST (holdouts in `ga4_lifts`, geo experiments), not as the final truth.
- Validated for syntax with the modules on and off, UDFs tested in node. Nothing ran on a real
  export yet: check the first results against `attr_model_comparison`.
- Journeys only see the people with cookies and consent, like everything session based.
