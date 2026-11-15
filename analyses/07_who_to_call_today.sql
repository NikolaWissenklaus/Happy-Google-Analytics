-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- valuable customers going away: high CLV (BTYD) and dropping p_alive, plus the CRM triggers of
-- today. Only identified customers that can receive CRM contact (consent gate).

SELECT
  c.user_key,
  t.user_id,
  c.clv_revenue,
  c.clv_decile,
  c.p_alive,
  c.alive_band,
  c.expected_purchases,
  c.last_purchase_date,
  t.lifecycle_stage,
  t.favorite_category,
  t.churn_risk
FROM `your-gcp-project.ga4_data_science.ds_btyd_customer_clv` AS c
JOIN `your-gcp-project.ga4_activation.act_crm_user_traits` AS t USING (user_key)
WHERE c.clv_decile >= 8
  AND c.p_alive < 0.5
ORDER BY c.clv_revenue DESC
LIMIT 100;

-- today's triggers (abandoned checkout first, biggest value first)
SELECT trigger_name, priority, user_id, value_at_stake, items
FROM `your-gcp-project.ga4_activation.act_crm_triggers`
ORDER BY trigger_name = 'abandoned_checkout' DESC, priority
LIMIT 200;
