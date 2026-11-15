<!-- author: Francisco Lucas / Nikola Wissenklaus / Chico -->

# activation

The tables in `ga4_activation` are ready to be sent. The sending itself is a small job of your
stack (Cloud Run job, Cloud Function, Airflow, Hightouch / Census, the Google Ads Data Manager...),
because credentials and rate limits do not belong in a Dataform repo.

## the gate

`act_consent_eligible_users` decides, per user, today:

| flag | rule | used by |
|---|---|---|
| `can_send_to_ads` | latest `ads_storage = granted` and no revocation / deletion request | Google Ads, Meta, audiences |
| `can_write_back_ga4` | latest `analytics_storage = granted` and no request | Measurement Protocol |
| `can_send_to_crm` | identified (user_id), analytics not denied, no request | CRM traits and triggers |

Every `act_` table joins the gate. `priv_activation_consent_audit` and the assertion
`assert_activation_only_consented_users` check it every day. If the assertion fails, stop the
syncs until it is fixed.

## destinations

| table | destination | how to send |
|---|---|---|
| `act_google_ads_offline_conversions` | Google Ads conversions (gclid / gbraid / wbraid, order_id, consent fields, hashed e-mail / phone with CRM) | Google Ads API `UploadClickConversions` (one of gclid / gbraid / wbraid per row) or the scheduled CSV upload. Conversion names must exist in Google Ads |
| `act_meta_capi_events` | Meta Conversions API | POST `https://graph.facebook.com/v<version>/<pixel_id>/events` with `{"data": [payload_json, ...]}` (up to 1000 per call). Only the last 7 days, Meta refuses older events |
| `act_ga4_mp_user_properties` | GA4 Measurement Protocol (traits as user properties) | POST `https://www.google-analytics.com/mp/collect?measurement_id=G-XXX&api_secret=...` with `payload_json`. Register the `hga_*` user properties as custom dimensions first. Send only rows whose `traits_fingerprint` changed |
| `act_audience_exports` | Google Ads Customer Match, Meta Custom Audiences, GA4 audience import, CRM lists | per `destination`. Google Customer Match needs `enable_crm` (hashed e-mail / phone) |
| `act_crm_user_traits` | CRM / CDP | upsert by `user_id`, only changed `traits_fingerprint` |
| `act_crm_triggers` | CRM automations (abandoned cart / checkout, price drop, propensity, churn) | daily list (view over `act_crm_triggers_all` without the holdout), the CRM checks its own opt-ins (e-mail / WhatsApp / SMS) before sending. History in `act_crm_triggers_history` |

## holdouts

With `cfg_lifts.holdout.enabled`, a fixed part of each audience and of each CRM trigger is never
sent (deterministic by person). That is what makes `lift_activation_holdouts` able to say if the
remarketing / the abandoned cart e-mail really sells, or only takes credit for purchases that would
happen anyway. See `docs/lifts.md`.

## things that bite

- **Dedup with the tags.** Google Ads dedups by `order_id` when the tag also sends the
  transaction_id. Meta dedups when the pixel `eventID` = our `event_id` (transaction_id for
  purchases). Without that, conversions count twice.
- **Match quality on Meta.** The GA4 export has no IP and no user agent, so `fbc` + `external_id`
  (+ hashed contact with CRM) is what we have. A server side tag sends more.
- **Click windows.** gclid is valid 90 days in the offline import, Meta click attribution is 7
  days by default. The tables already respect that.
- **Measurement Protocol** creates an event every time. That is why the fingerprint exists: send
  only what changed, or you will inflate `user_traits_sync` events (harmless, but ugly).
- **Revocation.** When somebody revokes the consent, the gate removes them the next day. Removing
  them from lists already uploaded is the job of the sync (send the removals, not only the adds).
