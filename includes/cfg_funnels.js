// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_funnels.js
//
// Funnels are generated from here (definitions/40_marts/funnels/funnels.js).
// Each funnel creates 4 tables: steps (one row per session/user), daily (open + closed),
// elapsed time between steps and "next action" after the drop off.
//
//   scope   session -> steps must happen inside the same session
//           user    -> steps can be in any session, inside window_days from step 1
//   condition is SQL over stg_ga4__events columns (event_name, page_path, link_url, ...)
//
// Open funnel: user can enter in any step. Closed funnel: must do step 1, then 2, then 3...
// (same idea as GA4 explorations, but here you can slice by anything)

module.exports = {
  funnels: [
    {
      name: "purchase",
      description: "Product view to purchase, the classic ecommerce funnel",
      scope: "session",
      steps: [
        { name: "view_item", condition: "event_name = 'view_item'" },
        { name: "add_to_cart", condition: "event_name = 'add_to_cart'" },
        { name: "begin_checkout", condition: "event_name = 'begin_checkout'" },
        { name: "add_shipping_info", condition: "event_name = 'add_shipping_info'" },
        { name: "add_payment_info", condition: "event_name = 'add_payment_info'" },
        { name: "purchase", condition: "event_name = 'purchase'" }
      ]
    },
    {
      name: "checkout",
      description: "Only the checkout part, where the money is lost",
      scope: "session",
      steps: [
        { name: "begin_checkout", condition: "event_name = 'begin_checkout'" },
        { name: "add_shipping_info", condition: "event_name = 'add_shipping_info'" },
        { name: "add_payment_info", condition: "event_name = 'add_payment_info'" },
        { name: "purchase", condition: "event_name = 'purchase'" }
      ]
    },
    {
      name: "lead",
      description: "Lead generation: any landing, contact page, form start, lead",
      scope: "session",
      steps: [
        { name: "session_start", condition: "event_name IN ('session_start', 'page_view')" },
        { name: "contact_page", condition: "event_name = 'page_view' AND REGEXP_CONTAINS(page_path, r'/(contato|contact|fale-conosco|orcamento)')" },
        { name: "form_start", condition: "event_name = 'form_start'" },
        { name: "lead", condition: "event_name IN ('generate_lead', 'form_submit')" }
      ]
    },
    {
      name: "activation",
      description: "New users: first visit, sign up, add to cart and first purchase within 30 days",
      scope: "user",
      window_days: 30,
      steps: [
        { name: "first_visit", condition: "event_name IN ('first_visit', 'first_open')" },
        { name: "sign_up", condition: "event_name = 'sign_up'" },
        { name: "add_to_cart", condition: "event_name = 'add_to_cart'" },
        { name: "purchase", condition: "event_name = 'purchase'" }
      ]
    }
  ],

  // only this many days are scanned for the funnels (they read events)
  window_days: 120,

  // how many "next actions" to keep per drop off step
  next_actions_top_n: 10
};
