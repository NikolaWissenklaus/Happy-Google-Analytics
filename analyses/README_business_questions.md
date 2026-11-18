<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# analyses: business questions (17 to 52)

Same rules as `README.md` (queries to copy, paste and adapt; Dataform does not compile this folder;
replace `your-gcp-project` and the `ga4_` prefix). Most of them read only the core contract tables
(`docs/data_contracts.md`), so they work in any store. Some files start with a `DECLARE` with the
number you must set (threshold, ticket, event names): run the whole file as a script.

## questions every business asks

| file | the question | who asks |
|---|---|---|
| `17_who_pays_the_bills.sql` | is the revenue coming from new or returning customers? is loyalty getting better? | board, CEO |
| `18_channel_customer_quality.sql` | which channel brings customers that COME BACK, and what a new customer costs | marketing, finance |
| `19_gateway_products.sql` | which first product creates loyal customers, which one creates "one and done" | marketing, merchandising |
| `20_pareto_catalog.sql` | how many products make 80% of the revenue, which are dead or invisible | merchandising, buyers |
| `21_when_people_buy.sql` | best hour to send, to bid, to staff support, to deploy | CRM, media, ops |
| `22_payday_and_calendar.sql` | payday, 13th salary, holidays and Black Friday effects | planning, promotions |
| `23_coupon_profitability.sql` | are coupons buying growth or giving away margin? | CRM, finance |
| `24_free_shipping_threshold.sql` | is the free shipping threshold in the right place? | pricing, logistics |
| `25_mobile_money_left.sql` | how much money the mobile experience leaves on the table | product, CRO |
| `26_checkout_money_leak.sql` | where the money leaves the checkout, in R$ | CRO, payments |
| `27_geo_expansion.sql` | which states to grow in (penetration per 100k inhabitants) | expansion, media |
| `28_payment_methods.sql` | PIX, boleto or card: ticket, unpaid, refunds, retries | finance, payments |
| `29_search_demand_not_met.sql` | what people search and the store does not deliver | buyers, SEO |
| `30_price_bands.sql` | is the assortment where the demand is (by price band)? | buyers, pricing |
| `31_basket_building.sql` | how to sell more items per order (single item orders, attach rates) | merchandising |
| `32_second_purchase_window.sql` | when to send the "come back" message | CRM |
| `33_returns_and_net_revenue.sql` | which channels, products and customers give the money back | finance, media |
| `34_campaign_roas_reality.sql` | which campaigns pay for themselves (net ROAS, new customers, bots) | media, agency |
| `35_owned_vs_rented_demand.sql` | how much of the revenue is owned demand vs rented from Google / Meta | board, brand |
| `36_vip_early_signals.sql` | what the best customers did at the beginning (find the next VIPs early) | CRM, media |
| `37_win_back_list.sql` | customers that lost their own buying rhythm, by money at stake | CRM, sales |
| `38_yoy_like_for_like.sql` | are we growing vs last year (same weekday, holidays flagged)? | board, finance |
| `39_content_that_sells.sql` | does the blog sell anything? | content, SEO |

## sector specific

| file | sector |
|---|---|
| `40_sector_fashion_sizes_and_returns.sql` | fashion, shoes, sportswear: refunds per size, size curve, bracketing |
| `41_sector_replenishment_beauty_pet_pharma_grocery.sql` | consumables: repurchase cycle, who is due this week, subscription candidates |
| `42_sector_high_ticket_electronics_furniture.sql` | high ticket: decision journey, remarketing window, price checks |
| `43_sector_lead_generation.sql` | B2B, education, real estate, cars, insurance, services: leads, SDR shifts, lead score |
| `44_whatsapp_clicks.sql` | Brazil: the WhatsApp button as a sales channel |
| `45_sector_publishers_content_sites.sql` | publishers: read rate, recirculation, loyalty, article half life, ad revenue |
| `46_sector_signup_subscription_apps.sql` | subscriptions, SaaS, apps: sign up activation, aha moments |
| `47_sector_food_delivery_restaurants.sql` | food delivery: day parts, kitchen peak, weekly habit, minimum order |
| `48_sector_multibrand_retail.sql` | multi-brand retail: brand scorecard, brand loyalty, brand dependence |
| `49_launches_and_collections.sql` | launches: the first 28 days of every new product, verdict |
| `50_hidden_b2b_buyers.sql` | any B2C store: the resellers and companies buying as consumers |

## using the newer models

| file | what |
|---|---|
| `51_frontier_action_lists.sql` | one action list per team from the `frontier` models (docs/frontier.md) |
| `52_which_attribution_to_trust.sql` | where the attribution models agree and disagree, marginal cost per conversion (docs/attribution_extended.md) |
