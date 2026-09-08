WITH deduplicated AS (
    SELECT DISTINCT currency_code
    FROM {{ ref('stg_glamira_raw') }}
    WHERE currency_code IS NOT NULL AND TRIM(currency_code) != ''
),
currency_dimension AS (
    SELECT
        FARM_FINGERPRINT(currency_code) AS currency_key,
        currency_code,
        CASE currency_code
            WHEN 'EUR' THEN 'Euro' WHEN 'GBP' THEN 'British Pound' WHEN 'USD' THEN 'US Dollar'
            WHEN 'SEK' THEN 'Swedish Krona' WHEN 'DKK' THEN 'Danish Krone' WHEN 'NOK' THEN 'Norwegian Krone'
            WHEN 'AUD' THEN 'Australian Dollar' WHEN 'CAD' THEN 'Canadian Dollar' WHEN 'CHF' THEN 'Swiss Franc'
            WHEN 'CZK' THEN 'Czech Koruna' WHEN 'HUF' THEN 'Hungarian Forint' WHEN 'PLN' THEN 'Polish Zloty'
            WHEN 'MXN' THEN 'Mexican Peso' WHEN 'SGD' THEN 'Singapore Dollar' WHEN 'NZD' THEN 'New Zealand Dollar'
            WHEN 'BRL' THEN 'Brazilian Real' WHEN 'VND' THEN 'Vietnamese Dong' WHEN 'BGN' THEN 'Bulgarian Lev'
            WHEN 'RON' THEN 'Romanian Leu' WHEN 'AED' THEN 'UAE Dirham' WHEN 'ZAR' THEN 'South African Rand'
            WHEN 'HRK' THEN 'Croatian Kuna' WHEN 'CLP' THEN 'Chilean Peso' WHEN 'COP' THEN 'Colombian Peso'
            WHEN 'CRC' THEN 'Costa Rican Colon' WHEN 'DOP' THEN 'Dominican Peso' WHEN 'GTQ' THEN 'Guatemalan Quetzal'
            WHEN 'HKD' THEN 'Hong Kong Dollar' WHEN 'KWD' THEN 'Kuwaiti Dinar' WHEN 'MDL' THEN 'Moldovan Leu'
            WHEN 'PEN' THEN 'Peruvian Sol' WHEN 'UYU' THEN 'Uruguayan Peso' WHEN 'BOB' THEN 'Bolivian Boliviano'
            WHEN 'ARS' THEN 'Argentine Peso' WHEN 'CNY' THEN 'Chinese Yuan' WHEN 'INR' THEN 'Indian Rupee'
            WHEN 'JPY' THEN 'Japanese Yen' WHEN 'PHP' THEN 'Philippine Peso' WHEN 'PYG' THEN 'Paraguayan Guarani'
            WHEN 'RSD' THEN 'Serbian Dinar' WHEN 'TRY' THEN 'Turkish Lira'
            ELSE NULL
        END AS currency_name
    FROM deduplicated
)
SELECT
    *,
    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by
FROM currency_dimension