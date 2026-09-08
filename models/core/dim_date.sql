WITH date_spine AS (

    SELECT
        date_day

    FROM UNNEST(
        GENERATE_DATE_ARRAY(
            DATE('2020-01-01'),
            DATE('2020-12-31'),
            INTERVAL 1 DAY
        )
    ) AS date_day

)

SELECT
    CAST(FORMAT_DATE('%Y%m%d', date_day) AS INT64) AS date_key,

    date_day AS full_date,

    EXTRACT(DAYOFWEEK FROM date_day) AS day_of_week,

    FORMAT_DATE('%A', date_day) AS day_name,

    EXTRACT(DAY FROM date_day) AS day_of_month,

    EXTRACT(DAYOFYEAR FROM date_day) AS day_of_year,

    EXTRACT(WEEK FROM date_day) AS week_of_year,

    EXTRACT(MONTH FROM date_day) AS month_number,

    FORMAT_DATE('%B', date_day) AS month_name,

    EXTRACT(QUARTER FROM date_day) AS quarter_number,

    EXTRACT(YEAR FROM date_day) AS year_number,

    CASE
        WHEN EXTRACT(DAYOFWEEK FROM date_day) IN (1, 7)
            THEN TRUE
        ELSE FALSE
    END AS is_weekend,

    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by

FROM date_spine