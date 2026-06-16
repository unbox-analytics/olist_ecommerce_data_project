<p>
<a href="[https://github.com/malachi-mendes/Ecommerce_Data_Analytics/tree/main](https://github.com/unbox-analytics/olist_ecommerce_data_project/tree/main)">Overview</a> • <a href="https://github.com/unbox-analytics/olist_ecommerce_data_project/blob/main/documentation/CustomerInsights.md">Customer Insights</a> • <a href="https://github.com/unbox-analytics/olist_ecommerce_data_project/blob/main/documentation/Sales_and_Revenue_Analysis.md">Sales and Revenue Analysis</a> • <a href="https://unbox-analytics.github.io/">Back to website</a> 
</p>

# Retail E-commerce Project  



## Project Overview
The Olist database is a set of ecommerce data spanning multiple tables. Olist, a Brazilian e-commerce platform has published a dataset containing 99441 orders from March 2016 to August 2018. 

The project simulates a real-world data pipeline involving:

- Data ingestion
- Automated data cleaning
- Error logging
- Data warehouse design
- Business analysis
- KPI reporting

## Importing and understading the data (Data Source: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
To get a better understanding of the data the files were imported into a new SQL database using Microsoft SQL Server Management Studio. Each csv is imported using the import wizard. 

## Tables
customers.csv
geolocation.csv
order_items.csv
order_payments.csv
order_reviews.csv
orders.csv
products.csv
sellers.csv
product_category_name_translation.cs


## Tools and Technologies
<p align="left">
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/python/python-original.svg" width="40" />
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/mysql/mysql-original.svg" width="40" />
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/pandas/pandas-original.svg" width="40" />
  <img src="https://img.icons8.com/color/48/power-bi.png" width="40" />
  <img src="https://img.icons8.com/color/48/microsoft-excel-2019--v1.png" width="40" />
  <img src="https://img.icons8.com/color/48/sql.png" width="40" />
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/figma/figma-original.svg" width="40" height="40"/>
<img src="https://img.icons8.com/color/48/chatgpt.png" width="40" height="40" alt="ChatGPT"/>
</p>

![DAX](https://img.shields.io/badge/DAX-DataModeling-yellow?logo=powerbi&logoColor=black)
![Power Query](https://img.shields.io/badge/Power%20Query-ETL-green?logo=microsoft&logoColor=white)


# Executive Summary
## Customer Insights
Somethinh something something

<a href="https://github.com/malachi-mendes/Ecommerce_Data_Analytics/blob/main/CustomerInsights.md">Deep dive into customer Insights</a>




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


Which cities have the longest average delivery times?


Sales trend analysis

Customer segmentation

Recommendation systems

Pricing optimization

