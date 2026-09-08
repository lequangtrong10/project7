SELECT
    fact_pk,
    order_qty,
    unit_price,
    sales_amount
FROM {{ ref('fact_sales_order_detail') }}
WHERE unit_price IS NOT NULL
    AND sales_amount IS NOT NULL
    AND ROUND(sales_amount, 2) != ROUND(order_qty * unit_price, 2)