WITH source_data AS (
    SELECT
        _id,
        REGEXP_REPLACE(order_id, r'\.0$', '') AS order_id,
        user_id_db,
        email_address,
        TIMESTAMP_SECONDS(time_stamp) AS order_timestamp,
        store_id,
        currency,
        ip,
        current_url,
        device_id,
        user_agent,
        resolution,
        price AS raw_price,
        cart_products
    FROM {{ source('raw', 'glamira_raw') }}
    WHERE collection = 'checkout_success'
),

expanded_cart AS (
    SELECT
        source_data.*,
        cart_product.product_id AS product_id,
        cart_product.amount AS order_qty,
        cart_product.price AS product_price,
        cart_product.currency AS raw_product_currency,
        cart_index
    FROM source_data
    CROSS JOIN UNNEST(cart_products) AS cart_product
    WITH OFFSET AS cart_index
),

mapped_currency AS (
    SELECT
        expanded_cart.*,
        COALESCE(
            NULLIF(TRIM(raw_product_currency), ''),
            NULLIF(TRIM(currency_mapping.product_currency), ''),
            NULLIF(TRIM(currency), '')
        ) AS product_currency
    FROM expanded_cart
    LEFT JOIN {{ ref('currency_url_mapping') }} AS currency_mapping
        ON expanded_cart.current_url = currency_mapping.current_url
),
parsed_price AS (
    SELECT
        mapped_currency.*,
        CASE
            WHEN product_currency = '￥'
                 AND REGEXP_CONTAINS(TRIM(product_price), r'^\d{1,3}(,\d{3})+(\.00)?$')
            THEN CAST(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(TRIM(product_price), ',', ''),
                    r'\.00$',
                    ''
                ) AS NUMERIC
            )

            WHEN REGEXP_CONTAINS(TRIM(product_price), r'٫\d{2}$')
            THEN CAST(REPLACE(TRIM(product_price), '٫', '.') AS NUMERIC)

            WHEN REGEXP_CONTAINS(TRIM(product_price), r"^\d{1,3}('\d{3})+\.\d{2}$")
            THEN CAST(
                REGEXP_REPLACE(TRIM(product_price), r"'", '') AS NUMERIC
            )

            WHEN REGEXP_CONTAINS(TRIM(product_price), r',\d{2}$')
            THEN CAST(
                REPLACE(REPLACE(TRIM(product_price), '.', ''), ',', '.') AS NUMERIC
            )

            WHEN REGEXP_CONTAINS(TRIM(product_price), r'\.\d{2}$')
            THEN CAST(
                REPLACE(TRIM(product_price), ',', '') AS NUMERIC
            )

            WHEN product_price IS NULL OR TRIM(product_price) = ''
            THEN NULL

            ELSE NULL
        END AS unit_price
    FROM mapped_currency
),

resolved_currency AS (
    SELECT
        parsed_price.*,
        CASE
            WHEN product_currency = '€' THEN 'EUR'
            WHEN product_currency = '£' THEN 'GBP'
            WHEN product_currency = 'CHF' THEN 'CHF'
            WHEN product_currency = 'zł' THEN 'PLN'
            WHEN product_currency = 'Kč' THEN 'CZK'
            WHEN product_currency = 'Ft' THEN 'HUF'
            WHEN product_currency = '₺' THEN 'TRY'
            WHEN product_currency = '₱' THEN 'PHP'
            WHEN product_currency = '₫' THEN 'VND'
            WHEN product_currency = '₹' THEN 'INR'
            WHEN product_currency = '₲' THEN 'PYG'
            WHEN product_currency = 'R$' THEN 'BRL'
            WHEN product_currency = 'RON' THEN 'RON'
            WHEN product_currency = 'AED' THEN 'AED'
            WHEN product_currency = 'ZAR' THEN 'ZAR'
            WHEN product_currency = 'SGD $' THEN 'SGD'
            WHEN product_currency = 'CAD $' THEN 'CAD'
            WHEN product_currency = 'AU $' THEN 'AUD'
            WHEN product_currency = 'NZD $' THEN 'NZD'
            WHEN product_currency = 'MXN $' THEN 'MXN'
            WHEN product_currency = 'USD $' THEN 'USD'
            WHEN product_currency = 'COP $' THEN 'COP'
            WHEN product_currency = 'HKD $' THEN 'HKD'
            WHEN product_currency = 'CRC ₡' THEN 'CRC'
            WHEN product_currency = 'GTQ Q' THEN 'GTQ'
            WHEN product_currency = 'PEN S/.' THEN 'PEN'
            WHEN product_currency = 'BOB Bs' THEN 'BOB'
            WHEN product_currency = 'DOP $' THEN 'DOP'
            WHEN product_currency = 'CLP' THEN 'CLP'
            WHEN product_currency = 'лв.' THEN 'BGN'
            WHEN product_currency = 'kn' THEN 'HRK'
            WHEN product_currency = 'Lei' THEN 'MDL'
            WHEN product_currency = 'UYU' THEN 'UYU'
            WHEN product_currency = 'kr' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.se') THEN 'SEK'
            WHEN product_currency = 'kr' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.dk') THEN 'DKK'
            WHEN product_currency = 'kr' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.no') THEN 'NOK'
            WHEN product_currency = '$' AND REGEXP_CONTAINS(LOWER(current_url), r'/glus/') THEN 'USD'
            WHEN product_currency = '$' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.com/') THEN 'USD'
            WHEN product_currency = '$' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.com\.ar') THEN 'ARS'
            WHEN product_currency = '$' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.hk') THEN 'HKD'
            WHEN product_currency = '￥' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.jp') THEN 'JPY'
            WHEN product_currency = '￥' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.cn') THEN 'CNY'
            WHEN product_currency = 'din.' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.rs') THEN 'RSD'
            WHEN product_currency = 'د.ك.‏' AND REGEXP_CONTAINS(LOWER(current_url), r'glamira\.com\.kw') THEN 'KWD'
            ELSE NULL
        END AS currency_code
    FROM parsed_price
)

SELECT
    order_id,
    user_id_db,
    email_address,
    order_timestamp,
    store_id,
    currency,
    ip as ip_address,
    current_url,
    device_id,
    user_agent,
    resolution,
    product_id,
    order_qty,
    product_price,
    unit_price,
    product_currency,
    currency_code,
    cart_index,
    raw_product_currency,
    raw_price
FROM resolved_currency