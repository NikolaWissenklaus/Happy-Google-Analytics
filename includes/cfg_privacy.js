// author: Francisco Lucas / Nikola Wissenklaus / Chico

// cfg_privacy.js
//
// LGPD settings. Talk to your DPO (encarregado de dados) before changing this file,
// specially retention and the deletion stuff.

module.exports = {
  // query string keys that should NEVER reach analytics. if the dev team puts
  // ?email=fulano@x.com in a url (it happens, a lot), we redact the value.
  sensitive_url_keys: [
    "email", "e-mail", "e_mail", "mail", "user_email", "customer_email",
    "cpf", "cnpj", "rg", "documento", "document", "doc",
    "phone", "telefone", "tel", "celular", "whatsapp", "mobile",
    "nome", "name", "first_name", "last_name", "sobrenome", "fullname", "full_name",
    "endereco", "address", "street", "rua", "cep", "zipcode", "zip",
    "password", "senha", "pass", "pwd",
    "token", "access_token", "id_token", "auth", "session_token",
    "card", "cartao", "card_number", "cc", "cvv",
    "birthdate", "nascimento", "data_nascimento", "dob"
  ],

  // event params that are scanned for PII in priv_pii_findings. string params only.
  // empty list = scan every string param (more expensive, but finds the weird ones)
  params_to_scan: [],

  // user_id values that look like these are flagged in priv_user_id_quality.
  // user_id must be an internal id, never the email or the CPF in clear text.
  user_id_rules: {
    max_length: 128,
    forbid_email: true,
    forbid_cpf: true,
    forbid_phone: true
  },

  // custom consent params, for when the CMP (OneTrust, Cookiebot, Adopt, Usercentrics...)
  // also sends the consent as an event param. GA4 export only has analytics_storage and
  // ads_storage in privacy_info, ad_user_data and ad_personalization are NOT exported.
  consent_params: {
    ad_user_data: "consent_ad_user_data",
    ad_personalization: "consent_ad_personalization"
  },

  // LGPD art. 19: full answer to the titular in up to 15 days. priv_dsr_requests flags the overdue ones
  dsr_sla_days: 15,

  // data subject requests (LGPD art. 18). Use a real table in production (var dsr_table),
  // this list is just for tests and for small operations.
  // request_type: access | confirmation | portability | correction | deletion | anonymization | revocation
  // status: open -> approved (by the DPO, deletion only runs for these) -> done | rejected
  data_subject_requests: [
    // { request_id: "DSR-0001", request_type: "deletion", user_id: "12345", user_pseudo_id: null, requested_at: "2026-01-10", status: "open" }
  ],

  // what each dataset holds, used by priv_data_inventory (a ROPA-lite for the DPO)
  dataset_classification: {
    staging: { contains_personal_data: true, legal_basis: "legitimate_interest", notes: "pseudonymous ids, PII masked when mask_pii_in_urls=true" },
    intermediate: { contains_personal_data: true, legal_basis: "legitimate_interest", notes: "pseudonymous ids" },
    core: { contains_personal_data: true, legal_basis: "legitimate_interest", notes: "pseudonymous ids + user_id" },
    activation: { contains_personal_data: true, legal_basis: "consent", notes: "only users with ads consent, hashed identifiers" },
    privacy: { contains_personal_data: true, legal_basis: "legal_obligation", notes: "LGPD controls, restricted access" },
    seeds: { contains_personal_data: true, legal_basis: "legal_obligation", notes: "only seed_data_subject_requests, when dsr_table is not used" },
    segments: { contains_personal_data: true, legal_basis: "legitimate_interest", notes: "one row per user_key, pseudonymous" },
    ds: { contains_personal_data: true, legal_basis: "legitimate_interest", notes: "features and scores per user_key, pseudonymous" },
    attribution: { contains_personal_data: true, legal_basis: "legitimate_interest", notes: "touchpoints and paths per user_key, the rest is aggregated" },
    cro: { contains_personal_data: true, legal_basis: "legitimate_interest", notes: "session level scores (session_key)" },
    audiences: { contains_personal_data: true, legal_basis: "consent", notes: "pseudonymous ids, consent flag on each row" },
    crm: { contains_personal_data: true, legal_basis: "contract", notes: "joins with backend orders" },
    default: { contains_personal_data: false, legal_basis: "aggregated", notes: "aggregated data, no individual rows" }
  }
};
