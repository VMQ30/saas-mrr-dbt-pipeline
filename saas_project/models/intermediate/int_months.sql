WITH date_range AS (
    SELECT
        generated_date
    FROM
        unnest(generate_date_array('2024-01-01' , current_date(), interval 1 month)) AS generated_date
)

SELECT
    CAST(generated_date AS date) AS date_month
FROM date_range