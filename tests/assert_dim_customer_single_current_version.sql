SELECT
    customer_id
FROM {{ ref('dim_customer') }}
WHERE is_current = TRUE
GROUP BY customer_id
HAVING COUNT(*) > 1