{{ config(materialized='table') }}

WITH source_data AS (
    SELECT
        ip,
        country_code,
        region_name,
        city_name,
        lookup_status,
        processed_at_utc
    FROM {{ source('raw', 'ip_locations') }}
    WHERE ip IS NOT NULL AND TRIM(ip) != ''
),

deduplicated AS (
    SELECT
        ip,
        country_code,
        region_name,
        city_name,
        lookup_status,
        ROW_NUMBER() OVER (
            PARTITION BY ip
            ORDER BY
                CASE
                    WHEN lookup_status = 'ok' THEN 1
                    ELSE 2
                END,
                processed_at_utc DESC
        ) AS rn
    FROM source_data
),

mapped AS (
    SELECT
        d.ip,
        COALESCE(loc.location_key, -1) AS location_key
    FROM deduplicated d
    LEFT JOIN {{ ref('dim_location') }} loc
        ON d.lookup_status = 'ok'
        AND COALESCE(d.country_code, '') = COALESCE(loc.country_code, '')
        AND COALESCE(d.region_name, '') = COALESCE(loc.region_name, '')
        AND COALESCE(d.city_name, '') = COALESCE(loc.city_name, '')
    WHERE d.rn = 1
)

SELECT
    ip,
    location_key,
    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by
FROM mapped