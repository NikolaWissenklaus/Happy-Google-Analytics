// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_tracking_plan.js
//
// The tracking plan as code. gov_tracking_plan_violations compares this with what
// actually arrives in the export, every day. When the dev team changes something
// without telling anyone (always), it shows up there the next morning.
//
// types: string | int | number | any
// "allow_unplanned_events: false" makes every event outside the plan a violation.

const ecommerceParams = [
  { name: "currency", type: "string", required: true },
  { name: "value", type: "number", required: true }
];

module.exports = {
  allow_unplanned_events: false,

  // automatically collected / enhanced measurement, never flagged as unplanned
  automatic_events: [
    "first_visit", "session_start", "page_view", "user_engagement", "scroll", "click",
    "view_search_results", "video_start", "video_progress", "video_complete", "file_download",
    "form_start", "form_submit", "first_open", "screen_view", "app_remove", "os_update",
    "app_update", "app_exception", "notification_receive", "notification_open", "ad_impression"
  ],

  events: [
    { event_name: "page_view", owner: "web", params: [{ name: "page_location", type: "string", required: true }, { name: "page_title", type: "string", required: false }] },
    { event_name: "login", owner: "web", params: [{ name: "method", type: "string", required: true }] },
    { event_name: "sign_up", owner: "web", params: [{ name: "method", type: "string", required: true }] },
    { event_name: "generate_lead", owner: "marketing", params: ecommerceParams.concat([{ name: "lead_source", type: "string", required: false }]) },
    { event_name: "view_item_list", owner: "ecommerce", params: [{ name: "item_list_name", type: "string", required: true }], requires_items: true },
    { event_name: "select_item", owner: "ecommerce", params: [{ name: "item_list_name", type: "string", required: false }], requires_items: true },
    { event_name: "view_item", owner: "ecommerce", params: ecommerceParams, requires_items: true },
    { event_name: "add_to_wishlist", owner: "ecommerce", params: ecommerceParams, requires_items: true },
    { event_name: "add_to_cart", owner: "ecommerce", params: ecommerceParams, requires_items: true },
    { event_name: "remove_from_cart", owner: "ecommerce", params: ecommerceParams, requires_items: true },
    { event_name: "view_cart", owner: "ecommerce", params: ecommerceParams, requires_items: true },
    { event_name: "begin_checkout", owner: "ecommerce", params: ecommerceParams.concat([{ name: "coupon", type: "string", required: false }]), requires_items: true },
    { event_name: "add_shipping_info", owner: "ecommerce", params: ecommerceParams.concat([{ name: "shipping_tier", type: "string", required: true }]), requires_items: true },
    { event_name: "add_payment_info", owner: "ecommerce", params: ecommerceParams.concat([{ name: "payment_type", type: "string", required: true }]), requires_items: true },
    {
      event_name: "purchase",
      owner: "ecommerce",
      params: ecommerceParams.concat([
        { name: "transaction_id", type: "string", required: true },
        { name: "shipping", type: "number", required: false },
        { name: "tax", type: "number", required: false },
        { name: "coupon", type: "string", required: false },
        { name: "payment_type", type: "string", required: false }
      ]),
      requires_items: true
    },
    { event_name: "refund", owner: "ecommerce", params: [{ name: "transaction_id", type: "string", required: true }, { name: "currency", type: "string", required: true }] },
    { event_name: "view_promotion", owner: "marketing", params: [{ name: "promotion_name", type: "string", required: false }], requires_items: false },
    { event_name: "select_promotion", owner: "marketing", params: [{ name: "promotion_name", type: "string", required: false }], requires_items: false },
    { event_name: "share", owner: "web", params: [{ name: "method", type: "string", required: false }, { name: "content_type", type: "string", required: false }] },
    { event_name: "experiment_impression", owner: "cro", params: [{ name: "experiment_id", type: "string", required: true }, { name: "variant_id", type: "string", required: true }] },
    { event_name: "view_reviews", owner: "product", params: [] },
    { event_name: "view_size_guide", owner: "product", params: [] }
  ],

  // one line per event for the living dictionary (gov_event_dictionary). The GA4 ones are
  // already here, add yours. An event without description shows up as 'TODO: describe'
  descriptions: {
    first_visit: "First time the device opens the site (GA4 automatic)",
    session_start: "Start of a session (GA4 automatic)",
    page_view: "Page view (GA4 automatic / enhanced measurement)",
    user_engagement: "Sent when the page loses focus, carries engagement_time_msec (GA4 automatic)",
    scroll: "Reached 90% of the page (enhanced measurement)",
    click: "Click on an outbound link (enhanced measurement)",
    view_search_results: "Site search results page, search_term param (enhanced measurement)",
    file_download: "Click on a document / file link (enhanced measurement)",
    form_start: "First interaction with a form (enhanced measurement)",
    form_submit: "Form submitted (enhanced measurement, not always reliable)",
    video_start: "Embedded YouTube video started (enhanced measurement)",
    video_progress: "Video passed 10/25/50/75% (enhanced measurement)",
    video_complete: "Video finished (enhanced measurement)",
    login: "User logged in",
    sign_up: "Account created",
    generate_lead: "Lead form sent (key event)",
    view_item_list: "List of products shown (category, search, shelf)",
    select_item: "Product clicked in a list",
    view_item: "Product detail page",
    add_to_wishlist: "Product saved to the wishlist",
    add_to_cart: "Product added to the cart",
    remove_from_cart: "Product removed from the cart",
    view_cart: "Cart page",
    begin_checkout: "Checkout started",
    add_shipping_info: "Shipping step done (shipping_tier)",
    add_payment_info: "Payment step done (payment_type)",
    purchase: "Order placed (key event, the money one)",
    refund: "Order refunded (full or partial)",
    view_promotion: "Internal banner / promotion shown",
    select_promotion: "Internal banner / promotion clicked",
    share: "Content shared",
    experiment_impression: "User exposed to an A/B test variant",
    view_reviews: "Opened the product reviews",
    view_size_guide: "Opened the size guide",
    first_open: "First open of the app (GA4 automatic, apps)",
    screen_view: "App screen view (GA4 automatic, apps)",
    app_exception: "App crash / exception (GA4 automatic, apps)"
  },

  naming: {
    // GA4 limits (standard property). 360 is bigger, but keep it standard and you are safe
    max_event_name_length: 40,
    max_param_name_length: 40,
    max_param_value_length: 100,
    max_user_property_name_length: 24,
    max_user_property_value_length: 36,
    max_params_per_event: 25,
    reserved_prefixes: ["ga_", "google_", "firebase_", "_"],
    // snake_case only. "AddToCart" and "add_to_cart" are 2 different events for GA4
    event_name_regex: "^[a-z][a-z0-9_]*$"
  }
};
