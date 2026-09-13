WITH stg_dim_location_source AS (
    SELECT
        *
    FROM {{ source('raw', 'ip_locations') }}
    WHERE ip IS NOT NULL
      AND TRIM(ip) != ''

),

stg_dim_location_cleaned AS (
    SELECT
        ip AS ip_address,
        CASE
            WHEN UPPER(country_code) LIKE '%MISSING%'
              OR UPPER(country_code) LIKE '%INVALID%'
              OR UPPER(country_code) LIKE '%ERROR%'
            THEN NULL
            ELSE country_code
        END AS country_code,
        CASE
            WHEN UPPER(country_name) LIKE '%MISSING%'
              OR UPPER(country_name) LIKE '%INVALID%'
              OR UPPER(country_name) LIKE '%ERROR%'
            THEN NULL
            ELSE country_name
        END AS country_name,
        CASE
            WHEN UPPER(region_name) LIKE '%MISSING%'
              OR UPPER(region_name) LIKE '%INVALID%'
              OR UPPER(region_name) LIKE '%ERROR%'
            THEN NULL
            ELSE region_name
        END AS region_name,
        CASE
            WHEN UPPER(city_name) LIKE '%MISSING%'
              OR UPPER(city_name) LIKE '%INVALID%'
              OR UPPER(city_name) LIKE '%ERROR%'
            THEN NULL
            ELSE city_name
        END AS city_name
    FROM stg_dim_location_source

),

stg_dim_location_gen_key AS (

    SELECT
        ip_address,
        country_code,
        country_name,
        region_name,
        city_name,
        FARM_FINGERPRINT(
            CONCAT(
                COALESCE(country_code, ''), '|',
                COALESCE(region_name, ''), '|',
                COALESCE(city_name, '')
            )
        ) AS location_key
    FROM stg_dim_location_cleaned

)

SELECT
    *
FROM stg_dim_location_gen_key