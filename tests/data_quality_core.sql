WITH violations AS (

    -- 1. dim_date: day_of_week must be between 1 and 7
    SELECT
        'dim_date.day_of_week' AS test_name
    FROM {{ ref('dim_date') }}
    WHERE day_of_week IS NULL
       OR day_of_week < 1
       OR day_of_week > 7

    UNION ALL

    -- 2. dim_date: month_number must be between 1 and 12
    SELECT
        'dim_date.month_number' AS test_name
    FROM {{ ref('dim_date') }}
    WHERE month_number IS NULL
       OR month_number < 1
       OR month_number > 12

    UNION ALL

    -- 3. dim_date: quarter_number must be between 1 and 4
    SELECT
        'dim_date.quarter_number' AS test_name
    FROM {{ ref('dim_date') }}
    WHERE quarter_number IS NULL
       OR quarter_number < 1
       OR quarter_number > 4

    UNION ALL

    -- 4. fact_exchange_rate: rate_to_usd must be positive
    SELECT
        'fact_exchange_rate.rate_to_usd' AS test_name
    FROM {{ ref('fact_exchange_rate') }}
    WHERE rate_to_usd IS NULL
       OR rate_to_usd <= 0

    UNION ALL

    -- 5. fact_sales_order_detail: order_qty must be positive
    SELECT
        'fact_sales_order_detail.order_qty' AS test_name
    FROM {{ ref('fact_sales_order_detail') }}
    WHERE order_qty IS NULL
       OR order_qty <= 0
)

SELECT *
FROM violations