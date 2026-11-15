// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_identity.js
//
// How devices (user_pseudo_id) become people (user_key).
//
// 1) login: every device where the person logged in gets the user_id, also the anonymous
//    sessions before the login (int_ga4__user_stitching). This was always here.
// 2) graph: devices that NEVER logged in can still be the same person, when they share
//    something that only one person has: the same order (transaction_id) or the same ad click
//    (gclid / fbclid...) a few minutes apart, on the same OS. The classic one: the click opens
//    in the Instagram browser, the person taps "open in Safari", GA4 sees two devices.
//    int_ga4__identity_graph finds these links and int_ga4__user_stitching uses them.
//
// No fingerprinting here (same model + same city + same browser...). It is guess work, it is
// not allowed without consent in a lot of places, and it merges people that are not the same.

module.exports = {
  // user_id values that are not a person. They never stitch anything (without this, every device
  // with user_id = 'undefined' becomes ONE user with thousands of devices)
  user_id_placeholders: [
    "null", "undefined", "none", "nan", "0", "-1", "false", "true", "guest", "anonymous", "anon",
    "visitor", "user", "unknown", "test", "(not set)", "not set", "[object object]", "{{user_id}}", "{{userid}}"
  ],

  // a user_id on more devices than this is a shared / test / store account, not a person.
  // it is ignored for stitching (dq_identity_resolution lists them)
  max_devices_per_user_id: 50,

  graph: {
    use_transaction_links: true,
    // the same order on more devices than this = reused / test transaction id, ignored
    max_devices_per_transaction: 3,
    // all devices of the order must have sent it within this time
    transaction_window_hours: 48,

    use_click_id_links: true,
    click_id_window_minutes: 30,
    click_id_same_os: true,
    // a click id on more devices than this was shared (link sent in a WhatsApp group...), ignored
    max_devices_per_click_id: 3,

    // clusters bigger than this are not merged (something is wrong, look at dq_identity_resolution)
    max_devices_per_person: 25,
    // rounds of label propagation. each round walks device -> id -> device
    iterations: 6
  }
};
