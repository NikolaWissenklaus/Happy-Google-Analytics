<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# identity and bots

Two things that decide every "users" number of the project: who is the same person, and who is
not a person at all.

## identity: devices -> people

```
int_ga4__user_id_pairs_daily     device x user_id, every day a login happened
        |
int_ga4__identity_graph          devices linked by things only one person has, clustered
        |                        by label propagation (cfg_identity.graph)
int_ga4__user_stitching          one user_key per device + identity_method
        |
dim_user_identity / every core and mart table (user_key)
```

| identity_method | rule | confidence |
|---|---|---|
| `login` | the device logged in: its most recent user_id. Retroactive, the anonymous sessions before the login get the user_id too | high |
| `linked_by_transaction` | never logged in, but sent the SAME order (transaction_id) as a device of the person, within 48h, max 3 devices per order | high |
| `linked_by_click_id` | never logged in, but arrived with the SAME ad click (gclid / gbraid / wbraid / fbclid / msclkid / ttclid) as a device of the person, within 30 minutes, same OS, max 3 devices per click. The in-app browser -> real browser case | medium |
| `merged_anonymous` | linked devices of somebody that never logged in: one `dev:` key for all of them | medium |
| `device_only` | nothing links it | - |

Safety rules (all in `cfg_identity.js`):
- placeholder user_ids (`undefined`, `null`, `0`, `guest`, `[object Object]`...) never stitch. Without this,
  every device with a broken dataLayer becomes ONE "user" with thousands of devices;
- a user_id on more than `max_devices_per_user_id` devices is a shared / test / store account, ignored;
- a click id on more than 3 devices was shared (WhatsApp group), ignored;
- clusters bigger than `max_devices_per_person` are not merged;
- no fingerprinting (same model + city + browser...). It is guess work, merges different people
  and is not allowed without consent in a lot of places.

`dq_identity_resolution` shows the result: devices, people and dedup rate per method, people by
number of devices, the ignored user_ids and the clusters. `assert_no_giant_or_placeholder_users`
fails the run if a placeholder or a giant user shows up.

Turning a link type off is one line in `cfg_identity.js`. Remember that incremental tables keep
the user_keys of the day they were built (HLL sketches of old days, audience history).

## bots: session + device

| level | table | signals |
|---|---|---|
| session | `int_ga4__session_bot_signals` | datacenter city, robotic speed (events / minute), ghost hostname, empty session, unknown browser and OS, weird language, 20+ sessions of the device that day, page scraper (30+ views in less than a minute), one and done new device (see below) |
| device | `int_ga4__device_bot_signals` (last `bot.device.window_days`) | impossible travel (another country less than 2h after the previous session ended, twice), one country jump (weak, VPN / iCloud Private Relay do that), country hopping (3+ countries in a week), robotic regularity (sessions at regular intervals, a cron), identical session lengths, never engages (90%+ sessions without engagement time), blink sessions (median 2s or less), many user_ids on the device (credential stuffing / test rig), night shift robot (80%+ between 1h and 5h), headless browser, outdated Chrome / Edge / Firefox (20+ major versions behind), 404 scanner (half of the views on not found pages), always one page idle (6+ sessions, every one of them with one page, not engaged, no conversion) |

**One and done new device.** Most bots drop the cookie, so every visit is a "new user" that sees
one page and leaves: `is_new_user` (first_visit / first_open) + ONE page path (the query string is
ignored, `?utm_source=x` is not a second page) or ONE app screen and screen class + not engaged
(no 10s, no 2nd view, no key event) + `is_active_user = false` for GA4 (when the export has it) +
no key event + no purchase. A real person that opened the site and gave up looks exactly the same,
so it weighs `cfg_project.bot.one_and_done_weight` (30): alone it NEVER flags a session (60 needed),
it only tips the scale together with another signal (datacenter city, robotic speed, 20+ sessions
of the device...). Same idea at device level for the bots that keep the cookie: `always_one_page_idle`.

Each signal has a weight, the score is capped at 100 and `bot.min_score_to_flag` (60) flags it.
`fct_sessions` keeps both: `session_bot_score`, `device_bot_score`, `bot_score` (the max),
`bot_signals` (all of them) and `is_bot_suspect` (session OR device). Core keeps the bots flagged,
business marts drop them, GA4 / UA replicas keep them like the UI.

Where to look:
- `dq_bot_traffic_daily`: bot share per day, channel, source / medium and campaign, top signals, and
  **purchases inside bot sessions** (should be ~0: if not, some rule is too aggressive for your site);
- `mkt_media_quality_scorecard`: bot share per campaign, and the cost that went to bots;
- `dq_session_quality_daily`: how often each signal fires.

Tuning: everything in `cfg_project.bot` (thresholds) and the weights inside the two models. Start by
reading 20 sessions of a flagged device in `stg_ga4__events` before changing anything.
