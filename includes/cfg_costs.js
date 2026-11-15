// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_costs.js
//
// Costs that dont come from any connector: influencers, affiliates fixed fee,
// offline media, that agency that charges by month... Monthly costs are spread
// evenly over the days of the month in int_costs__unified_daily.
//
// source/medium/campaign must match the utms used in the links, otherwise there is
// no way to join cost with sessions (lower case, same as GA4 after cleaning).

module.exports = {
  manual_costs: [
    { cost_month: "2026-09-01", platform: "influencers", source: "instagram", medium: "influencer", campaign: "colecao_primavera", cost: 18000 },
    { cost_month: "2026-10-01", platform: "influencers", source: "instagram", medium: "influencer", campaign: "colecao_primavera", cost: 12000 },
    { cost_month: "2026-10-01", platform: "affiliates", source: "awin", medium: "affiliate", campaign: "(not set)", cost: 7500 },
    { cost_month: "2026-11-01", platform: "influencers", source: "tiktok", medium: "influencer", campaign: "black_friday_2026", cost: 30000 },
    { cost_month: "2026-11-01", platform: "crm", source: "rdstation", medium: "email", campaign: "(not set)", cost: 2500 }
  ]
};
