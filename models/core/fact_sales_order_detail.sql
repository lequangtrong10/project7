{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='fact_pk',
    on_schema_change='sync_all_columns',
    partition_by={
        'field': 'order_timestamp',
        'data_type': 'timestamp',
        'granularity': 'day'
    },
    cluster_by=['currency_key', 'product_key']
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

deduplicated AS (
    SELECT
        order_id,
        product_id,

        ANY_VALUE(user_id_db) AS user_id_db,
        MIN(order_timestamp) AS order_timestamp,
        ANY_VALUE(store_id) AS store_id,
        ANY_VALUE(currency_code) AS currency_code,
        ANY_VALUE(ip_address) AS ip_address,
        ANY_VALUE(current_url) AS current_url,

        SUM(order_qty) AS order_qty,
        AVG(unit_price) AS unit_price,
        SUM(order_qty * unit_price) AS sales_amount

    FROM source_data

    GROUP BY
        order_id,
        product_id
),

fact_source AS (
    SELECT
        FARM_FINGERPRINT(
            CONCAT(
                CAST(product_id AS STRING),
                '|',
                CAST(order_id AS STRING)
            )
        ) AS fact_pk,

        order_id,
        product_id,
        user_id_db,
        order_timestamp,
        store_id,
        currency_code,
        ip_address,
        current_url,
        order_qty,
        unit_price,
        sales_amount

    FROM deduplicated
),

joined AS (
    SELECT
        f.fact_pk,
        f.order_id,
        COALESCE(p.product_key, -1) AS product_key,
        COALESCE(cu.customer_key, -1) AS customer_key,
        COALESCE(d.date_key, -1) AS date_key,
        COALESCE(s.store_key, -1) AS store_key,
        COALESCE(c.currency_key, -1) AS currency_key,
        COALESCE(m.location_key, -1) AS location_key,

        f.order_timestamp,
        f.ip_address,
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
        AND f.order_timestamp < cu.end_date

    LEFT JOIN {{ ref('dim_date') }} d
        ON DATE(f.order_timestamp) = d.full_date

    LEFT JOIN {{ ref('dim_product') }} p
        ON f.product_id = p.product_id

    LEFT JOIN {{ ref('dim_store') }} s
        ON f.store_id = s.store_id

    LEFT JOIN {{ ref('dim_currency') }} c
        ON f.currency_code = c.currency_code

    LEFT JOIN {{ ref('stg_dim_location') }} m
        ON f.ip_address = m.ip_address

    LEFT JOIN {{ ref('fact_exchange_rate') }} er
        ON c.currency_key = er.currency_key
)

SELECT *
FROM joined