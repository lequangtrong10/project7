WITH source_data AS (
    SELECT
        store_id
    FROM {{ ref('stg_glamira_raw') }}
    WHERE store_id IS NOT NULL
      AND TRIM(store_id) != ''
),

deduplicated AS (
    SELECT DISTINCT
        store_id
    FROM source_data
)

SELECT
    FARM_FINGERPRINT(store_id) AS store_key,
    store_id,
    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by
FROM deduplicated