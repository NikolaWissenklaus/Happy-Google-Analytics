// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_promotions.js
//
// Promotion calendar. promo_calendar_lift compares each period with a baseline
// (same length, right before) and with the period right after (to catch the
// "pull forward" effect: people just waited for the promo and bought then).
//
// Examples only. Put the real ones, marketing has a spreadsheet for sure.

module.exports = {
  baseline_days: 28,
  post_period_days: 14,

  promotions: [
    { promo_id: "bf_2025", name: "Black Friday 2025", promo_type: "sitewide_sale", start_date: "2025-11-17", end_date: "2025-11-30", coupon_codes: ["BLACK25", "BF25"], discount_pct: 0.25 },
    { promo_id: "natal_2025", name: "Natal 2025", promo_type: "seasonal", start_date: "2025-12-01", end_date: "2025-12-24", coupon_codes: ["NATAL10"], discount_pct: 0.10 },
    { promo_id: "verao_2026", name: "Liquida Verao 2026", promo_type: "clearance", start_date: "2026-01-05", end_date: "2026-01-31", coupon_codes: [], discount_pct: 0.40 },
    { promo_id: "consumidor_2026", name: "Semana do Consumidor 2026", promo_type: "sitewide_sale", start_date: "2026-03-09", end_date: "2026-03-15", coupon_codes: ["CONSUMIDOR15"], discount_pct: 0.15 },
    { promo_id: "maes_2026", name: "Dia das Maes 2026", promo_type: "seasonal", start_date: "2026-04-27", end_date: "2026-05-10", coupon_codes: ["MAE10"], discount_pct: 0.10 },
    { promo_id: "frete_jun_2026", name: "Frete Gratis Junho 2026", promo_type: "free_shipping", start_date: "2026-06-01", end_date: "2026-06-12", coupon_codes: ["FRETEGRATIS"], discount_pct: 0.0 },
    { promo_id: "pais_2026", name: "Dia dos Pais 2026", promo_type: "seasonal", start_date: "2026-07-27", end_date: "2026-08-09", coupon_codes: ["PAI10"], discount_pct: 0.10 },
    { promo_id: "bf_2026", name: "Black Friday 2026", promo_type: "sitewide_sale", start_date: "2026-11-16", end_date: "2026-11-29", coupon_codes: ["BLACK26", "BF26"], discount_pct: 0.25 }
  ]
};
