-- FreshKart retail analysis: Part B, 10 business questions (PostgreSQL). Run after 02_cleaning.sql.

-- Q1
SELECT order_year,
       ROUND(SUM(sales_amount))                              AS net_sales,
       COUNT(DISTINCT order_id)                              AS delivered_orders,
       ROUND(SUM(sales_amount) / COUNT(DISTINCT order_id))   AS aov
FROM sales_view
WHERE order_status = 'Delivered'
GROUP BY order_year
ORDER BY order_year;

-- Q1b YoY
WITH y AS (
  SELECT order_year, SUM(sales_amount) AS net_sales
  FROM sales_view WHERE order_status = 'Delivered'
  GROUP BY order_year
)
SELECT ROUND((MAX(net_sales) FILTER (WHERE order_year = 2025)
            / MAX(net_sales) FILTER (WHERE order_year = 2024) - 1) * 100, 2) AS yoy_growth_pct
FROM y;

-- Q2
SELECT category,
       ROUND(SUM(sales_amount))                         AS net_sales,
       ROUND(SUM(profit))                               AS profit,
       ROUND(SUM(profit) / SUM(sales_amount) * 100, 1)  AS margin_pct
FROM sales_view
WHERE order_status = 'Delivered'
GROUP BY category
ORDER BY margin_pct;

-- Q3
SELECT order_month, ROUND(SUM(sales_amount)) AS net_sales
FROM sales_view
WHERE order_status = 'Delivered'
GROUP BY order_month
ORDER BY net_sales DESC
LIMIT 3;

-- Q4
SELECT
  CASE
    WHEN discount = 0     THEN '1. 0%'
    WHEN discount <= 0.10 THEN '2. 1-10%'
    WHEN discount <= 0.20 THEN '3. 11-20%'
    WHEN discount <= 0.30 THEN '4. 21-30%'
    ELSE                       '5. >30%'
  END                                              AS discount_bucket,
  COUNT(*)                                         AS lines,
  ROUND(SUM(sales_amount))                         AS net_sales,
  ROUND(SUM(profit))                               AS profit,
  ROUND(SUM(profit) / SUM(sales_amount) * 100, 1)  AS margin_pct
FROM sales_view
WHERE order_status = 'Delivered'
GROUP BY 1
ORDER BY 1;

-- Q5
SELECT region, store_name,
       ROUND(SUM(sales_amount)) AS net_sales,
       RANK() OVER (PARTITION BY region ORDER BY SUM(sales_amount) DESC) AS rank_in_region
FROM sales_view
WHERE order_status = 'Delivered'
GROUP BY region, store_name
ORDER BY region, rank_in_region;

-- Q6 top
SELECT product_name, ROUND(SUM(profit)) AS profit
FROM sales_view
WHERE order_status = 'Delivered' AND cost_price IS NOT NULL
GROUP BY product_name
ORDER BY profit DESC
LIMIT 5;
-- Q6 bottom
SELECT product_name, ROUND(SUM(profit)) AS profit
FROM sales_view
WHERE order_status = 'Delivered' AND cost_price IS NOT NULL
GROUP BY product_name
ORDER BY profit ASC
LIMIT 5;

-- Q7
WITH order_level AS (
  SELECT order_id, payment_mode,
         BOOL_OR(order_status = 'Cancelled') AS is_cancelled
  FROM sales_view
  GROUP BY order_id, payment_mode
)
SELECT payment_mode,
       COUNT(*)                                                       AS orders,
       COUNT(*) FILTER (WHERE is_cancelled)                           AS cancelled_orders,
       ROUND(COUNT(*) FILTER (WHERE is_cancelled) * 100.0 / COUNT(*), 2) AS cancel_rate_pct
FROM order_level
GROUP BY payment_mode
ORDER BY cancel_rate_pct DESC;

-- Q8
SELECT category,
       COUNT(*)                                                         AS lines,
       COUNT(*) FILTER (WHERE order_status = 'Returned')                AS returned,
       ROUND(COUNT(*) FILTER (WHERE order_status = 'Returned') * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM sales_view
WHERE order_status <> 'Cancelled'
GROUP BY category
ORDER BY return_rate_pct DESC;

-- Q9a
WITH cust AS (
  SELECT customer_id, COUNT(DISTINCT order_id) AS delivered_orders
  FROM sales_view
  WHERE order_status = 'Delivered'
  GROUP BY customer_id
)
SELECT COUNT(*)                                                   AS customers,
       COUNT(*) FILTER (WHERE delivered_orders > 1)               AS repeat_customers,
       ROUND(COUNT(*) FILTER (WHERE delivered_orders > 1) * 100.0 / COUNT(*), 2) AS repeat_pct
FROM cust;
-- Q9b
SELECT customer_id,
       COALESCE(customer_name, 'Unknown customer') AS customer_name,
       COALESCE(customer_city, 'Unknown')          AS city,
       ROUND(SUM(sales_amount))                    AS net_sales
FROM sales_view
WHERE order_status = 'Delivered'
GROUP BY customer_id, customer_name, customer_city
ORDER BY net_sales DESC
LIMIT 10;

-- Q10
WITH m AS (
  SELECT order_month, SUM(sales_amount) AS net_sales
  FROM sales_view
  WHERE order_status = 'Delivered' AND order_year = 2025
  GROUP BY order_month
)
SELECT order_month,
       ROUND(net_sales)                                                AS net_sales,
       ROUND(SUM(net_sales) OVER (ORDER BY order_month))              AS running_total,
       ROUND((net_sales / LAG(net_sales) OVER (ORDER BY order_month) - 1) * 100, 1) AS mom_growth_pct
FROM m
ORDER BY order_month;

-- Bonus
SELECT region,
       ROUND(AVG(ship_date - order_date), 2) AS avg_delivery_days
FROM sales_view
WHERE order_status = 'Delivered' AND NOT bad_ship_date
GROUP BY region
ORDER BY avg_delivery_days;
