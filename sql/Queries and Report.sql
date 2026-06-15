Customer Insights
Which states or cities have the most active buyers?

WITH repeat_customers AS (
-- CTE to count by state, all the customers who made more than 1 order
    SELECT 
        c.customer_unique_id as customer_unique_id,
        c.customer_state,    
        count(o.order_id) as order_count
    FROM orders o
    JOIN customers c
    ON o.customer_id = c.customer_id
    group by c.customer_unique_id, c.customer_state
    HAVING COUNT(o.order_id) > 1
),
all_customers AS (
-- CTE to obtain the number of unique customers by state
    SELECT 
       DISTINCT customer_unique_id as customer_unique_id,
       customer_state
    FROM customers
    )
SELECT 
        ac.customer_state, 
        COUNT(ac.customer_unique_id) as total_customers,
        count(rc.customer_unique_id) as repeat_customers,
        ROUND(count(rc.customer_unique_id)*100.0/COUNT(ac.customer_unique_id),1) as repeat_customer_rate
FROM all_customers ac
LEFT JOIN repeat_customers rc
ON rc.customer_unique_id = ac.customer_unique_id
GROUP BY ac.customer_state
ORDER BY repeat_customer_rate DESC
