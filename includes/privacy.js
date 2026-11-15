// author: Francisco Lucas / Nikola Wissenklaus / Chico

// privacy.js
//
// SQL builders for PII masking and detection (LGPD).
// Masking is applied in staging, so the raw PII never leaves the GA4 export dataset.
// Detection (priv_pii_findings) reads the raw export on purpose, to find what leaked.
//
// Regex notes: RE2 has no lookbehind, so the patterns are a bit "manual".
// CPF/CNPJ with check digits are validated by the JS UDFs, here we only catch
// the formatted ones (000.000.000-00), unformatted 11 digits could be a product id.

const constants = require("./constants");
const helpers = require("./helpers");
const cfg = require("./cfg_privacy");

const PATTERNS = {
  email: "(?i)[a-z0-9._%+-]+(?:@|%40)[a-z0-9.-]+\\.[a-z]{2,}",
  cpf_formatted: "\\b\\d{3}\\.\\d{3}\\.\\d{3}-\\d{2}\\b",
  // CNPJ alfanumerico (since jul/2026 the first 12 chars can be letters)
  cnpj_formatted: "\\b[0-9A-Z]{2}\\.[0-9A-Z]{3}\\.[0-9A-Z]{3}/[0-9A-Z]{4}-\\d{2}\\b",
  phone_br: "(?:\\+55[\\s.-]?)?\\(\\d{2}\\)[\\s.-]?9?\\d{4}[\\s.-]?\\d{4}|\\+55[\\s.-]?\\d{2}[\\s.-]?9?\\d{4}[\\s.-]?\\d{4}",
  cep: "\\b\\d{5}-\\d{3}\\b",
  // candidates only, luhn_check() decides
  card_candidate: "\\b(?:\\d[ -]?){12,18}\\d\\b",
  // raw 11 digits, validated with is_valid_cpf()
  cpf_candidate: "\\b\\d{11}\\b"
};

function sensitiveKeysRegex() {
  return cfg.sensitive_url_keys.map(helpers.regexEscape).join("|");
}

// redact sensitive query string values + anything that looks like email/cpf/cnpj/phone
function maskText(expr) {
  let sql = expr;
  sql = `REGEXP_REPLACE(${sql}, r'(?i)([?&#;](?:${sensitiveKeysRegex()})=)[^&#;]*', r'\\1[redacted]')`;
  sql = `REGEXP_REPLACE(${sql}, r'${PATTERNS.email}', '[email]')`;
  sql = `REGEXP_REPLACE(${sql}, r'${PATTERNS.cpf_formatted}', '[cpf]')`;
  sql = `REGEXP_REPLACE(${sql}, r'${PATTERNS.cnpj_formatted}', '[cnpj]')`;
  sql = `REGEXP_REPLACE(${sql}, r'${PATTERNS.phone_br}', '[phone]')`;
  return sql;
}

// returns an ARRAY<STRING> with the kinds of PII found in expr.
// cpfFn / cnpjFn / luhnFn are the persistent UDF names (pass ref("is_valid_cpf") etc)
function detectKinds(expr, { cpfFn, cnpjFn, luhnFn }) {
  return `ARRAY(
    SELECT kind FROM UNNEST([
      IF(REGEXP_CONTAINS(${expr}, r'${PATTERNS.email}'), 'email', NULL),
      IF(EXISTS(SELECT 1 FROM UNNEST(REGEXP_EXTRACT_ALL(${expr}, r'${PATTERNS.cpf_formatted}|${PATTERNS.cpf_candidate}')) AS c WHERE ${cpfFn}(c)), 'cpf', NULL),
      IF(EXISTS(SELECT 1 FROM UNNEST(REGEXP_EXTRACT_ALL(UPPER(${expr}), r'${PATTERNS.cnpj_formatted}|\\b\\d{14}\\b')) AS c WHERE ${cnpjFn}(c)), 'cnpj', NULL),
      IF(REGEXP_CONTAINS(${expr}, r'${PATTERNS.phone_br}'), 'phone_br', NULL),
      IF(REGEXP_CONTAINS(${expr}, r'${PATTERNS.cep}'), 'cep', NULL),
      IF(EXISTS(SELECT 1 FROM UNNEST(REGEXP_EXTRACT_ALL(${expr}, r'${PATTERNS.card_candidate}')) AS c WHERE ${luhnFn}(c)), 'credit_card', NULL),
      IF(REGEXP_CONTAINS(${expr}, r'(?i)[?&#;](?:${sensitiveKeysRegex()})=[^&#;]+'), 'sensitive_url_key', NULL)
    ]) AS kind
    WHERE kind IS NOT NULL
  )`;
}

// for the examples we keep in the privacy tables: maskText + any long run of digits
// (raw CPF, card, phone, CEP). never store the real value, not even hashed:
// a CPF has 10^9 possibilities, any laptop reverses that SHA256 in minutes
function maskForSample(expr) {
  return `SUBSTR(REGEXP_REPLACE(${maskText(expr)}, r'\\d[\\d .-]{6,}\\d', '[digits]'), 1, 300)`;
}

// where the data subject requests come from: the real table (var dsr_table) or the seed
function dsrSourceName() {
  return constants.PRIVACY.dsr_table ? constants.PRIVACY.dsr_table.split(".")[2] : "seed_data_subject_requests";
}

// columns that point to a person (pseudonymous or not). session_key starts with the
// user_pseudo_id, so it counts too
const IDENTIFIER_COLUMNS = ["user_pseudo_id", "user_id", "user_key", "session_key"];

// the WHERE piece for one identifier column, as a SQL expression that builds the text.
// session_key = user_pseudo_id + '.' + ga_session_id (and user_pseudo_id has a dot inside
// too), user_key = 'uid:<user_id>' or 'dev:<user_pseudo_id>'.
//   mode "plain":  compares with the ids in priv_dsr_identifiers (the preview, before anything)
//   mode "hashed": compares SHA256 with priv_dsr_suppression_list (the deletion). The list
//                  survives the deletion of int_ga4__user_id_pairs_daily, so the re runs of the
//                  next days still find every device of the person
function idConditionSql(source, mode) {
  if (mode === "hashed") {
    const hashedIn = idType => `(SELECT value_sha256 FROM ${source} WHERE ${idType ? `id_type = '${idType}' AND ` : ""}request_id IN UNNEST(@requests))`;
    return `CASE c.column_name
        WHEN 'session_key' THEN "TO_HEX(SHA256(REGEXP_EXTRACT(session_key, r'^(.*)[.][^.]+$'))) IN ${hashedIn("user_pseudo_id")}"
        WHEN 'user_key' THEN "TO_HEX(SHA256(REGEXP_EXTRACT(user_key, r'^[a-z]+:(.*)$'))) IN ${hashedIn(null)}"
        ELSE FORMAT("TO_HEX(SHA256(%s)) IN (SELECT value_sha256 FROM ${source} WHERE id_type = '%s' AND request_id IN UNNEST(@requests))", c.column_name, c.column_name)
      END`;
  }
  return `CASE c.column_name
        WHEN 'session_key' THEN "REGEXP_EXTRACT(session_key, r'^(.*)[.][^.]+$') IN (SELECT value FROM ${source} WHERE id_type = 'user_pseudo_id' AND request_id IN UNNEST(@requests))"
        ELSE FORMAT("%s IN (SELECT value FROM ${source} WHERE id_type = '%s' AND request_id IN UNNEST(@requests))", c.column_name, c.column_name)
      END`;
}

// every BASE TABLE of this project (our datasets only) with at least one identifier column,
// and the WHERE that finds the rows of the people of the requests in @requests.
// privacy / seeds / ops are skipped: the requests themselves are a legal record
function userLevelTablesSql(source, mode = "plain") {
  const skip = [constants.SCHEMAS.privacy, constants.SCHEMAS.seeds, constants.SCHEMAS.ops];
  return `
    SELECT
      c.table_schema,
      c.table_name,
      ARRAY_AGG(c.column_name ORDER BY c.column_name) AS id_columns,
      STRING_AGG(${idConditionSql(source, mode)}, ' OR ') AS id_condition
    FROM ${constants.regionTable("COLUMNS")} AS c
    JOIN ${constants.regionTable("TABLES")} AS t USING (table_catalog, table_schema, table_name)
    WHERE STARTS_WITH(c.table_schema, '${constants.SCHEMA_PREFIX}_')
      AND c.table_schema NOT IN (${helpers.sqlList(skip)})
      AND t.table_type = 'BASE TABLE'
      AND c.data_type = 'STRING'
      AND c.column_name IN (${helpers.sqlList(IDENTIFIER_COLUMNS)})
    GROUP BY 1, 2`;
}

// same idea for the GA4 export dataset itself (events_YYYYMMDD, pseudonymous_users_YYYYMMDD, users_YYYYMMDD)
function rawExportTablesSql(source, mode = "plain") {
  return `
    SELECT
      c.table_name,
      STRING_AGG(${idConditionSql(source, mode)}, ' OR ') AS id_condition
    FROM \`${constants.GA4_PROJECT}.${constants.GA4_DATASET}.INFORMATION_SCHEMA.COLUMNS\` AS c
    WHERE REGEXP_CONTAINS(c.table_name, r'^(events|events_intraday|pseudonymous_users|users)_\\d{8}$')
      AND c.data_type = 'STRING'
      AND c.column_name IN ('user_pseudo_id', 'user_id')
    GROUP BY 1`;
}

// approved deletion requests still to process. a request is processed again during 4 days
// after the first deletion, because GA4 rewrites shards up to 72h later
function pendingDeletionRequestsSql(identifiers, log) {
  return `(
    SELECT ARRAY_AGG(DISTINCT i.request_id)
    FROM ${identifiers} AS i
    LEFT JOIN (
      SELECT request_id, MIN(deleted_at) AS first_deleted_at
      FROM ${log}, UNNEST(request_ids) AS request_id
      GROUP BY request_id
    ) AS l ON l.request_id = i.request_id
    WHERE i.request_type IN ('deletion', 'anonymization')
      AND i.status = 'approved'
      AND (l.first_deleted_at IS NULL OR l.first_deleted_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 4 DAY))
  )`;
}

// staging drops everybody in the suppression list (people whose data was deleted).
// without it the next full refresh brings them back from the raw export.
// the list only has SHA256 of the ids: enough to block, useless to identify anyone
function suppressionFilter(listRef, { pseudoColumn = "user_pseudo_id", userIdColumn = "user_id" } = {}) {
  const parts = [];
  if (pseudoColumn) {
    parts.push(`AND (${pseudoColumn} IS NULL OR TO_HEX(SHA256(${pseudoColumn})) NOT IN (
      SELECT value_sha256 FROM ${listRef} WHERE id_type = 'user_pseudo_id' AND value_sha256 IS NOT NULL))`);
  }
  if (userIdColumn) {
    parts.push(`AND (${userIdColumn} IS NULL OR TO_HEX(SHA256(${userIdColumn})) NOT IN (
      SELECT value_sha256 FROM ${listRef} WHERE id_type = 'user_id' AND value_sha256 IS NOT NULL))`);
  }
  return parts.join("\n    ");
}

// user level tables partitioned by a DATE column, for the retention purge
function partitionedUserTablesSql() {
  const skip = [constants.SCHEMAS.privacy, constants.SCHEMAS.seeds, constants.SCHEMAS.ops];
  return `
    WITH id_tables AS (
      SELECT DISTINCT table_schema, table_name
      FROM ${constants.regionTable("COLUMNS")}
      WHERE STARTS_WITH(table_schema, '${constants.SCHEMA_PREFIX}_')
        AND table_schema NOT IN (${helpers.sqlList(skip)})
        AND column_name IN (${helpers.sqlList(IDENTIFIER_COLUMNS)})
    )
    SELECT c.table_schema, c.table_name, c.column_name AS partition_column
    FROM ${constants.regionTable("COLUMNS")} AS c
    JOIN ${constants.regionTable("TABLES")} AS t USING (table_catalog, table_schema, table_name)
    JOIN id_tables AS i USING (table_schema, table_name)
    WHERE t.table_type = 'BASE TABLE'
      AND c.is_partitioning_column = 'YES'
      AND c.data_type = 'DATE'`;
}

module.exports = {
  PATTERNS,
  IDENTIFIER_COLUMNS,
  maskText,
  maskForSample,
  detectKinds,
  sensitiveKeysRegex,
  dsrSourceName,
  pendingDeletionRequestsSql,
  suppressionFilter,
  userLevelTablesSql,
  rawExportTablesSql,
  partitionedUserTablesSql
};
