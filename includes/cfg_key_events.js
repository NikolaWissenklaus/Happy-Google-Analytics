// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_key_events.js
//
// Key events (the old "conversions"). Keep in sync with GA4 admin, but here we can do
// things GA4 cant: conditions on params, "once per session" for anything, custom values.
//
//   name         unique id of the key event in our tables
//   event_name   GA4 event name
//   condition    optional extra SQL filter over stg_ga4__events columns
//   counting     every_event | once_per_session  (same options as GA4)
//   value        revenue (purchase revenue) | param (the "value" param) | fixed | none
//   fixed_value  used when value = fixed (ex: a lead is worth R$ 35 for the business)
//   dedupe_by_transaction  only first purchase per transaction_id counts
//   is_primary   the main one, used as default conversion in attribution and CRO tables

module.exports = {
  key_events: [
    {
      name: "purchase",
      event_name: "purchase",
      label: "Purchase",
      category: "ecommerce",
      counting: "every_event",
      value: "revenue",
      dedupe_by_transaction: true,
      is_primary: true,
      google_ads_conversion_name: "GA4 Purchase (offline import)",
      meta_event_name: "Purchase"
    },
    {
      name: "generate_lead",
      event_name: "generate_lead",
      label: "Lead",
      category: "lead",
      counting: "once_per_session",
      value: "fixed",
      fixed_value: 35,
      google_ads_conversion_name: "GA4 Lead (offline import)",
      meta_event_name: "Lead"
    },
    {
      name: "sign_up",
      event_name: "sign_up",
      label: "Sign up",
      category: "account",
      counting: "once_per_session",
      value: "none",
      meta_event_name: "CompleteRegistration"
    },
    {
      // whatsapp is a sales channel in Brazil, period. click on wa.me = intent
      name: "whatsapp_click",
      event_name: "click",
      label: "WhatsApp click",
      category: "contact",
      condition: "REGEXP_CONTAINS(LOWER(COALESCE(link_url, link_domain, '')), r'(wa\\.me|whatsapp)')",
      counting: "once_per_session",
      value: "none",
      meta_event_name: "Contact"
    },
    {
      // the classic "pagina de obrigado" of the contact form
      name: "contact_thank_you",
      event_name: "page_view",
      label: "Contact thank you page",
      category: "lead",
      condition: "REGEXP_CONTAINS(page_path, r'/(obrigado|contato-enviado|mensagem-enviada)')",
      counting: "once_per_session",
      value: "none"
    }
  ]
};
