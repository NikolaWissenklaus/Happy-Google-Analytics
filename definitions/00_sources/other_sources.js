// author: Francisco Lucas / Nikola Wissenklaus / Chico

// Other optional sources. They are just declarations, nothing runs if the module is off.

// Meta Ads insights, usually loaded by Fivetran / Airbyte / Supermetrics / your own script.
// Expected columns are documented in stg_meta_ads__insights.sqlx
declare({
  database: constants.META_ADS.project,
  schema: constants.META_ADS.dataset,
  name: constants.META_ADS.table,
  description: "Meta Ads daily insights at ad level (optional, enable_meta_ads)"
});

// Search Console bulk export
declare({
  database: constants.SEARCH_CONSOLE.project,
  schema: constants.SEARCH_CONSOLE.dataset,
  name: "searchdata_site_impression",
  description: "Search Console bulk export, property level (optional, enable_search_console)"
});
declare({
  database: constants.SEARCH_CONSOLE.project,
  schema: constants.SEARCH_CONSOLE.dataset,
  name: "searchdata_url_impression",
  description: "Search Console bulk export, url level (optional, enable_search_console)"
});

// backend / CRM. expected columns in stg_crm__orders.sqlx and stg_crm__customers.sqlx
declare({
  database: constants.CRM.project,
  schema: constants.CRM.dataset,
  name: constants.CRM.orders_table,
  description: "Backend orders, source of truth for revenue (optional, enable_crm)"
});
declare({
  database: constants.CRM.project,
  schema: constants.CRM.dataset,
  name: constants.CRM.customers_table,
  description: "Backend customers (optional, enable_crm)"
});

// LGPD data subject requests, when they live in a table (var dsr_table = "project.dataset.table")
if (constants.PRIVACY.dsr_table) {
  const [dsrProject, dsrDataset, dsrTable] = constants.PRIVACY.dsr_table.split(".");
  declare({
    database: dsrProject,
    schema: dsrDataset,
    name: dsrTable,
    description: "LGPD data subject requests (requests from titulares)"
  });
}
