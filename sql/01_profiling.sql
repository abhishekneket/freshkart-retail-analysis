-- FreshKart retail analysis: data profiling (PostgreSQL / Supabase)
-- Raw CSVs were loaded into *_raw tables with every column as text, so no row is dropped on import.

-- 0. Row counts vs source files (expected: orders 5511, customers 2025, products 48, stores 12)
SELECT 'orders' AS t, COUNT(*) FROM orders_raw
UNION ALL SELECT 'customers', COUNT(*) FROM customers_raw
UNION ALL SELECT 'products',  COUNT(*) FROM products_raw
UNION ALL SELECT 'stores',    COUNT(*) FROM stores_raw;

-- =========================== STORES ===========================
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT store_id) AS distinct_stores FROM stores_raw;
SELECT region, city, COUNT(*) FROM stores_raw GROUP BY region, city ORDER BY region, city;
SELECT COUNT(*) FILTER (WHERE opened_date !~ '^\d{4}-\d{2}-\d{2}$') AS bad_format,
       MIN(opened_date), MAX(opened_date)
FROM stores_raw;

-- =========================== PRODUCTS ===========================
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT product_id) AS distinct_products FROM products_raw;

SELECT *, COUNT(*) AS cnt
FROM products_raw
GROUP BY product_id, product_name, category, sub_category, unit_price, cost_price
HAVING COUNT(*) > 1;

SELECT COUNT(*) - COUNT(product_name) AS null_name,
       COUNT(*) - COUNT(category)     AS null_category,
       COUNT(*) - COUNT(unit_price)   AS null_unit_price,
       COUNT(*) - COUNT(cost_price)   AS null_cost_price
FROM products_raw;

SELECT category, sub_category, COUNT(*) FROM products_raw GROUP BY 1, 2 ORDER BY 1, 2;

SELECT product_id, category, LENGTH(category) AS len_original, LENGTH(TRIM(category)) AS len_trimmed
FROM products_raw
WHERE category <> INITCAP(TRIM(category));

SELECT product_id, product_name, unit_price, cost_price
FROM products_raw
WHERE unit_price !~ '^[0-9]+(\.[0-9]+)?$'
   OR cost_price !~ '^[0-9]+(\.[0-9]+)?$'
   OR cost_price IS NULL;

-- =========================== CUSTOMERS ===========================
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT customer_id) AS distinct_customers FROM customers_raw;

SELECT COUNT(*) AS dup_groups, SUM(cnt - 1) AS extra_rows
FROM (SELECT COUNT(*) AS cnt FROM customers_raw
      GROUP BY customer_id, customer_name, gender, city, signup_date, segment
      HAVING COUNT(*) > 1) d;

SELECT COUNT(*) - COUNT(gender)  AS null_gender,
       COUNT(*) - COUNT(segment) AS null_segment,
       COUNT(*) - COUNT(city)    AS null_city
FROM customers_raw;

SELECT gender,  COUNT(*) FROM customers_raw GROUP BY 1 ORDER BY 1;
SELECT segment, COUNT(*) FROM customers_raw GROUP BY 1 ORDER BY 1;
SELECT city,    COUNT(*) FROM customers_raw GROUP BY 1 ORDER BY 1;

SELECT CASE
         WHEN signup_date ~ '^\d{4}-\d{2}-\d{2}$' THEN 'YYYY-MM-DD'
         WHEN signup_date ~ '^\d{2}-\d{2}-\d{4}$' THEN 'DD-MM-YYYY'
         WHEN signup_date ~ '^\d{2}/\d{2}/\d{4}$' THEN 'DD/MM/YYYY'
         WHEN signup_date ~ '^\d{4}/\d{2}/\d{2}$' THEN 'YYYY/MM/DD'
         ELSE 'OTHER'
       END AS date_format, COUNT(*)
FROM customers_raw GROUP BY 1;

SELECT customer_id, customer_name FROM customers_raw
WHERE customer_name <> TRIM(customer_name) OR customer_name = UPPER(customer_name);

-- =========================== ORDERS ===========================
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id || '-' || line_no) AS distinct_lines,
       COUNT(DISTINCT order_id) AS distinct_orders
FROM orders_raw;

SELECT COUNT(*) AS dup_groups, SUM(cnt - 1) AS extra_rows
FROM (SELECT COUNT(*) AS cnt FROM orders_raw
      GROUP BY order_id, line_no, order_date, ship_date, customer_id, store_id, product_id,
               quantity, discount, sales_amount, payment_mode, order_status
      HAVING COUNT(*) > 1) d;

SELECT COUNT(*) - COUNT(ship_date)    AS null_ship_date,
       COUNT(*) - COUNT(discount)     AS null_discount,
       COUNT(*) - COUNT(sales_amount) AS null_sales
FROM orders_raw;

SELECT CASE
         WHEN order_date ~ '^\d{4}-\d{2}-\d{2}$' THEN 'YYYY-MM-DD'
         WHEN order_date ~ '^\d{2}-\d{2}-\d{4}$' THEN 'DD-MM-YYYY'
         WHEN order_date ~ '^\d{2}/\d{2}/\d{4}$' THEN 'DD/MM/YYYY'
         WHEN order_date ~ '^\d{4}/\d{2}/\d{2}$' THEN 'YYYY/MM/DD'
         ELSE 'OTHER'
       END AS date_format, COUNT(*)
FROM orders_raw GROUP BY 1;

SELECT COUNT(*) FILTER (WHERE quantity     !~ '^-?[0-9]+$')          AS bad_qty,
       COUNT(*) FILTER (WHERE discount     !~ '^[0-9]+(\.[0-9]+)?$') AS bad_discount,
       COUNT(*) FILTER (WHERE sales_amount !~ '^[0-9]+(\.[0-9]+)?$') AS bad_sales
FROM orders_raw;

SELECT quantity, COUNT(*) FROM orders_raw
WHERE quantity::int <= 0 OR quantity::int > 50
GROUP BY quantity;

SELECT payment_mode, COUNT(*) FROM orders_raw GROUP BY 1 ORDER BY 1;
SELECT order_status, COUNT(*) FROM orders_raw GROUP BY 1 ORDER BY 1;

-- Referential integrity: orders whose keys are missing from master tables
SELECT 'customer' AS missing_in, COUNT(*) FROM orders_raw o
LEFT JOIN customers_raw c ON o.customer_id = c.customer_id WHERE c.customer_id IS NULL
UNION ALL
SELECT 'product', COUNT(*) FROM orders_raw o
LEFT JOIN products_raw p ON o.product_id = p.product_id WHERE p.product_id IS NULL
UNION ALL
SELECT 'store', COUNT(*) FROM orders_raw o
LEFT JOIN stores_raw s ON o.store_id = s.store_id WHERE s.store_id IS NULL;

-- Root cause check: product mismatches are only a case issue (expected 0)
SELECT COUNT(*) AS still_missing FROM orders_raw o
LEFT JOIN products_raw p ON UPPER(o.product_id) = p.product_id
WHERE p.product_id IS NULL;
