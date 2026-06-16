<p>
<a href="https://github.com/unbox-analytics/olist_ecommerce_data_project/tree/main">Home</a> • <a href="https://github.com/unbox-analytics/olist_ecommerce_data_project/blob/main/documentation/CustomerInsights.md">Customer Insights</a> • <a href="https://github.com/unbox-analytics/olist_ecommerce_data_project/blob/main/documentation/Sales_and_Revenue_Analysis.md">Sales and Revenue Analysis</a> • <a href="https://unbox-analytics.github.io/">Back to website</a> 
</p>

## Customer Insights

### Which states has the most active buyers and what is the repeat customer rate?
Assumptions: 
- Active buyers are those that have made at least one purchase
- For statistical significance, only cities with over 500 customers have been considered
Using CTE count the numbers of such active buyers and then compare against total buyers by state. 
```sql
USE olist
WITH repeat_customers AS (
-- CTE to count by state, all the customers who made more than 1 order
    SELECT 
        c.customer_unique_id as customer_unique_id,
        g.geolocation_city as customer_city,    
        count(o.order_id) as order_count
    FROM orders o
    JOIN customers c
    ON o.customer_id = c.customer_id
    JOIN geolocation g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
    group by c.customer_unique_id, g.geolocation_city
    HAVING COUNT(o.order_id) > 1
),
all_customers AS (
-- CTE to obtain the number of unique customers by state
    SELECT 
       DISTINCT customer_unique_id as customer_unique_id,
       g.geolocation_city as customer_city    
    FROM customers
    JOIN geolocation g
    ON customers.customer_zip_code_prefix = g.geolocation_zip_code_prefix
    )
SELECT 
        ac.customer_city, 
        COUNT(ac.customer_unique_id) as total_customers,
        count(rc.customer_unique_id) as repeat_customers,
        ROUND(count(rc.customer_unique_id)*100.0/COUNT(ac.customer_unique_id),1) as repeat_customer_rate
FROM all_customers ac
LEFT JOIN repeat_customers rc
ON rc.customer_unique_id = ac.customer_unique_id
GROUP BY ac.customer_city
HAVING COUNT(ac.customer_unique_id) > 500
ORDER BY repeat_customer_rate DESC
```


![My Image](https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/Q1.jpg)

What is the average order value per customer?

```sql
-- Averages the average order value of each customer to obtain the global average value per customer 
    SELECT AVG(avg_order_value) AS av_ord_val_per_customer 
    FROM (
    --Tabulates the list of customers with the average order value of each customer
        SELECT 
                c.customer_unique_id,
                sum(oi.price) as order_value,
                count(o.order_id) as order_count,
                sum(oi.price) / count(o.order_id) as avg_order_value
        FROM customers c
        JOIN orders o
        ON c.customer_id = o.customer_id
        JOIN order_items oi
        ON o.order_id = oi.order_id
        group by c.customer_unique_id
    ) AS ord_value
```
![MY Image](https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/Q2.jpg)


What is the order value per customer by state?
```sql
SELECT  
        ord_value.customer_state,
        ROUND(AVG(avg_order_value),2) as avg_order_value_by_state
    FROM(
        -- table for customer wise average order value
        SELECT 
            c.customer_unique_id,
            c.customer_state,
            sum(oi.price)/ count(o.order_id) as avg_order_value
        FROM orders o
        JOIN order_items oi
        ON o.order_id = oi.order_id
        JOIN customers c
        ON o.customer_id = c.customer_id
        GROUP BY c.customer_state, c.customer_unique_id
        ) AS ord_value
     GROUP BY ord_value.customer_state
     ORDER BY ord_value.customer_state
```

![My Image](https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/Q3.jpg)

What is the repeat customer rate?
```sql
    SELECT 
            COUNT(*) as repeat_customers,
            (SELECT count(customer_unique_id) FROM orders
            JOIN customers c
            ON orders.customer_id = c.customer_id) as total_customers,
            ROUND(COUNT(*)*100.0/(SELECT count(customer_unique_id) FROM orders
            JOIN customers c
            ON orders.customer_id = c.customer_id),2) as repeat_customer_rate
    FROM (        
            
            SELECT  -- table for customers with more than 1 order 
                c.customer_unique_id,
                COUNT(o.order_id) as order_count
            FROM customers c
            JOIN orders o
            ON c.customer_id = o.customer_id
            GROUP BY c.customer_unique_id
            HAVING COUNT(o.order_id) > 1
    ) AS repeat_customers
```
![My Image](https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/Q4.jpg)


What is the customer churn rate over time?
Assumption:
Defining a churned customer as one who has not made a repeat purchase as on '2017-07-01'

```sql
WITH order_timelines AS( -- listing first order and last order dates
            SELECT 
                c.customer_unique_id as customer_unique_id,  
                MIN(CAST(o.order_purchase_timestamp as date)) as First_purchase_date,
                MAX(CAST(o.order_purchase_timestamp as date)) as last_purchase_date
            FROM orders o
            JOIN customers c            
            ON o.customer_id = c.customer_id
            GROUP BY c.customer_unique_id           
), 
eligible_customers AS( --  removing customers with no purchases before 2017-01-01
    SELECT 
        customer_unique_id,
        last_purchase_date
    FROM order_timelines
    WHERE First_purchase_date < '2017-07-01'
),
Churned_Customers AS ( -- customers that did not purchase again from the above subset
            SELECT 
                * 
            FROM eligible_customers
            WHERE last_purchase_date < '2017-07-01'
)
SELECT 
    COUNT(*) AS Churned_Customers, (SELECT COUNT(DISTINCT customer_unique_id) FROM eligible_customers) AS Eligible_Customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT customer_unique_id) FROM eligible_customers), 2) AS Churn_Rate
FROM Churned_Customers
```
![My Image](https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/Q5.jpg)

Which cities have the longest average delivery times?
```sql
SELECT top 10 
                c.customer_city, 
                AVG(DATEDIFF(DAY,  o.order_delivered_carrier_date, o.order_delivered_customer_date)) as delivery_time,
                COUNT(*) as order_count
        FROM orders o
        JOIN customers c
        on o.customer_id = c.customer_id
        WHERE o.order_status = 'delivered'
            AND o.order_delivered_carrier_date IS NOT NULL
            AND o.order_delivered_customer_date IS NOT NULL
          
        GROUP BY customer_city
        HAVING COUNT(*) > 10
        ORDER BY delivery_time DESC
```

![My Image](https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/Q6.jpg)

[View pdf] (https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/This%20is%20a%20mad%20mad%20world.pdf)
