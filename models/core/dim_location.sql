WITH dim_location_source AS (
    SELECT *
    FROM {{ ref('stg_dim_location') }}
),

dim_location_distinct AS (
    SELECT DISTINCT
        FARM_FINGERPRINT(
            CONCAT(
                COALESCE(country_code, ''), '|',
                COALESCE(region_name, ''), '|',
                COALESCE(city_name, '')
            )
        ) AS location_key,
        country_code,
        country_name,
        region_name,
        city_name
    FROM dim_location_source
),

dim_locaton_unknown_member AS (
    SELECT
        CAST(-1 AS INT64) AS location_key,
        'Undefined' AS country_code,
        'Undefined' AS country_name,
        'Undefined' AS region_name,
        'Undefined' AS city_name
),

dim_location_combined AS (
    SELECT *
    FROM dim_locaton_unknown_member

    UNION ALL

    SELECT *
    FROM dim_location_distinct
)

SELECT
    *,
    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by
FROM dim_location_combined