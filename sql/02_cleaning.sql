-- FreshKart retail analysis: cleaning (PostgreSQL / Supabase). Re-runnable: each clean table is dropped and rebuilt from the raw tables.

DROP TABLE IF EXISTS stores_clean; CREATE TABLE stores_clean AS SELECT store_id, store_name, city, region, opened_date::date AS opened_date FROM stores_raw;
DROP TABLE IF EXISTS products_clean; CREATE TABLE products_clean AS
SELECT DISTINCT UPPER(TRIM(product_id)) AS product_id, TRIM(product_name) AS product_name, INITCAP(TRIM(category)) AS category,
 TRIM(sub_category) AS sub_category, unit_price::numeric AS unit_price, cost_price::numeric AS cost_price FROM products_raw;
DROP TABLE IF EXISTS customers_clean;
CREATE TABLE customers_clean AS
SELECT DISTINCT TRIM(customer_id) AS customer_id, INITCAP(TRIM(customer_name)) AS customer_name,
 CASE WHEN gender IS NULL THEN 'Unknown' WHEN UPPER(LEFT(TRIM(gender),1))='M' THEN 'Male' WHEN UPPER(LEFT(TRIM(gender),1))='F' THEN 'Female' END AS gender,
 CASE INITCAP(TRIM(city)) WHEN 'Bangalore' THEN 'Bengaluru' WHEN 'New Delhi' THEN 'Delhi' WHEN 'Gurgaon' THEN 'Gurugram' WHEN 'Bombay' THEN 'Mumbai' ELSE INITCAP(TRIM(city)) END AS city,
 CASE WHEN signup_date ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(signup_date,'YYYY-MM-DD') WHEN signup_date ~ '^\d{2}-\d{2}-\d{4}$' THEN TO_DATE(signup_date,'DD-MM-YYYY')
      WHEN signup_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(signup_date,'DD/MM/YYYY') WHEN signup_date ~ '^\d{4}/\d{2}/\d{2}$' THEN TO_DATE(signup_date,'YYYY/MM/DD') END AS signup_date,
 COALESCE(segment,'Unknown') AS segment FROM customers_raw;

DROP TABLE IF EXISTS orders_clean;

CREATE TABLE orders_clean AS
WITH dedup AS (                                   -- Step 1: remove exact duplicate rows
  SELECT DISTINCT * FROM orders_raw
),
parsed AS (                                       -- Step 2: standardise formats and types
  SELECT
    TRIM(order_id)                         AS order_id,
    line_no::int                           AS line_no,
    CASE
      WHEN order_date ~ '^\d{4}-\d{2}-\d{2}$' THEN TO_DATE(order_date, 'YYYY-MM-DD')
      WHEN order_date ~ '^\d{2}-\d{2}-\d{4}$' THEN TO_DATE(order_date, 'DD-MM-YYYY')
      WHEN order_date ~ '^\d{2}/\d{2}/\d{4}$' THEN TO_DATE(order_date, 'DD/MM/YYYY')
      WHEN order_date ~ '^\d{4}/\d{2}/\d{2}$' THEN TO_DATE(order_date, 'YYYY/MM/DD')
    END                                    AS order_date,
    ship_date::date                        AS ship_date,
    TRIM(customer_id)                      AS customer_id,
    TRIM(store_id)                         AS store_id,
    UPPER(TRIM(product_id))                AS product_id,
    quantity::int                          AS qty_raw,
    CASE
      WHEN discount LIKE '%\%%' THEN REPLACE(discount, '%', '')::numeric / 100
      ELSE discount::numeric
    END                                    AS disc_raw,
    REPLACE(REPLACE(sales_amount, '₹', ''), ',', '')::numeric AS sales_amount,
    CASE
      WHEN UPPER(TRIM(payment_mode)) IN ('COD', 'CASH ON DELIVERY') THEN 'Cash on Delivery'
      ELSE TRIM(payment_mode)
    END                                    AS payment_mode,
    INITCAP(TRIM(order_status))            AS order_status
  FROM dedup
),
fixed AS (                                        -- Step 3: business rules (sales_amount is the trusted source)
  SELECT
    p.*,
    pr.unit_price,
    COALESCE(
      p.disc_raw,
      ROUND(1 - p.sales_amount / (ABS(p.qty_raw) * pr.unit_price), 2)
    )                                      AS discount
  FROM parsed p
  JOIN products_clean pr ON pr.product_id = p.product_id
)
SELECT
  order_id, line_no, order_date, ship_date, customer_id, store_id, product_id,
  CASE
    WHEN qty_raw < 0   THEN ABS(qty_raw)
    WHEN qty_raw = 999 THEN ROUND(sales_amount / (unit_price * (1 - discount)))::int
    ELSE qty_raw
  END                                      AS quantity,
  discount,
  sales_amount,
  payment_mode,
  order_status,
  (customer_id NOT IN (SELECT customer_id FROM customers_clean)) AS is_unknown_customer,
  (ship_date IS NULL OR ship_date < order_date)                 AS bad_ship_date
FROM fixed;

-- Reporting view used by the analysis queries and the Power BI dashboard
CREATE OR REPLACE VIEW sales_view AS
SELECT o.*,
       EXTRACT(YEAR FROM o.order_date)::int       AS order_year,
       DATE_TRUNC('month', o.order_date)::date    AS order_month,
       p.product_name, p.category, p.sub_category, p.unit_price, p.cost_price,
       o.sales_amount - o.quantity * p.cost_price AS profit,
       s.store_name, s.city AS store_city, s.region,
       c.customer_name, c.city AS customer_city, c.segment
FROM orders_clean o
JOIN products_clean  p ON p.product_id  = o.product_id
JOIN stores_clean    s ON s.store_id    = o.store_id
LEFT JOIN customers_clean c ON c.customer_id = o.customer_id;

-- Validation checks (expected results in comments)
SELECT COUNT(*) FROM orders_clean;                                         -- 5469
SELECT COUNT(*) FROM orders_clean WHERE order_date IS NULL;                -- 0
SELECT COUNT(*) FROM orders_clean WHERE quantity <= 0 OR quantity > 50;    -- 0
SELECT COUNT(*) AS mismatch
FROM orders_clean o JOIN products_clean p USING (product_id)
WHERE ABS(ROUND(o.quantity * p.unit_price * (1 - o.discount), 2) - o.sales_amount) > 1;   -- 0
