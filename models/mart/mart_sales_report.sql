{{ config(materialized='table') }}

SELECT
    f.fact_pk,
    f.order_id,
    f.order_timestamp,

    -- When
    d.full_date,
    d.year_number,
    d.quarter_number,
    d.month_number,
    d.month_name,
    d.day_name,
    d.is_weekend,

    -- What
    p.product_id,
    p.product_name,
    p.category_name,
    p.gender,

    -- Where
    l.country_name,
    l.city_name,
    s.store_id,

    -- Currency
    c.currency_code,
    c.currency_name,

    -- Measures
    f.order_qty,
    f.unit_price,
    f.sales_amount,
    f.rate_to_usd,
    f.sales_usd_price

FROM {{ ref('fact_sales_order_detail') }} f
LEFT JOIN {{ ref('dim_date') }} d ON f.date_key = d.date_key
LEFT JOIN {{ ref('dim_product') }} p ON f.product_key = p.product_key
LEFT JOIN {{ ref('dim_location') }} l ON f.location_key = l.location_key
LEFT JOIN {{ ref('dim_store') }} s ON f.store_key = s.store_key
LEFT JOIN {{ ref('dim_currency') }} c ON f.currency_key = c.currency_key