WITH customers AS (
    SELECT * 
    FROM {{ref('stg_customers')}}
),

months AS (
    SELECT * 
    FROM {{ref('int_months')}}
),

customer_months AS (
    SELECT 
        c.customer_id,
        m.date_month,
        DATE_TRUNC(CAST(c.created_at_timestamp AS date) , month) AS signup_month
    FROM customers AS c
    CROSS JOIN months AS m
),

filtered_months AS (
    SELECT
        customer_id,
        date_month
    FROM customer_months
    WHERE date_month >= signup_month
)

SELECT * 
FROM filtered_months
ORDER BY customer_id , date_month