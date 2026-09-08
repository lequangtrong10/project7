WITH geography_data AS (
    SELECT DISTINCT
        country_code,
        country_name,
        region_name,
        city_name
    FROM {{ source('raw', 'ip_locations') }}
    WHERE lookup_status = 'ok'
),

location_dimension AS (
    SELECT
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
    FROM geography_data
),

unknown_member AS (
    SELECT
        CAST(-1 AS INT64) AS location_key,
        CAST(NULL AS STRING) AS country_code,
        CAST(NULL AS STRING) AS country_name,
        CAST(NULL AS STRING) AS region_name,
        CAST(NULL AS STRING) AS city_name
),

combined AS (
    SELECT * FROM unknown_member
    UNION ALL
    SELECT * FROM location_dimension
)

SELECT
    *,
    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by
FROM combined