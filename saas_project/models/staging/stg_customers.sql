WITH source AS (
    SELECT *
    FROM {{source('raw_saas' , 'raw_customers')}}
),

cleaned AS (
    SELECT
        NULLIF(TRIM(CAST(customer_id AS STRING)) , '') AS customer_id,
        NULLIF(TRIM(customer_name) , '') AS customer_name,
        NULLIF(TRIM(country) , '') AS country_code,
        CASE
            WHEN TRIM(created_at) IN ('NULL' , '' , 'None') THEN NULL
            WHEN REGEXP_CONTAINS(TRIM(created_at), r'^\d+$') 
                THEN TIMESTAMP_SECONDS(CAST(TRIM(created_at) AS INT64))
            ELSE COALESCE(
                SAFE_CAST(TRIM(created_at) AS TIMESTAMP),
                SAFE.PARSE_TIMESTAMP('%Y/%m/%d', TRIM(created_at))
            )
        END AS created_at_timestamp
    FROM source
)

SELECT * FROM cleaned
WHERE customer_id IS NOT NULL
    AND created_at_timestamp IS NOT NULL
QUALIFY row_number() OVER (
    PARTITION BY customer_id
    ORDER BY created_at_timestamp DESC
) = 1