{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='fact_pk',
    on_schema_change='sync_all_columns'
) }}
WITH source_data AS (
    SELECT *
    FROM {{ ref('stg_glamira_raw') }}
    {% if is_incremental() %}
        WHERE order_timestamp >= (
            SELECT MAX(order_timestamp)
            FROM {{ this }}
        )
    {% endif %}
),
fact_source AS (
    SELECT
        FARM_FINGERPRINT(
            CONCAT(
                CAST(_id AS STRING),
                '|',
                CAST(cart_index AS STRING)
            )
        ) AS fact_pk,
        _id,
        order_id,
        cart_index,
        user_id_db,
        order_timestamp,
        product_id,
        store_id,
        currency_code,
        ip,
        current_url,
        order_qty,
        unit_price,
        order_qty * unit_price AS sales_amount
    FROM source_data
),
joined AS (
    SELECT
        f.fact_pk,
        f.order_id,
        f.cart_index,
        COALESCE(cu.customer_key, -1) AS customer_key,
        COALESCE(d.date_key, -1)      AS date_key,
        COALESCE(p.product_key, -1)   AS product_key,
        COALESCE(s.store_key, -1)     AS store_key,
        COALESCE(c.currency_key, -1)  AS currency_key,
        COALESCE(m.location_key, -1)  AS location_key,
        f.order_timestamp,
        f.ip,
        f.current_url,
        f.currency_code,
        f.order_qty,
        f.unit_price,
        f.sales_amount,
        er.rate_to_usd,
        f.unit_price * er.rate_to_usd AS unit_price_usd,
        f.sales_amount * er.rate_to_usd AS sales_usd_price,
        CURRENT_TIMESTAMP() AS inserted_date,
        'dbt' AS inserted_by,
        CURRENT_TIMESTAMP() AS updated_date,
        'dbt' AS updated_by
    FROM fact_source f
    LEFT JOIN {{ ref('dim_customer') }} cu
        ON f.user_id_db = cu.customer_id
        AND f.order_timestamp >= cu.start_date
        AND (
            f.order_timestamp < cu.end_date
            OR cu.end_date IS NULL
        )
    LEFT JOIN {{ ref('dim_date') }} d
        ON DATE(f.order_timestamp) = d.full_date
    LEFT JOIN {{ ref('dim_product') }} p
        ON f.product_id = p.product_id
    LEFT JOIN {{ ref('dim_store') }} s
        ON f.store_id = s.store_id
    LEFT JOIN {{ ref('dim_currency') }} c
        ON f.currency_code = c.currency_code
    LEFT JOIN {{ ref('map_ip_location') }} m
        ON f.ip = m.ip
    LEFT JOIN {{ ref('fact_exchange_rate') }} er
        ON c.currency_key = er.currency_key
)
SELECT *
FROM joined