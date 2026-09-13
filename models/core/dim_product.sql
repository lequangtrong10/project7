WITH source_data AS (
    SELECT *
    FROM {{ ref('stg_products') }}
),

product_dimension AS (
    SELECT
        FARM_FINGERPRINT(CAST(product_id AS STRING)) AS product_key,
        CAST(product_id AS STRING) AS product_id,
        product_name,
        sku,
        category_name,
        product_type_value,
        product_type,
        type_id,
        COALESCE(collection_id, -1) AS collection_id,
        collection,
        gender,
        price,
        min_price,
        max_price,
        attribute_set,
        COALESCE(attribute_set_id, -1) AS attribute_set_id,
        store_code AS crawl_site_code
    FROM source_data
),

unknown_member AS (
    SELECT
        CAST(-1 AS INT64) AS product_key,
        'UNKNOWN' AS product_id,
        'Unknown Product' AS product_name,
        'Undefined' AS sku,
        'Undefined' AS category_name,
        CAST(NULL AS INT64) AS product_type_value,
        'Undefined' AS product_type,
        'Undefined' AS type_id,
        CAST(-1 AS INT64) AS collection_id,
        'Undefined' AS collection,
        'Undefined' AS gender,
        CAST(NULL AS FLOAT64) AS price,
        CAST(NULL AS FLOAT64) AS min_price,
        CAST(NULL AS FLOAT64) AS max_price,
        'Undefined' AS attribute_set,
        CAST(-1 AS INT64) AS attribute_set_id,
        'Undefined' AS crawl_site_code
),

combined AS (
    SELECT
        product_key, product_id, product_name, sku, category_name,
        product_type_value, product_type, type_id, collection_id, collection,
        gender, price, min_price, max_price, attribute_set, attribute_set_id,
        crawl_site_code
    FROM unknown_member

    UNION ALL

    SELECT
        product_key, product_id, product_name, sku, category_name,
        product_type_value, product_type, type_id, collection_id, collection,
        gender, price, min_price, max_price, attribute_set, attribute_set_id,
        crawl_site_code
    FROM product_dimension
)

SELECT
    *,
    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by
FROM combined