WITH customer_months AS (
    SELECT * 
    FROM {{ref('int_customer_months')}}
),

subscription_events AS (
    SELECT *
    FROM {{ref('stg_subscription_events')}}
),

monthly_deduped_events as (
    select
        customer_id,
        date_trunc(cast(event_timestamp as date), month) as date_month,
        event_type,
        plan_name,
        mrr_amount,
        event_timestamp,
        row_number() over (
            partition by customer_id, date_trunc(cast(event_timestamp as date), month)
            order by event_timestamp desc, event_id desc
        ) as rn
    from subscription_events
),

last_event_per_month as (
    select *
    from monthly_deduped_events
    where rn = 1
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
        AND cm.date_month = date_trunc(CAST(le.event_timestamp AS date) , month)
),

carried_forward AS (
    SELECT
        customer_id,
        date_month,
        last_value(plan_name ignore nulls) OVER (
            PARTITION BY customer_id
            ORDER BY date_month
            ROWS BETWEEN unbounded preceding AND current row
        ) AS current_plan,
        last_value(mrr_amount ignore nulls) OVER (
            PARTITION BY customer_id
            ORDER BY date_month
            ROWS BETWEEN unbounded preceding AND current row
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