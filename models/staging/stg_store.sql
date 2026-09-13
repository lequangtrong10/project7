WITH source_data AS (
    SELECT
        store_id,
        current_url
    FROM {{ ref('stg_glamira_raw') }}
    WHERE store_id IS NOT NULL
      AND TRIM(store_id) != ''
      AND current_url IS NOT NULL
),

resolved AS (
    SELECT DISTINCT
        store_id,
        CASE
            WHEN current_url LIKE 'file://%' THEN NULL
            ELSE NET.HOST(current_url)
        END AS domain
    FROM source_data
)

SELECT
    store_id,
    domain
FROM resolved
WHERE domain IS NOT NULL