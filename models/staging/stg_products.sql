SELECT
    candidate_product_id AS product_id,

    name AS product_name,
    sku,

    category_name,
    category,

    product_type_value,
    product_type,
    type_id,

    collection_id,
    collection,

    gender,

    price,
    min_price,
    max_price,

    attribute_set,
    attribute_set_id,

    store_code

FROM {{ source('raw', 'products') }}

WHERE candidate_product_id IS NOT NULL