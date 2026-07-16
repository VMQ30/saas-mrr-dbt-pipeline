WITH current_and_previous_mrr AS (
    SELECT 
        customer_id,
        date_month,
        current_plan, 
        mrr_amount AS current_mrr,
        COALESCE(
            LAG(mrr_amount) OVER (
                PARTITION BY customer_id ORDER BY date_month
            ), 0.00
        ) AS previous_mrr
    FROM {{ref('int_customer_revenue_by_month')}}
),

classified_mrr AS (
    SELECT 
        customer_id,
        date_month,
        current_plan,
        current_mrr,
        previous_mrr,
        (current_mrr - previous_mrr) as mrr_change,
        CASE
            WHEN previous_mrr = 0.00 AND current_mrr > 0.00 THEN 'new'
            WHEN current_mrr = 0.00 AND previous_mrr > 0.00 THEN 'churn'
            WHEN current_mrr > previous_mrr then 'upgrade'
            WHEN current_mrr < previous_mrr then 'downgrade'
            ELSE 'active' 
        END AS mrr_change_category
    FROM current_and_previous_mrr
)

SELECT * FROM classified_mrr
WHERE current_mrr > 0.00 OR previous_mrr > 0.00
ORDER BY customer_id, date_month