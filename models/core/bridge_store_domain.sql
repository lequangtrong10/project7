WITH source_data AS (
    SELECT
        store_id,
        domain
    FROM {{ ref('stg_store') }}
),

bridge AS (
    SELECT
        s.store_key,
        sd.domain
    FROM source_data sd
    INNER JOIN {{ ref('dim_store') }} s
        ON sd.store_id = s.store_id
)

SELECT
    *,
    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by
FROM bridge