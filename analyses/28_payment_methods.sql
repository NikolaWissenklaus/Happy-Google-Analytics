-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- PIX, boleto or card: what each payment method does to the business.
-- boleto that is never paid inflates the GA4 revenue, card has higher tickets (installments),
-- PIX is fast and cheap. Choose the default method, the PIX discount and the installment rules
-- with numbers.

-- 1) mix, ticket, unpaid deferred payments and refunds per method, by month
SELECT
  DATE_TRUNC(transaction_date, MONTH) AS month,
  COALESCE(LOWER(payment_type), '(not set)') AS payment_type,
  COUNT(*) AS orders,
  SUM(revenue) AS revenue,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER (PARTITION BY DATE_TRUNC(transaction_date, MONTH))) AS share_of_orders,
  AVG(revenue) AS aov,
  SAFE_DIVIDE(COUNTIF(is_deferred_payment), COUNT(*)) AS share_deferred,
  SAFE_DIVIDE(SUM(refunded_value), SUM(revenue)) AS refund_rate_value,
  SAFE_DIVIDE(COUNTIF(is_first_purchase), COUNT(*)) AS share_new_customers
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH)
  AND NOT is_test_transaction
GROUP BY 1, 2
ORDER BY 1 DESC, orders DESC;

-- 2) the method by the ticket: from which order value people move from PIX to card (installments)
SELECT
  CASE
    WHEN revenue < 100 THEN '0_100'
    WHEN revenue < 200 THEN '100_200'
    WHEN revenue < 400 THEN '200_400'
    WHEN revenue < 800 THEN '400_800'
    WHEN revenue < 1500 THEN '800_1500'
    ELSE '1500_plus'
  END AS order_value_band,
  COALESCE(LOWER(payment_type), '(not set)') AS payment_type,
  COUNT(*) AS orders,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER (PARTITION BY CASE
    WHEN revenue < 100 THEN '0_100' WHEN revenue < 200 THEN '100_200' WHEN revenue < 400 THEN '200_400'
    WHEN revenue < 800 THEN '400_800' WHEN revenue < 1500 THEN '800_1500' ELSE '1500_plus' END)) AS share_in_band
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE is_valid_for_revenue AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 180 DAY)
GROUP BY 1, 2
ORDER BY 1, orders DESC;

-- 3) GA4 revenue vs paid revenue (needs enable_crm): how much of the boleto / PIX never turned into money
SELECT
  COALESCE(LOWER(payment_type), '(not set)') AS payment_type,
  COUNT(*) AS orders,
  SUM(revenue) AS ga4_revenue,
  SUM(IF(crm_paid_ts IS NOT NULL, crm_order_value, 0)) AS paid_revenue,
  SAFE_DIVIDE(SUM(IF(crm_paid_ts IS NOT NULL, crm_order_value, 0)), SUM(revenue)) AS paid_share
FROM `your-gcp-project.ga4_core.fct_transactions`
WHERE transaction_date BETWEEN DATE_SUB(CURRENT_DATE(), INTERVAL 60 DAY) AND DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND NOT is_test_transaction
GROUP BY 1
ORDER BY ga4_revenue DESC;

-- 4) payment retries: sessions that tried to pay more than once and how many made it (card declined?)
SELECT
  COALESCE(LOWER(last_payment_type), '(not set)') AS payment_type,
  COUNTIF(has_payment_retries) AS sessions_with_retries,
  SAFE_DIVIDE(COUNTIF(has_payment_retries AND has_purchase), COUNTIF(has_payment_retries)) AS success_after_retry,
  SUM(IF(has_payment_retries AND NOT has_purchase, checkout_value, 0)) AS value_lost_after_retries
FROM `your-gcp-project.ga4_core.fct_sessions`
WHERE session_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY) AND has_add_payment_info AND NOT is_bot_suspect
GROUP BY 1
ORDER BY value_lost_after_retries DESC;
