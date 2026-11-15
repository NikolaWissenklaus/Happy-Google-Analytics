-- author: Francisco Lucas / Nikola Wissenklaus / Chico

-- landing pages with the biggest money on the table: converting below the median of the same
-- page type and device. revenue_opportunity_30d = (median conversion of the type - page conversion)
-- x sessions x AOV of the type. Look at conversion_wilson_high too: if even the upper bound is
-- below the median, it is not bad luck, the page really converts less

SELECT
  landing_page_path,
  landing_page_type,
  device_category,
  sessions,
  conversion_rate,
  page_type_median_conversion,
  conversion_wilson_low,
  conversion_wilson_high,
  bounce_rate_ga4,
  avg_engagement_time_sec,
  revenue_opportunity_30d
FROM `your-gcp-project.ga4_cro.cro_landing_pages`
WHERE revenue_opportunity_30d > 0
ORDER BY revenue_opportunity_30d DESC
LIMIT 30;

-- the friction signals of those pages (rage clicks, errors, slow web vitals...)
SELECT *
FROM `your-gcp-project.ga4_product.prod_ux_friction_signals`
ORDER BY 1 DESC
LIMIT 50;
