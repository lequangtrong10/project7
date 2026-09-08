{{ config(materialized='table') }}

SELECT
    FARM_FINGERPRINT(
        CONCAT(
            er.currency_code,
            '|',
            er.rate_date
        )
    ) AS exchange_rate_key,

    d.date_key,

    c.currency_key,

    er.currency_code,
    er.rate_date,
    er.rate_to_usd,

    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by

FROM {{ ref('exchange_rate_seed') }} er

LEFT JOIN {{ ref('dim_date') }} d
    ON SAFE.PARSE_DATE('%m/%d/%Y', er.rate_date) = d.full_date

LEFT JOIN {{ ref('dim_currency') }} c
    ON er.currency_code = c.currency_code