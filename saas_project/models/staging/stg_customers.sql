WITH source AS (
    SELECT *
    FROM {{source('raw_saas' , 'raw_customers')}}
),

renamed AS (
    SELECT
        customer_id,
        customer_name,
        country AS country_code,
        CAST(created_at AS timestamp) AS created_at_timestamp
    FROM source
)

SELECT * FROM renamed