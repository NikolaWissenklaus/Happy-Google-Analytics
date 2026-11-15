<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# attribution

GA4 gives you two models today (data driven and last click) and no way to see how they get
there. Here everything is SQL, so you can read it, argue with it and change it.

## the pieces

```
attr_touchpoints          every session of every user in the window, with the session OWN source
       |                  (no carry over here, otherwise one click would count twice)
attr_conversion_paths     one row per conversion, the ordered touches inside conversion_lookback_days
       |
       +--> attr_credits_rule_based        7 rule based models, credits sum 1 per conversion
       |       +--> attr_channel_by_model / attr_campaign_by_model / attr_model_comparison
       +--> attr_markov_removal_effects    data driven, Markov chains (uses non converting paths too)
       +--> attr_shapley_values            data driven, exact Shapley values
       +--> attr_data_driven_summary       last non-direct x linear x Markov x Shapley, one line per channel
       +--> attr_top_conversion_paths / attr_assisted_conversions / attr_time_lag_and_path_length /
            attr_channel_roles             the old UA Multi-Channel Funnels reports
```

Channel used: `attribution_channel_grouping` = `default` (GA4 default channel group, same rules
and order as Google, `includes/channels.js`) or `custom` (with AI assistants, WhatsApp, brand
search, cashback, marketplaces).

## rule based models (attr_credits_rule_based)

| model | rule |
|---|---|
| first click | 100% to the first touch |
| last click | 100% to the last touch, direct included |
| last non-direct click | 100% to the last touch that is not direct (if all are direct, the last). This is what GA4 shows in most reports |
| linear | 1 / n for each touch |
| time decay | weight `2^(-days_before_conversion / time_decay_half_life_days)`, normalized |
| position based | 40% first, 40% last, 20% split in the middle (1 touch = 100%, 2 touches = 50/50) |
| W-shaped | 30% first, 30% first add to cart session, 30% last, 10% the rest |

`assert_attribution_credits_sum_to_one` checks the sums every day.

## data driven

**Markov (removal effect).** Builds the transition matrix between channels from converting AND
non converting journeys (`start -> channels -> conversion | null`), then removes each channel
and measures how much the conversion probability drops. The share of the drop is the credit.
Same idea of the R package ChannelAttribution, but it runs in a JS UDF
(`markov_removal_effects`), so no python job.

**Shapley.** Each converting path is a coalition of channels. The value of a coalition is its
conversion count; the Shapley value of a channel is its average marginal contribution over all
orders of entry. Exact computation with the zeta transform (`shapley_values`, up to ~12
channels, more than that and you have a channel grouping problem, not an attribution problem).

Neither is the GA4 DDA (Google does not publish it), but both are explainable, and when the two
agree you can trust the direction. `attr_data_driven_summary.consensus` is their average.

## how to read it

- Channel with `assisted_last_click_ratio > 1` (attr_assisted_conversions) opens doors: cutting
  it hurts the "closers" a few weeks later.
- `attr_channel_roles`: introducer / assistant / closer. Brand search is almost always a closer,
  do not give it the budget of the introducers.
- Big gap between last non-direct and Markov for a channel = the default reports are lying about
  it (usually social, video and display are under credited).
- Time lag (attr_time_lag_and_path_length) tells you the remarketing window. If 40% of the
  purchases take more than 7 days, a 7 day window loses them.

## limits (honest part)

- Only what GA4 sees: no impressions, no view through (MMM in `60_data_science/mmm` covers that).
- Consent denied users have no `user_pseudo_id`, their paths do not exist here.
- Cross device only works for users that log in (identity stitching).
- 90 days window in the data driven models, keep it: older paths add noise, not signal.
