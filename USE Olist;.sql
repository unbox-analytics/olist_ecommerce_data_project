USE Olist;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';
-- Olist E-commerce Data Analysis
-- Customer Insights
-- Which states or cities have the most active buyers?
    -- active buyer is defined as someone who buys more than 2 times
    USE Olist
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
            ROUND(count(rc.customer_unique_id)TOP 5 *100.0/COUNT(ac.customer_unique_id),1) as repeat_customer_rate
    FROM all_customers ac
    LEFT JOIN repeat_customers rc
    ON rc.customer_unique_id = ac.customer_unique_id
    GROUP BY ac.customer_city
    HAVING COUNT(ac.customer_unique_id) > 500
    ORDER BY repeat_customer_rate DESC
-- What is the average order value per customer?
    -- to get we need to value of orders div number of customers. since price is in order items we need to join
    -- to get value of orders
    USE Olist
    
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
-- What is the average order value per customer by state?

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
     ORDER BY ROUND(AVG(avg_order_value),2) DESC
-- What is the repeat customer rate?
    --number of repeat customers divide by total customers TOP 5 *100
    SELECT 
            COUNT(TOP 5 *) as repeat_customers,
            (SELECT count(customer_unique_id) FROM orders
            JOIN customers c
            ON orders.customer_id = c.customer_id) as total_customers,
            ROUND(COUNT(TOP 5 *)TOP 5 *100.0/(SELECT count(customer_unique_id) FROM orders
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
-- What is the customer churn rate over time?
        --Assumption: customer churn is defined as a customer who has not made a purchase in the last 6 months.
    -- = Number of customers who stopped buying TOP 5 *100/ Total number of customers at beginning of the period
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
                        TOP 5 * 
                    FROM eligible_customers
                    WHERE last_purchase_date < '2017-07-01'
        )
        SELECT 
            COUNT(TOP 5 *) AS Churned_Customers, (SELECT COUNT(DISTINCT customer_unique_id) FROM eligible_customers) AS Eligible_Customers,
            ROUND(COUNT(TOP 5 *) TOP 5 * 100.0 / (SELECT COUNT(DISTINCT customer_unique_id) FROM eligible_customers), 2) AS Churn_Rate
        FROM Churned_Customers
-- Which cities have the longest average delivery times?
        SELECT top 10 
                c.customer_city, 
                AVG(DATEDIFF(DAY,  o.order_delivered_carrier_date, o.order_delivered_customer_date)) as delivery_time,
                COUNT(TOP 5 *) as order_count
        FROM orders o
        JOIN customers c
        on o.customer_id = c.customer_id
        WHERE o.order_status = 'delivered'
            AND o.order_delivered_carrier_date IS NOT NULL
            AND o.order_delivered_customer_date IS NOT NULL
          
        GROUP BY customer_city
        HAVING COUNT(TOP 5 *) > 10
        ORDER BY delivery_time DESC
        
-- SALES AND REVENUE ANALYSIS

SELECT TOP 5 * FROM orders
SELECT TOP 5 * FROM customers
SELECT TOP 5 * FROM order_items
SELECT TOP 5 * FROM products
SELECT TOP 5 * FROM category_name
SELECT TOP 5 * FROM payments
SELECT TOP 5 * FROM geolocation
SELECT TOP 5 * FROM payments
SELECT TOP 5 * FROM order_reviews
SELECT TOP 5 * FROM sellers


-- Which product categories generate the most revenue?
    USE Olist 

    SELECT  
        cn.product_category_name_english AS product_category_name, 
        ROUND(SUM(total_revenue),2) AS total_revenue,
        ROUND(SUM(total_revenue)*100.0/ (SELECT SUM(price) FROM order_items),2) AS revenue_percentage,
        SUM(order_count) AS number_of_orders
        FROM (
            SELECT -- list of product categories with total revenue
                COALESCE(p.product_category_name, 'Misc') AS product_category_name, 
                ROUND(SUM(oi.price),2) AS total_revenue,
                ROUND(SUM(oi.price)*100.0/ (select sum(price) from order_items),2) AS revenue_percentage,
                COUNT(DISTINCT oi.order_id) AS order_count
            FROM order_items oi
            JOIN products p
            ON oi.product_id = p.product_id
            GROUP BY p.product_category_name
        ) AS cr
        JOIN category_name cn
        ON cr.product_category_name = cn.product_category_name
    GROUP BY cn.product_category_name_english
    ORDER BY total_revenue DESC;

-- What is the monthly/yearly revenue trend?
USE Olist
WITH monthly_revenue AS (
    SELECT 
        DATEPART(YEAR, o.order_purchase_timestamp) AS order_year,
        DATEPART(MONTH, o.order_purchase_timestamp) AS order_month,
        FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS month_label,
        SUM(oi.price) AS total_revenue
    FROM orders o   
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY 
        DATEPART(YEAR, o.order_purchase_timestamp), 
        DATEPART(MONTH, o.order_purchase_timestamp),
        FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
)
SELECT 
    order_year, 
    order_month,
    month_label,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(SUM(total_revenue) OVER (
        PARTITION BY order_year 
        ORDER BY order_month
    ), 2) AS running_total_revenue
FROM monthly_revenue
ORDER BY order_year, order_month;


What is the average revenue per seller?



What’s the cancellation rate, and how does it affect total revenue?

Which states generate the most revenue, and how does that correlate with customer volume?






🔹 Logistics & Delivery Performance
What is the average time between purchase and delivery (actual vs. estimated)?

Which sellers or regions have the slowest deliveries?

Does delivery delay affect customer review ratings?

How do public holidays or weekends affect delivery delays?

How long does it take for sellers to ship products after order approval?

🔹 Product and Category Insights
Which product categories have the highest return or cancellation rates?

Which product categories have the most 5-star vs 1-star reviews?

What is the average review score per product category?

Which categories are most frequently sold together? (market basket analysis)

Which products are most frequently sold during holiday seasons?

🔹 Customer Reviews and Satisfaction
What’s the average rating per seller?

Which sellers consistently receive poor reviews?

What is the distribution of review scores across order delivery delays?

Is there a relationship between product price and review score?

🔹 Seller Performance
Which sellers have the highest revenue and volume?

Which sellers have the highest average customer ratings?

How many sellers are retained or drop off after 6 months?

What’s the average shipping time per seller?

Do sellers in specific regions perform better in terms of revenue or speed?

🔹 Payment Behavior
Which payment types are most commonly used?

How does payment type correlate with order value?

What is the average number of installments per product category?

Are installment payments more common in higher-value purchases?

🔧 Extra Advanced Ideas (for dashboards or modeling)
Build a cohort analysis to track customer behavior over time.

RFM (Recency, Frequency, Monetary) segmentation to identify VIP customers.

Forecast monthly revenue using time series modeling.

Create a customer satisfaction index by combining reviews, delivery time, and repeat orders.

