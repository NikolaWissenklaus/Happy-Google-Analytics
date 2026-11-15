// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Google Ads data transfer (BigQuery Data Transfer Service, "new" connector with
// ads_ prefix tables). Only used when enable_google_ads = true.
//   ads_Campaign_<cid>              campaign attributes, one snapshot per _DATA_DATE
//   ads_CampaignBasicStats_<cid>    daily cost / clicks / impressions per campaign
//   ads_ClickStats_<cid>            one row per click with the gclid (gold for fixing "(not set)" campaigns)

const ads = { database: constants.GOOGLE_ADS.project, schema: constants.GOOGLE_ADS.dataset };
const cid = constants.GOOGLE_ADS.customer_id;

declare({ ...ads, name: `ads_Campaign_${cid}`, description: "Google Ads campaigns (DTS)" });
declare({ ...ads, name: `ads_CampaignBasicStats_${cid}`, description: "Google Ads campaign daily stats (DTS)" });
declare({ ...ads, name: `ads_ClickStats_${cid}`, description: "Google Ads click level stats with gclid (DTS)" });
