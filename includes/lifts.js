// author: Francisco Lucas / Nikola Wissenklaus / Chico

// lifts.js
//
// Small helpers of the holdout logic, shared by the activation tables (who is NOT sent) and by
// lift_activation_holdouts (who was not sent, to compare). Both sides must use the same rule,
// that is why it lives here and not inside the models.

const cfgLifts = require("./cfg_lifts");
const cfgAudiences = require("./cfg_audiences");
const helpers = require("./helpers");

// holdout % of an audience: holdout_pct of the audience in cfg_audiences, else the default
function audienceHoldoutPct(audienceNameExpr) {
  const overrides = cfgAudiences.audiences.filter(a => a.holdout_pct !== undefined);
  if (overrides.length === 0) return String(cfgLifts.holdout.audiences_pct);
  return `CASE ${audienceNameExpr} ${overrides.map(a => `WHEN '${a.name}' THEN ${Number(a.holdout_pct)}`).join(" ")} ELSE ${cfgLifts.holdout.audiences_pct} END`;
}

// TRUE when the person is in the holdout of the audience (always FALSE with the holdout off)
function audienceHoldout(audienceNameExpr, userKeyExpr) {
  if (!cfgLifts.holdout.enabled) return "FALSE";
  return helpers.isHoldout(audienceNameExpr, userKeyExpr, audienceHoldoutPct(audienceNameExpr));
}

module.exports = { audienceHoldoutPct, audienceHoldout };
