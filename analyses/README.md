<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# analyses

Queries for the day to day. Dataform does not compile this folder, it is just SQL to copy,
paste in the BigQuery console and adapt. Replace `your-gcp-project` by your project (and the
`ga4_` prefix if you changed `schema_prefix`).

| file | when |
|---|---|
| `01_why_did_revenue_drop.sql` | somebody asks "why is revenue down?" |
| `02_channels_last_30_days.sql` | weekly marketing meeting |
| `03_landing_pages_to_fix.sql` | CRO backlog |
| `04_products_with_problems.sql` | merchandising / catalog meeting |
| `05_is_this_difference_real.sql` | before saying "it went up" (the stats UDFs) |
| `06_one_user_journey.sql` | support / product: what did this person do? |
| `07_who_to_call_today.sql` | CRM / sales: valuable customers at risk |
| `08_tracking_health_monday.sql` | analytics team, every monday |
| `09_month_pacing.sql` | "are we going to hit the target?" |
| `10_utm_mess.sql` | send to the agency |
| `11_media_quality.sql` | bots, broken urls and lost attribution per campaign |
| `12_what_really_works.sql` | every lift measured (holdouts, tests, interventions, promos) |
| `13_what_was_that_spike.sql` | "what happened yesterday at 21h?": bursts, blackouts and peak load |
| `14_merchandising_moves.sql` | weekly list of who decides the shelf: positions, gems, substitutes, reminders |
| `15_who_broke_the_habit.sql` | CRM: regular users late for their own rhythm, open missions with value |
| `16_is_the_number_real.sql` | before presenting a number: mix vs rate, shrunk rates, peeking, UI vs BigQuery |
