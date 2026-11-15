// author: Francisco Lucas / Nikola Wissenklaus / Chico

// content.js
//
// Page classification helpers (page type, 404 detection), generated from cfg_project.js

const project = require("./cfg_project");
const helpers = require("./helpers");

// CASE that turns a page_path into a page type. first match wins, order of the config
function pageTypeCase(pathExpr) {
  const whens = project.page_types.map(p => `WHEN REGEXP_CONTAINS(${pathExpr}, r'${p.pattern}') THEN '${p.type}'`);
  return `CASE\n      WHEN ${pathExpr} IS NULL THEN '(not set)'\n      ${whens.join("\n      ")}\n      ELSE 'other'\n    END`;
}

// page_title says 404 / not found / pagina nao encontrada (accents removed before)
function isNotFoundTitle(titleExpr) {
  const pattern = helpers.regexFromList(project.not_found_title_patterns, false);
  return `COALESCE(REGEXP_CONTAINS(LOWER(REGEXP_REPLACE(NORMALIZE(${titleExpr}, NFD), r'\\p{M}', '')), r'${pattern}'), FALSE)`;
}

module.exports = { pageTypeCase, isNotFoundTitle };
