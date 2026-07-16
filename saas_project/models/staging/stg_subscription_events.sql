WITH source AS (
    SELECT * 
    FROM {{source('raw_saas' , 'raw_subscription_events')}} 
),

renamed AS (
    SELECT
        event_id,
        customer_id,
        LOWER(event_type) AS event_type,
        LOWER(plan_name) AS plan_name,
        CAST(amount AS float64) AS mrr_amount,
        CAST(event_timestamp AS timestamp) AS event_timestamp
    FROM source
)

SELECT * FROM renamed