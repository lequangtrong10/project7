WITH customer_events AS (
    SELECT DISTINCT user_id_db AS customer_id, email_address, order_timestamp
    FROM {{ ref('stg_glamira_raw') }}
    WHERE user_id_db IS NOT NULL AND TRIM(user_id_db) != ''
),
ordered_events AS (
    SELECT customer_id, email_address, order_timestamp,
        LAG(email_address) OVER (PARTITION BY customer_id ORDER BY order_timestamp) AS previous_email,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_timestamp) AS customer_event_number
    FROM customer_events
),
version_flagged AS (
    SELECT customer_id, email_address, order_timestamp,
        CASE WHEN customer_event_number = 1 THEN 1
             WHEN email_address IS DISTINCT FROM previous_email THEN 1
             ELSE 0 END AS is_new_version
    FROM ordered_events
),
version_numbered AS (
    SELECT customer_id, email_address, order_timestamp,
        SUM(is_new_version) OVER (PARTITION BY customer_id ORDER BY order_timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS version_number
    FROM version_flagged
),
version_bounds AS (
    SELECT customer_id, email_address, version_number, MIN(order_timestamp) AS start_date
    FROM version_numbered
    GROUP BY customer_id, email_address, version_number
),
version_windowed AS (
    SELECT customer_id, email_address, start_date,
        LEAD(start_date) OVER (PARTITION BY customer_id ORDER BY start_date) AS end_date
    FROM version_bounds
),
customer_dimension AS (
    SELECT
        FARM_FINGERPRINT(CONCAT(CAST(customer_id AS STRING), '|', CAST(start_date AS STRING))) AS customer_key,
        CAST(customer_id AS STRING) AS customer_id,
        email_address, start_date, end_date,
        end_date IS NULL AS is_current
    FROM version_windowed
    UNION ALL
    SELECT
        CAST(-1 AS INT64) AS customer_key,
        'UNKNOWN' AS customer_id,
        'UNKNOWN' AS email_address,
        TIMESTAMP('1900-01-01 00:00:00 UTC') AS start_date,
        NULL AS end_date,
        TRUE AS is_current
)
SELECT
    *,
    CURRENT_TIMESTAMP() AS inserted_date,
    'dbt' AS inserted_by,
    CURRENT_TIMESTAMP() AS updated_date,
    'dbt' AS updated_by
FROM customer_dimension