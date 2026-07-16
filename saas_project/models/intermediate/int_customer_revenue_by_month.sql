WITH customer_months AS (
    SELECT * 
    FROM {{ref('int_customer_months')}}
),

subscription_events AS (
    SELECT *
    FROM {{ref('stg_subscription_events')}}
),

monthly_deduped_events AS (
    SELECT
        customer_id,
        DATE_TRUNC(CAST(event_timestamp AS DATE), MONTH) AS date_month,
        event_type,
        plan_name,
        mrr_amount,
        event_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id, DATE_TRUNC(CAST(event_timestamp AS DATE), MONTH)
            ORDER BY event_timestamp DESC, event_id DESC
        ) AS rn
    FROM subscription_events
),

last_event_per_month AS (
    SELECT *
    FROM monthly_deduped_events
    WHERE rn = 1
),

joined_events AS (
    SELECT
        cm.customer_id,
        cm.date_month,
        le.event_type,
        le.plan_name,
        le.mrr_amount,
        le.event_timestamp
    FROM customer_months AS cm
    LEFT JOIN last_event_per_month AS le
        ON cm.customer_id = le.customer_id
        AND cm.date_month = DATE_TRUNC(CAST(le.event_timestamp AS DATE), MONTH)
),

carried_forward AS (
    SELECT
        customer_id,
        date_month,
        LAST_VALUE(plan_name IGNORE NULLS) OVER (
            PARTITION BY customer_id
            ORDER BY date_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS current_plan,
        LAST_VALUE(mrr_amount IGNORE NULLS) OVER (
            PARTITION BY customer_id
            ORDER BY date_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS current_mrr
    FROM joined_events
)

SELECT
    customer_id,
    date_month,
    COALESCE(current_plan, 'none') AS current_plan,
    CASE
        WHEN COALESCE(current_plan, 'none') IN ('none', 'churn') THEN 0.00
        ELSE COALESCE(current_mrr, 0.00)
    END AS mrr_amount
FROM carried_forward