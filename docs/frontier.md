<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# frontier

The models with the tag `frontier`: behavioural economics, queueing theory and a bit of
statistical physics applied to the GA4 export. One step past the `labs` (docs/labs.md): questions
that are not in any GA4 report, in any connector, and in very few data teams.

Same rules as the rest of the project: they read only the core contract tables (and one mart,
`ecom_order_value_distribution`), drop bots with `helpers.martSessionFilter()`, and every knob is
in `includes/cfg_frontier.js`. Run them with `dataform run --tags frontier` after the daily run.

## what is here

| question | table | idea |
|---|---|---|
| Do my customers compare products in tabs? | `prod_multi_tab_browsing` | a new page whose referrer is an OLDER page of the session = a parallel tab |
| Where does the visit die, and is it natural? | `prod_session_hazard_curve` | life table of the session by page and minute, cliffs = something the site does |
| Is the attention concentrating or spreading? | `prod_zipf_long_tail` | weekly Zipf exponent of pages, products and search terms |
| Who leaves to check the price elsewhere? | `ecom_price_check_departures` | ends on the product, comes back to the same product hours later (or never) |
| What do people add to reach free shipping? | `ecom_cart_filler_items` | running cart value, the add that crosses the threshold with a cheap item |
| How much revenue is sitting in open carts? | `ecom_cart_pipeline_forecast` | carts as a CRM pipeline, P(convert in 7 days given age) + Little's law |
| Which sizes / colours are people hunting? | `ecom_variant_hunting` | 3+ variants of the same product in one session, the dead end variants |
| How many products before the customer drowns? | `ecom_choice_overload` | conversion by products viewed, the sweet spot per category |
| Does the first price seen change what they buy? | `ecom_price_anchoring` | sessions grouped by the relative price of the first product viewed |
| Which items people regret putting in the cart? | `ecom_cart_indecision` | kept / removed / flip-flop, impulse vs freight regret |
| Who is waiting for the price to drop? | `seg_price_watchers` | same person, same product, 3+ days, no purchase (activation ready, with consent) |
| Does the store grow by word of mouth? | `mkt_viral_coefficient` | K factor from the share event and the newcomers of shared links |
| Who is behind the browser in another language? | `mkt_language_geo_mismatch` | device language x IP country: natives, foreigners, bots, diaspora |
| Which campaign brings the wallet? | `mkt_audience_affluence_index` | device tier (premium / mid / entry) per channel, campaign and UF |
| How hostage is my revenue? | `biz_channel_dependency_risk` | HHI and effective number of channels and of traffic owners (Google, Meta...) |
| Can an LLM read my sessions? | `ds_session_narratives` | every session as a paragraph of text + a token sequence |

## the math, short

**Parallel tabs.** A page view `p` at position `k > 1` is parallel when it is the first view of `p`
in the session, its referrer is a page of the site, the referrer is not the previous page, and the
referrer was viewed at position `k - 2` or before. The back button brings an old page back (not a
first view) and a reload has referrer = itself, so both are out. Single page apps that do not
update `document.referrer` show no tabs at all: read the table only for classic navigation.

**Hazard.** `alive(k) = sessions with k or more steps`, `hazard(k) = ended(k) / alive(k)`,
`survival(k) = alive(k) / all`. No censoring (a session always ends). `hazard_excess = h(k) -
(h(k-1) + h(k+1)) / 2`, a cliff is an excess above 3 times the median absolute excess of the curve.
The last step is open ended (that many or more) and never a cliff.

**Zipf.** `log f = a - s log r`, `s = -cov(log r, log f) / var(log r)` over the top `max_rank` ranks,
`R2 = corr^2`. Only compare `s` of the same entity type over time; between types it means nothing.

**Price check.** Departure = session without purchase, engaged, exit page of type product, last
viewed item = the item. Return = a `view_item` of the same item by the same `user_key` in another
session inside `max_return_hours`. People that come back on a device we cannot stitch count as
`never_returned`, so the absolute share is a ceiling: use `competitor_loss_index` (against the
category), not the raw share.

**Filler.** The cart of the session is rebuilt as the running sum of `add_to_cart` minus
`remove_from_cart` values. A filler add has `cart_before < T <= cart_after`, `T - cart_before <=
max_gap_share * T` and an add value `<= max_filler_share * T`. Thresholds come from the config and
from the buckets of `ecom_order_value_distribution` with `bunching_ratio >= 1.5`. Carts that live
across sessions start at zero in every session here, so fillers of old carts are missed.

**Cart pipeline.** One cart per person per purchase cycle: rows between two purchases of the same
`user_key` are one cart. `p(a) = carts converting at age in [a, a + H) / carts still open at age a`,
learned on carts old enough to be fully observed. `expected revenue = open value * p(a) * median
(order value / cart value)`. Little's law `L = lambda W` with `lambda` = carts opened per day and
`W` = average days in the pipeline (dead carts count `max_cart_age_days`). `pipeline_pressure =
open carts now / (lambda W)`.

**Variant hunting.** The product is `item_id` when `item_variant` is sent, else `item_name` (sites
that use one `item_id` per size). `estimated_revenue_lost = gave_up_hunters * median price *
purchase rate of the non hunters` (what they would buy converting like the others), an order of
magnitude.

**Choice overload.** Sessions bucketed by distinct products viewed (capped). The sweet spot is the
bucket with the highest Wilson lower bound, not the highest raw rate, so a bucket of 50 lucky
sessions does not win. It is an observational curve: people that view 25 products are different
people. Use it to choose the size of a shelf and to design a test, not as a causal effect.

**Anchoring.** `relative price = price / median price of the category` (views of the window).
Buckets by the relative price of the first product viewed. `anchor_pull = paid ratio - paid ratio
of the typical bucket`. Same caveat: observational, the ad that brought them already chose the
anchor. The test to run is the order of the first slot.

**Indecision.** Per session and item, the ordered adds and removes. `flip_flop` = removed, added
back and still in the cart at the end. `freight_regret_share` = removes after the first
`add_shipping_info` of the session.

**Viral K.** `K = new users from shared links / active users` (weekly). A newcomer is from a shared
link when the source / medium of the session itself (no carry over) matches `shared_link_pattern`.
Shared links without parameters fall in Direct (see `mkt_dark_social_estimate`), so K is a floor.

**Affluence.** Device tier: entry (pattern or old OS) > premium (pattern or Apple) > mid. Index
`100 * (1 + premium - entry) / (1 + site premium - site entry)`. The `tier` rows carry the revenue
per session of each tier: if premium does not spend more than entry in your store, do not use the
index. On the web GA4 often only knows "iPhone" or a frozen Android model, so most of the signal is
the brand and the OS version.

**Dependency.** `HHI = sum share^2` of the weekly valid revenue, `effective players = 1 / HHI`.
The traffic owner comes from regexes on the session source (AI assistants first, so
gemini.google.com is AI and not Google).

**Narratives.** Plain `CONCAT`, no model, no API: deterministic and cheap. English on purpose (the
rest of the project is), and with no personal data besides the city of the IP and the products. The
table is user level (`user_key`) and lives in `ga4_data_science` with the other personal data.

## limits (honest)

- Validated like the rest (compile + sqlglot with the modules on and off). Nothing here ran against
  a real export yet: check the first results with somebody that knows the store.
- Most of these are observational. They point where to look and what to test (`ga4_cro`), they do
  not prove causes.
- With consent mode denying a big share of the traffic, everything describes the people that
  accepted.
