<p>
<a href="https://github.com/malachi-mendes/Ecommerce_Data_Analytics/tree/main">Overview</a> • <a href="https://github.com/unbox-analytics/olist_ecommerce_data_project/blob/main/documentation/CustomerInsights.md">Customer Insights</a> • <a href="https://github.com/unbox-analytics/olist_ecommerce_data_project/blob/main/documentation/Sales_and_Revenue_Analysis.md">Sales and Revenue Analysis</a> • <a href="https://unbox-analytics.github.io/">Back to website</a> 
</p>

## Sales and Revenue Analysis


🔹 Sales and Revenue Analysis
Which product categories generate the most revenue?
```sql
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
```

Top revenue product categories
![My Image](https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/Q7a.jpg)

Lowest revenue categories
![My Image](https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/Q7b.jpg)


What is the monthly/yearly revenue trend?
```sql
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
```
![My Image](https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/assets/Q8.jpg)

What is the average revenue per seller?

What’s the cancellation rate, and how does it affect total revenue?

Which states generate the most revenue, and how does that correlate with customer volume?
