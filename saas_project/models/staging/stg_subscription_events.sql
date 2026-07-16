WITH source AS (
    SELECT * FROM {{source('raw_saas' , 'raw_subscription_events')}} 
),

cleaned AS (
    SELECT
        NULLIF(TRIM(CAST(event_id AS string)) , '') AS event_id,
        NULLIF(TRIM(CAST(customer_id AS string)) , '') AS customer_id,
        COALESCE(NULLIF(TRIM(LOWER(event_type)), ''), 'unknown') AS raw_event_type,
        COALESCE(NULLIF(TRIM(LOWER(plan_name)), ''), 'unknown') AS raw_plan_name,
        CAST(amount AS float64) AS mrr_amount,
        
        CASE
            WHEN TRIM(event_timestamp) IN ('NULL', '', 'None') THEN NULL
            WHEN REGEXP_CONTAINS(TRIM(event_timestamp), r'^\d+$') 
                THEN TIMESTAMP_SECONDS(CAST(TRIM(event_timestamp) AS INT64))
            ELSE COALESCE(
                SAFE_CAST(TRIM(event_timestamp) AS TIMESTAMP),
                SAFE.PARSE_TIMESTAMP('%Y/%m/%d', TRIM(event_timestamp))
            )
        END AS event_timestamp
    FROM source
),

fallback AS (
    SELECT
        event_id,
        customer_id,
        event_timestamp,
        CASE 
            WHEN raw_plan_name = 'unknown' AND mrr_amount = 9.99 THEN 'basic'
            WHEN raw_plan_name = 'unknown' AND mrr_amount = 24.99 THEN 'pro'
            WHEN raw_plan_name = 'unknown' AND mrr_amount = 100.00 THEN 'enterprise'
            WHEN raw_plan_name = 'unknown' AND mrr_amount = 0.00 THEN 'none'
            WHEN raw_plan_name = 'unknown' THEN 'basic' 
            ELSE raw_plan_name
        END AS plan_name,
        CASE 
            WHEN mrr_amount IS NULL AND raw_plan_name = 'basic' THEN 9.99
            WHEN mrr_amount IS NULL AND raw_plan_name = 'pro' THEN 24.99
            WHEN mrr_amount IS NULL AND raw_plan_name = 'enterprise' THEN 100.00
            WHEN mrr_amount IS NULL AND raw_plan_name = 'none' THEN 0.00
            WHEN mrr_amount IS NULL THEN 9.99
            ELSE mrr_amount
        END AS mrr_amount,
        CASE 
            WHEN raw_event_type = 'unknown' AND (raw_plan_name = 'none' OR mrr_amount = 0.00) THEN 'churn'
            WHEN raw_event_type = 'unknown' THEN 'plan_change'
            ELSE raw_event_type
        END AS event_type
    FROM cleaned
    WHERE event_timestamp IS NOT NULL
      AND customer_id IS NOT NULL
)

SELECT * FROM fallback
QUALIFY row_number() OVER(
    PARTITION BY event_id
    ORDER BY event_timestamp DESC
) = 1