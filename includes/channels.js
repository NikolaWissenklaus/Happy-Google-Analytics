// author: Francisco Lucas / Nikola Wissenklaus / Chico

// channels.js
//
// Channel grouping logic, generated from cfg_channels.js.
// The same functions build the inline SQL used by the pipeline AND the persistent
// UDFs (ga4_udf.default_channel_group etc), so analysts and pipeline never disagree.
//
// All the expressions expect source/medium/campaign already lower cased.

const helpers = require("./helpers");
const lists = require("./cfg_channels");
const project = require("./cfg_project");
const constants = require("./constants");

const PAID_MEDIUM = "^(.*cp.*|ppc|retargeting|paid.*)$";
const SHOPPING_CAMPAIGN = "^(.*(([^a-df-z]|^)shop|shopping).*)$";

function inSet(expr, values) {
  return helpers.inList(expr, values);
}

// "l.facebook.com" -> "facebook", "google.com.br" -> "google", and so on
function normalizeSource(expr) {
  const whens = lists.source_aliases.map(alias => {
    const conds = [inSet(expr, alias.values.concat([alias.canonical]))];
    if (alias.pattern) conds.push(`REGEXP_CONTAINS(${expr}, r'${alias.pattern}')`);
    return `WHEN ${conds.join(" OR ")} THEN '${alias.canonical}'`;
  });
  return `CASE\n      ${whens.join("\n      ")}\n      ELSE ${expr}\n    END`;
}

// GA4 default channel group, same order google evaluates the rules
// https://support.google.com/analytics/answer/9756891
function defaultChannelGroup(src, med, camp) {
  const paid = `REGEXP_CONTAINS(${med}, r'${PAID_MEDIUM}')`;
  const shopCampaign = `REGEXP_CONTAINS(${camp}, r'${SHOPPING_CAMPAIGN}')`;
  return `CASE
      WHEN (${src} = '(direct)' OR ${src} IS NULL) AND (${med} IN ('(not set)', '(none)') OR ${med} IS NULL) THEN 'Direct'
      WHEN REGEXP_CONTAINS(${camp}, r'cross-network') THEN 'Cross-network'
      WHEN (${inSet(src, lists.shopping)} OR ${shopCampaign}) AND ${paid} THEN 'Paid Shopping'
      WHEN ${inSet(src, lists.search)} AND ${paid} THEN 'Paid Search'
      WHEN ${inSet(src, lists.social)} AND ${paid} THEN 'Paid Social'
      WHEN ${inSet(src, lists.video)} AND ${paid} THEN 'Paid Video'
      WHEN ${med} IN ('display', 'banner', 'expandable', 'interstitial', 'cpm') THEN 'Display'
      WHEN ${paid} THEN 'Paid Other'
      WHEN ${inSet(src, lists.shopping)} OR ${shopCampaign} THEN 'Organic Shopping'
      WHEN ${inSet(src, lists.social)} OR ${med} IN ('social', 'social-network', 'social-media', 'sm', 'social network', 'social media') THEN 'Organic Social'
      WHEN ${inSet(src, lists.video)} OR REGEXP_CONTAINS(${med}, r'^(.*video.*)$') THEN 'Organic Video'
      WHEN ${inSet(src, lists.search)} OR ${med} = 'organic' THEN 'Organic Search'
      WHEN ${inSet(src, lists.email_sources)} OR ${inSet(med, lists.email_sources)} THEN 'Email'
      WHEN ${med} = 'affiliate' THEN 'Affiliates'
      WHEN ${med} IN ('referral', 'app', 'link') THEN 'Referral'
      WHEN ${med} = 'audio' THEN 'Audio'
      WHEN ${src} = 'sms' OR ${med} = 'sms' THEN 'SMS'
      WHEN ENDS_WITH(${med}, 'push') OR REGEXP_CONTAINS(${med}, r'(mobile|notification)') OR ${src} = 'firebase' THEN 'Mobile Push Notifications'
      ELSE 'Unassigned'
    END`;
}

// our own grouping, closer to how a brazilian marketing team talks.
// needs the default group already calculated (dcg) to avoid repeating the big CASE
function customChannelGroup(src, med, camp, dcg) {
  const brand = helpers.regexFromList(project.brand_terms, false);
  const m = lists.custom_mediums;
  return `CASE
      WHEN ${dcg} = 'Direct' THEN 'Direct'
      WHEN ${inSet(src, lists.ai_assistants)} THEN 'AI Assistants'
      WHEN ${inSet(src, lists.cashback_coupons)} OR ${inSet(med, m.cashback)} THEN 'Cashback & Coupons'
      WHEN ${inSet(med, m.affiliates)} THEN 'Affiliates'
      WHEN ${inSet(med, m.influencers)} THEN 'Influencers'
      WHEN ${inSet(src, lists.whatsapp)} OR ${inSet(med, m.whatsapp)} THEN 'WhatsApp'
      WHEN ${dcg} = 'Paid Search' AND REGEXP_CONTAINS(COALESCE(${camp}, ''), r'(?i)${brand}') THEN 'Paid Search - Brand'
      WHEN ${dcg} = 'Paid Search' THEN 'Paid Search - Non-brand'
      WHEN ${inSet(src, lists.marketplaces)} AND NOT STARTS_WITH(${dcg}, 'Paid') THEN 'Marketplaces'
      WHEN ${dcg} = 'Email' OR ${inSet(med, m.crm)} THEN 'Email & CRM'
      WHEN ${dcg} IN ('SMS', 'Mobile Push Notifications') THEN 'SMS & Push'
      WHEN ${dcg} IN ('Paid Other', 'Audio') THEN 'Other Paid'
      ELSE ${dcg}
    END`;
}

function isPaymentGateway(src) {
  const pattern = lists.payment_gateway_patterns.join("|");
  return `(${inSet(src, lists.payment_gateways)} OR REGEXP_CONTAINS(COALESCE(${src}, ''), r'${pattern}'))`;
}

// own domain coming back as referral (subdomain jump, checkout in another host...)
function isSelfReferral(src) {
  const roots = Array.from(new Set(constants.SITE_HOSTNAMES.map(h => h.replace(/^www\./, ""))));
  if (roots.length === 0) return "FALSE";
  return `REGEXP_CONTAINS(COALESCE(${src}, ''), r'(^|\\.)(${roots.map(helpers.regexEscape).join("|")})$')`;
}

function isAiAssistant(src) {
  return inSet(src, lists.ai_assistants);
}

module.exports = {
  PAID_MEDIUM,
  SHOPPING_CAMPAIGN,
  normalizeSource,
  defaultChannelGroup,
  customChannelGroup,
  isPaymentGateway,
  isSelfReferral,
  isAiAssistant
};
