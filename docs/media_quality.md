<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# media quality

Is the campaign sending people, and is GA4 crediting them to the campaign? Three ways to lose:
bots, broken urls and attribution that GA4 never processed.

## the pieces

| table | what |
|---|---|
| `int_ga4__session_tagging_checks` | per session: utms of the urls, structural problems of the urls, internal utms, utms that arrived late, and the attribution loss |
| `mkt_url_tagging_issues` | every problem with the utms it had, sessions and revenue affected, example url and how to fix |
| `mkt_utm_attribution_loss_daily` | tagged sessions per day and utm source / medium / campaign, how many GA4 did not attribute, and their revenue |
| `mkt_media_quality_scorecard` | per campaign (as tagged): bot share, tagging problems, attribution loss, engagement and conversion of the humans, cost and cost on bots, 0-100 score, grade and main problem |
| `mkt_utm_linter` | the VALUES of the utms: upper case, typos in the source, unknown mediums, macros not replaced |
| `dq_bot_traffic_daily` | bot share per channel / source / campaign and the signals |

## url problems detected (`includes/tagging.js`)

| issue | example | why it hurts |
|---|---|---|
| `utm_without_question_mark` | `/page&utm_source=fb` | no query string, GA4 sees no utm |
| `utm_glued_to_previous_param` | `?utm_source=fbutm_medium=cpc` | source becomes "fbutm_medium=cpc", medium missing |
| `double_question_mark` | `?a=1?utm_source=x` | the utm becomes part of the value of `a` |
| `empty_utm_value` | `utm_source=&utm_medium=cpc` | the dynamic parameter of the platform came empty |
| `html_encoded_ampersand` | `&amp;utm_medium=email` | GA4 reads a param called `amp;utm_medium` |
| `encoded_separator` | `%3Futm_source%3D...` | the url went through a redirect / shortener and was encoded |
| `utm_after_hash` | `/#/home?utm_source=x` | GA4 does not read the fragment |
| `uppercase_utm_param_name` | `UTM_SOURCE=x` | param names are case sensitive |
| `invalid_utm_param_name` | `utm_souce`, `utm-medium`, `utm_campaing` | ignored |
| `duplicated_utm_param` | `utm_source=a&...&utm_source=b` | GA4 keeps one, nobody knows which is right |
| `msclkid_without_utm` | Microsoft Ads without utms | GA4 does not know msclkid: paid Bing becomes organic |
| `ttclid_without_utm` | TikTok Ads without utms | becomes tiktok / referral |
| `fbclid_without_utm` | Meta click without utms | paid Meta mixed with organic (organic posts get fbclid too) |
| `gclid_with_conflicting_utm_medium` | `gclid=...&utm_medium=email` | manual tagging fighting the auto tagging |
| `internal_utm` | utm in a banner of the own site | rewrites the attribution of the session |
| `utm_not_on_first_page` | utm only after a redirect / SPA route | the session started without it |
| `utm_without_source_medium_event_param` | url with utms, no event got `source` / `medium` params | GA4 did not process the utms (tag fired before the url had them, consent, redirect, SPA) |
| `utm_ignored_by_ga4` | url with utms, GA4 says (direct) / (not set) | attribution lost |

The last two are the "attribution loss" of `mkt_utm_attribution_loss_daily`. The check of the event
params is exactly that: the session had utms in some page_location, but not a single event of the
session has the event params `source` and `medium`.

## the score

```
media_quality_score = 100 - 45 x bot share - 25 x attribution loss - 15 x tagging issues
                          - 15 x (1 - engagement rate of the humans)
```

A >= 85, B >= 70, C >= 55, D below. `main_problem` says which penalty is the biggest. Campaigns
are grouped as they were TAGGED (utm values), so the sessions GA4 lost still count for the
campaign that paid for them. Costs are matched by campaign name with `fct_ad_costs_daily`.

Monday routine: sort `mkt_media_quality_scorecard` by `cost_on_bots` and by grade, send
`mkt_url_tagging_issues` (severity high) and `mkt_utm_linter` to the agency.
