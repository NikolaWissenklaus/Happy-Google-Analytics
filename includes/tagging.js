// author: Francisco Lucas / Nikola Wissenklaus / Chico

// tagging.js
//
// Checks on the STRUCTURE of the campaign urls. The VALUES of the utms (upper case, typos,
// unknown mediums...) are in mkt_utm_linter, here it is the url itself: the "?" that is missing,
// two params glued together, "&amp;", the utm after the "#", param names with typos, auto tagging
// ids without utms... Every one of these makes GA4 lose (or change) the attribution.

const VALID_UTM_PARAMS = [
  "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
  "utm_source_platform", "utm_creative_format", "utm_marketing_tactic"
];

// gclid with these mediums is fine, anything else is manual tagging fighting the auto tagging
const GOOGLE_PAID_MEDIUMS = ["cpc", "ppc", "paid", "paidsearch", "paid_search", "cpm", "display", "video"];

// ARRAY<STRING> with the problems of the url (empty array = clean)
function urlIssues(urlExpr) {
  const u = `LOWER(${urlExpr})`;
  // encoded separators and &amp; become "&" here, so they do not look like "glued" params too
  const decoded = `REGEXP_REPLACE(${u}, r'(%3f|%26|&amp;|&#0*38;)utm_', '&utm_')`;
  // utm_*, and the usual typos of the prefix (utm-, utmsource, umt_, utn_, um_)
  const names = `REGEXP_EXTRACT_ALL(${u}, r'[?&#;]((?:utm|umt|utn|um_)[a-z_.-]*)=')`;
  return `ARRAY(
    SELECT issue FROM UNNEST([
      IF(REGEXP_CONTAINS(${u}, r'utm_[a-z_]+=') AND NOT REGEXP_CONTAINS(${u}, r'\\?'), 'utm_without_question_mark', NULL),
      IF(REGEXP_CONTAINS(${u}, r'\\?') AND REGEXP_CONTAINS(${decoded}, r'[^?&#;_-]utm_[a-z_]+='), 'utm_glued_to_previous_param', NULL),
      IF(REGEXP_CONTAINS(${u}, r'\\?[^#]*\\?'), 'double_question_mark', NULL),
      IF(REGEXP_CONTAINS(${u}, r'[?&]utm_[a-z_]+=(&|#|$)'), 'empty_utm_value', NULL),
      IF(REGEXP_CONTAINS(${u}, r'&amp;(amp;)*utm_|&#0*38;utm_'), 'html_encoded_ampersand', NULL),
      IF(REGEXP_CONTAINS(${u}, r'(%3f|%26)utm_'), 'encoded_separator', NULL),
      IF(REGEXP_CONTAINS(${u}, r'#.*utm_[a-z_]+='), 'utm_after_hash', NULL),
      IF(EXISTS(SELECT 1 FROM UNNEST(REGEXP_EXTRACT_ALL(${urlExpr}, r'(?i)[?&#;](utm[a-z_]*)=')) AS n WHERE n != LOWER(n)), 'uppercase_utm_param_name', NULL),
      IF(EXISTS(SELECT 1 FROM UNNEST(${names}) AS n WHERE n NOT IN (${VALID_UTM_PARAMS.map(p => `'${p}'`).join(", ")})), 'invalid_utm_param_name', NULL),
      IF(EXISTS(SELECT 1 FROM UNNEST(REGEXP_EXTRACT_ALL(${u}, r'[?&#;](utm_[a-z_]+)=')) AS n GROUP BY n HAVING COUNT(*) > 1), 'duplicated_utm_param', NULL),
      IF(REGEXP_CONTAINS(${u}, r'[?&]msclkid=') AND NOT REGEXP_CONTAINS(${u}, r'[?&]utm_source='), 'msclkid_without_utm', NULL),
      IF(REGEXP_CONTAINS(${u}, r'[?&]ttclid=') AND NOT REGEXP_CONTAINS(${u}, r'[?&]utm_source='), 'ttclid_without_utm', NULL),
      IF(REGEXP_CONTAINS(${u}, r'[?&]fbclid=') AND NOT REGEXP_CONTAINS(${u}, r'[?&]utm_source='), 'fbclid_without_utm', NULL),
      IF(REGEXP_CONTAINS(${u}, r'[?&](gclid|gbraid|wbraid)=')
         AND REGEXP_EXTRACT(${u}, r'[?&]utm_medium=([^&#]*)') NOT IN (${GOOGLE_PAID_MEDIUMS.map(m => `'${m}'`).join(", ")}), 'gclid_with_conflicting_utm_medium', NULL)
    ]) AS issue
    WHERE issue IS NOT NULL
  )`;
}

// the param name that the typo probably wanted (closest valid one)
function closestUtmParam(nameExpr) {
  return `(SELECT p FROM UNNEST([${VALID_UTM_PARAMS.map(p => `'${p}'`).join(", ")}]) AS p ORDER BY EDIT_DISTANCE(${nameExpr}, p) LIMIT 1)`;
}

const ISSUE_SEVERITY = {
  utm_without_question_mark: "high",
  utm_glued_to_previous_param: "high",
  double_question_mark: "medium",
  empty_utm_value: "high",
  html_encoded_ampersand: "high",
  encoded_separator: "high",
  utm_after_hash: "high",
  uppercase_utm_param_name: "high",
  invalid_utm_param_name: "high",
  duplicated_utm_param: "medium",
  msclkid_without_utm: "high",
  ttclid_without_utm: "medium",
  fbclid_without_utm: "medium",
  gclid_with_conflicting_utm_medium: "low",
  internal_utm: "high",
  utm_not_on_first_page: "medium",
  utm_without_source_medium_event_param: "high",
  utm_ignored_by_ga4: "high"
};

const ISSUE_FIX = {
  utm_without_question_mark: "The url has '&utm_...' but no '?'. The first param must start with '?': /page?utm_source=...",
  utm_glued_to_previous_param: "Two params without '&' between them (utm_source=fbutm_medium=cpc). Fix the url template of the ad",
  double_question_mark: "Two '?' in the url (page?a=1?utm_source=x): the second one is part of a value. Use '&' after the first",
  empty_utm_value: "utm_source= or utm_medium= without value: the dynamic parameter of the platform came empty",
  html_encoded_ampersand: "&amp;utm_... : the url was copied from HTML (e-mail tool, CMS). GA4 reads a param called 'amp;utm_medium'",
  encoded_separator: "%3F / %26 before the utm: the url went through a redirect / shortener that encoded it. Fix the redirect",
  utm_after_hash: "utm after the '#': GA4 does not read the fragment. Put the utms before the '#'",
  uppercase_utm_param_name: "UTM_SOURCE / Utm_Medium: param names are case sensitive, use lower case",
  invalid_utm_param_name: "Param name with a typo (utm_souce, utm-medium, utm_campaing...): GA4 ignores it",
  duplicated_utm_param: "The same utm twice with different values: GA4 keeps the first, nobody knows which one is right",
  msclkid_without_utm: "Microsoft Ads click without utms: GA4 does not know msclkid, paid Bing becomes organic / referral. Add the utms in the account level tracking template",
  ttclid_without_utm: "TikTok Ads click without utms: becomes tiktok / referral. Add the utms in the ad url",
  fbclid_without_utm: "fbclid without utms. Organic posts get fbclid too, but if this landing comes from an ad, the ad has no utms and paid Meta mixes with organic",
  gclid_with_conflicting_utm_medium: "gclid + a utm_medium that is not cpc: manual tagging fighting the auto tagging. Keep the auto tagging alone",
  internal_utm: "utm in an internal link (banner, menu, e-mail signature pointing to the site): it rewrites the attribution of the session. Use internal promotion events instead",
  utm_not_on_first_page: "The utm only appeared after the first page (redirect / SPA added it late): the session already started without it",
  utm_without_source_medium_event_param: "The url had utms but no event of the session got the source / medium params: GA4 did not process them (tag fired before the url had the params, consent, redirect, SPA)",
  utm_ignored_by_ga4: "The url had utms but GA4 says the session was (direct) / (not set): the attribution was lost"
};

function severityCase(issueExpr) {
  return `CASE ${issueExpr} ${Object.entries(ISSUE_SEVERITY).map(([k, v]) => `WHEN '${k}' THEN '${v}'`).join(" ")} ELSE 'low' END`;
}

function fixCase(issueExpr) {
  return `CASE ${issueExpr} ${Object.entries(ISSUE_FIX).map(([k, v]) => `WHEN '${k}' THEN '${v.replace(/'/g, "\\'")}'`).join(" ")} END`;
}

module.exports = { VALID_UTM_PARAMS, GOOGLE_PAID_MEDIUMS, urlIssues, closestUtmParam, severityCase, fixCase, ISSUE_SEVERITY };
