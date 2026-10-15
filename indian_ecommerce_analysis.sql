/* =====================================================================
   INDIAN E-COMMERCE ANALYSIS  |  MySQL 8.0
   Author : Rahul Ballidav
   ---------------------------------------------------------------------
   Run order (top to bottom):
     PART 1  Create database and tables
     PART 2  Load the 8 CSV files
     PART 3  Validate the load (row counts, keys, NULLs, integrity)
     PART 4  Reporting view (single revenue definition)
     PART 5  Exploratory analysis          (Q1  - Q40)
     PART 6  Business analysis for the dashboard (B1 - B15)
     PART 7  Checks behind the dashboard findings

   Revenue definition used in PART 4, 6 and 7:
     Revenue = item_revenue of every order EXCEPT order_status = 'Cancelled'
     (Returned, Failed and Processing orders are still included.)

   Before loading, check which folder MySQL allows for LOAD DATA:
     SHOW VARIABLES LIKE 'secure_file_priv';
   and place the CSV files there (or change the paths below).
   ===================================================================== */


/* =====================================================================
   PART 1. DATABASE AND TABLES
   ===================================================================== */
CREATE DATABASE IF NOT EXISTS indian_ecommerce;
USE indian_ecommerce;

-- 1. CUSTOMERS
CREATE TABLE IF NOT EXISTS customers (
    customer_id              VARCHAR(30) PRIMARY KEY,
    customer_signup_date     DATE,
    gender                   VARCHAR(20),
    age                      INT NULL,
    age_group                VARCHAR(30),
    state                    VARCHAR(100),
    city                     VARCHAR(100),
    pincode_prefix           VARCHAR(10),
    customer_segment         VARCHAR(50),
    preferred_device         VARCHAR(50) NULL,
    preferred_payment_method VARCHAR(50),
    acquisition_channel      VARCHAR(50),
    total_orders             INT,
    total_spend              DECIMAL(14,2),
    last_order_date          DATE NULL,
    average_order_value      DECIMAL(14,2) NULL,
    customer_status          VARCHAR(50),
    loyalty_tier             VARCHAR(30)
);

-- 2. PRODUCTS
CREATE TABLE IF NOT EXISTS products (
    product_id           VARCHAR(30) PRIMARY KEY,
    product_name         VARCHAR(255),
    category             VARCHAR(100),
    subcategory          VARCHAR(100),
    brand                VARCHAR(100),
    price                DECIMAL(14,2),
    cost_price           DECIMAL(14,2),
    discount_range       VARCHAR(30),
    rating_average       DECIMAL(4,2) NULL,
    rating_count         INT,
    stock_quantity       INT,
    product_launch_date  DATE,
    product_type         VARCHAR(100),
    return_rate_baseline DECIMAL(8,4)
);

-- 3. ORDERS
CREATE TABLE IF NOT EXISTS orders (
    order_id            VARCHAR(30) PRIMARY KEY,
    customer_id         VARCHAR(30),
    order_date          DATE,
    order_time          TIME,
    order_status        VARCHAR(50),
    shipping_method     VARCHAR(50),
    delivery_city       VARCHAR(100),
    delivery_state      VARCHAR(100),
    coupon_code         VARCHAR(100) NULL,
    discount_percentage DECIMAL(8,2),
    marketing_channel   VARCHAR(100),
    subtotal            DECIMAL(14,2),
    shipping_fee        DECIMAL(14,2),
    tax_amount          DECIMAL(14,2),
    final_amount        DECIMAL(14,2),
    campaign_id         VARCHAR(30) NULL,
    INDEX idx_orders_customer (customer_id),
    INDEX idx_orders_date (order_date)
);

-- 4. ORDER ITEMS
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id       VARCHAR(30) PRIMARY KEY,
    order_id            VARCHAR(30),
    product_id          VARCHAR(30),
    quantity            INT,
    unit_price          DECIMAL(14,2),
    discount_percentage DECIMAL(8,2),
    item_revenue        DECIMAL(14,2),
    item_cost           DECIMAL(14,2),
    profit              DECIMAL(14,2),
    INDEX idx_items_order (order_id),
    INDEX idx_items_product (product_id)
);

-- 5. PAYMENTS
CREATE TABLE IF NOT EXISTS payments (
    payment_id      VARCHAR(30) PRIMARY KEY,
    order_id        VARCHAR(30),
    payment_date    DATE,
    payment_method  VARCHAR(50),
    payment_status  VARCHAR(50),
    amount_paid     DECIMAL(14,2),
    transaction_fee DECIMAL(14,2),
    refund_amount   DECIMAL(14,2),
    INDEX idx_payments_order (order_id)
);

-- 6. RETURNS
CREATE TABLE IF NOT EXISTS returns (
    return_id     VARCHAR(30) PRIMARY KEY,
    order_id      VARCHAR(30),
    customer_id   VARCHAR(30),
    product_id    VARCHAR(30),
    return_date   DATE,
    return_reason VARCHAR(100),
    refund_amount DECIMAL(14,2),
    return_status VARCHAR(50),
    INDEX idx_returns_order (order_id),
    INDEX idx_returns_product (product_id)
);

-- 7. SHIPMENTS
CREATE TABLE IF NOT EXISTS shipments (
    shipment_id            VARCHAR(30) PRIMARY KEY,
    order_id               VARCHAR(30),
    warehouse_city         VARCHAR(100),
    delivery_city          VARCHAR(100),
    shipping_method        VARCHAR(50),
    dispatch_date          DATE,
    expected_delivery_date DATE,
    actual_delivery_date   DATE NULL,
    delivery_days          DECIMAL(8,2) NULL,
    delivery_status        VARCHAR(50),
    delayed_flag           TINYINT,
    INDEX idx_shipments_order (order_id)
);

-- 8. CUSTOMER REVIEWS
CREATE TABLE IF NOT EXISTS customer_reviews (
    review_id         VARCHAR(30) PRIMARY KEY,
    order_id          VARCHAR(30),
    customer_id       VARCHAR(30),
    product_id        VARCHAR(30),
    review_date       DATE,
    rating            INT,
    review_sentiment  VARCHAR(50) NULL,
    verified_purchase VARCHAR(10),
    INDEX idx_reviews_order (order_id),
    INDEX idx_reviews_product (product_id)
);


/* =====================================================================
   PART 2. LOAD THE DATA
   Cleaning at load time:
     - dates arrive as dd-mm-yyyy and are converted with STR_TO_DATE
     - blank text/number fields become NULL (NULLIF) instead of '' or 0
     - UTF-8 (utf8mb4) so the rupee symbol and product names load cleanly
   Each file is loaded exactly once, after the tables are emptied.
   ===================================================================== */
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE customer_reviews;
TRUNCATE TABLE order_items;
TRUNCATE TABLE payments;
TRUNCATE TABLE returns;
TRUNCATE TABLE shipments;
TRUNCATE TABLE orders;
TRUNCATE TABLE products;
TRUNCATE TABLE customers;

SET FOREIGN_KEY_CHECKS = 1;

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers.csv'
INTO TABLE customers
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    customer_id,
    @customer_signup_date,
    gender,
    @age,
    age_group,
    state,
    city,
    pincode_prefix,
    customer_segment,
    @preferred_device,
    preferred_payment_method,
    acquisition_channel,
    total_orders,
    total_spend,
    @last_order_date,
    @average_order_value,
    customer_status,
    loyalty_tier
)
SET
    customer_signup_date = STR_TO_DATE(@customer_signup_date, '%d-%m-%Y'),
    age                  = NULLIF(@age, ''),
    preferred_device     = NULLIF(@preferred_device, ''),
    last_order_date      = STR_TO_DATE(NULLIF(@last_order_date, ''), '%d-%m-%Y'),
    average_order_value  = NULLIF(@average_order_value, '');

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/products.csv'
INTO TABLE products
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    product_id,
    product_name,
    category,
    subcategory,
    brand,
    price,
    cost_price,
    discount_range,
    @rating_average,
    rating_count,
    stock_quantity,
    @product_launch_date,
    product_type,
    return_rate_baseline
)
SET
    rating_average      = NULLIF(@rating_average, ''),
    product_launch_date = STR_TO_DATE(@product_launch_date, '%d-%m-%Y');

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/orders.csv'
INTO TABLE orders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    order_id,
    customer_id,
    @order_date,
    order_time,
    order_status,
    shipping_method,
    delivery_city,
    delivery_state,
    @coupon_code,
    discount_percentage,
    marketing_channel,
    subtotal,
    shipping_fee,
    tax_amount,
    final_amount,
    @campaign_id
)
SET
    order_date  = STR_TO_DATE(@order_date, '%d-%m-%Y'),
    coupon_code = NULLIF(@coupon_code, ''),
    campaign_id = NULLIF(@campaign_id, '');

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/order_items.csv'
INTO TABLE order_items
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount_percentage,
    item_revenue,
    item_cost,
    profit
);

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/payments.csv'
INTO TABLE payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    payment_id,
    order_id,
    @payment_date,
    payment_method,
    payment_status,
    amount_paid,
    transaction_fee,
    refund_amount
)
SET
    payment_date = STR_TO_DATE(@payment_date, '%d-%m-%Y');

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/returns.csv'
INTO TABLE returns
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    return_id,
    order_id,
    customer_id,
    product_id,
    @return_date,
    return_reason,
    refund_amount,
    return_status
)
SET
    return_date = STR_TO_DATE(@return_date, '%d-%m-%Y');

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/shipments.csv'
INTO TABLE shipments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    shipment_id,
    order_id,
    warehouse_city,
    delivery_city,
    shipping_method,
    @dispatch_date,
    @expected_delivery_date,
    @actual_delivery_date,
    @delivery_days,
    delivery_status,
    delayed_flag
)
SET
    dispatch_date          = STR_TO_DATE(@dispatch_date, '%d-%m-%Y'),
    expected_delivery_date = STR_TO_DATE(@expected_delivery_date, '%d-%m-%Y'),
    actual_delivery_date   = STR_TO_DATE(NULLIF(@actual_delivery_date, ''), '%d-%m-%Y'),
    delivery_days          = NULLIF(@delivery_days, '');

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customer_reviews.csv'
INTO TABLE customer_reviews
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(
    review_id,
    order_id,
    customer_id,
    product_id,
    @review_date,
    rating,
    @review_sentiment,
    verified_purchase
)
SET
    review_date      = STR_TO_DATE(@review_date, '%d-%m-%Y'),
    review_sentiment = NULLIF(@review_sentiment, '');

SHOW WARNINGS;


/* =====================================================================
   PART 3. VALIDATE THE LOAD
   ===================================================================== */

-- 3.1 Row counts (expected: 550 products, 100,000 orders, 254,331 order items)
SELECT 'customers' AS table_name, COUNT(*) AS total_rows FROM customers
UNION ALL SELECT 'products',         COUNT(*) FROM products
UNION ALL SELECT 'orders',           COUNT(*) FROM orders
UNION ALL SELECT 'order_items',      COUNT(*) FROM order_items
UNION ALL SELECT 'payments',         COUNT(*) FROM payments
UNION ALL SELECT 'returns',          COUNT(*) FROM returns
UNION ALL SELECT 'shipments',        COUNT(*) FROM shipments
UNION ALL SELECT 'customer_reviews', COUNT(*) FROM customer_reviews;

-- 3.2 Primary keys are unique (total_rows should equal unique_ids)
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT customer_id)   AS unique_ids FROM customers;
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT product_id)    AS unique_ids FROM products;
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id)      AS unique_ids FROM orders;
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_item_id) AS unique_ids FROM order_items;

-- 3.3 Expected NULLs (genuinely missing values, not load errors)
SELECT COUNT(*) AS missing_age                  FROM customers WHERE age IS NULL;
SELECT COUNT(*) AS missing_last_order_date      FROM customers WHERE last_order_date IS NULL;
SELECT COUNT(*) AS orders_without_campaign      FROM orders    WHERE campaign_id IS NULL;
SELECT COUNT(*) AS missing_actual_delivery_date FROM shipments WHERE actual_delivery_date IS NULL;

-- 3.4 Referential integrity (every result should be 0)
SELECT 'orders -> customers'   AS check_name, COUNT(*) AS problem_rows
FROM orders o LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'order_items -> orders', COUNT(*)
FROM order_items oi LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_items -> products', COUNT(*)
FROM order_items oi LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'payments -> orders', COUNT(*)
FROM payments p LEFT JOIN orders o ON p.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'shipments -> orders', COUNT(*)
FROM shipments s LEFT JOIN orders o ON s.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'returns -> products', COUNT(*)
FROM returns r LEFT JOIN products p ON r.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'reviews -> orders', COUNT(*)
FROM customer_reviews r LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 3.5 Business-rule checks (every result should be 0)
SELECT COUNT(*) AS profit_not_equal_revenue_minus_cost
FROM order_items
WHERE ABS(profit - (item_revenue - item_cost)) > 0.01;

-- 3.6 Allowed status values (used as filters in the queries below)
SELECT DISTINCT order_status   FROM orders;
SELECT DISTINCT payment_status FROM payments;
SELECT DISTINCT return_status  FROM returns;

-- 3.7 Discounts are stored as 0-100, not 0-1 (observed range: 0 to 33)
SELECT MIN(discount_percentage) AS min_discount,
       MAX(discount_percentage) AS max_discount
FROM order_items;


/* =====================================================================
   PART 4. REPORTING VIEW
   One revenue definition for all business queries:
   every order line except those on Cancelled orders.
   ===================================================================== */
CREATE OR REPLACE VIEW vw_item_sales AS
SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id,
    o.customer_id,
    o.order_date,
    o.order_status,
    o.marketing_channel,
    o.coupon_code,
    o.delivery_state,
    p.category,
    p.subcategory,
    p.brand,
    oi.quantity,
    oi.unit_price,
    oi.discount_percentage AS item_discount_pct,
    oi.item_revenue,
    oi.item_cost,
    oi.profit
FROM order_items oi
JOIN orders o   ON oi.order_id   = o.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status <> 'Cancelled';


/* =====================================================================
   PART 5. EXPLORATORY ANALYSIS (Q1 - Q40)
   Note: Q19-Q26, Q36 and Q37 aggregate ALL orders, including cancelled
   ones, to show the raw recorded figures. The dashboard figures in
   PART 6 use vw_item_sales, which excludes cancelled orders.
   ===================================================================== */

-- Q1. The first 20 customers.
SELECT *
FROM customers
LIMIT 20;

-- Q2. Customers from Karnataka.
SELECT customer_id, city, state, customer_segment
FROM customers
WHERE state = 'Karnataka';

-- Q3. Customers aged between 25 and 35.
SELECT customer_id, age, city
FROM customers
WHERE age BETWEEN 25 AND 35;

-- Q4. All distinct product categories.
SELECT DISTINCT category
FROM products
ORDER BY category;

-- Q5. Products priced above Rs 10,000.
SELECT product_id, product_name, category, price
FROM products
WHERE price > 10000
ORDER BY price DESC;

-- Q6. Orders that were cancelled.
SELECT order_id, customer_id, order_date, final_amount
FROM orders
WHERE order_status = 'Cancelled';

-- Q7. Count customers by state.
SELECT state, COUNT(*) AS total_customers
FROM customers
GROUP BY state
ORDER BY total_customers DESC;

-- Q8. The average, minimum and maximum product price.
SELECT
    AVG(price) AS average_price,
    MIN(price) AS minimum_price,
    MAX(price) AS maximum_price
FROM products;

-- Q9. Count orders by order status.
SELECT order_status, COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Q10. Count products by category.
SELECT category, COUNT(*) AS product_count
FROM products
GROUP BY category
ORDER BY product_count DESC;

-- Q11. Categories with an average price above Rs 2,000.
SELECT category, AVG(price) AS average_price
FROM products
GROUP BY category
HAVING AVG(price) > 2000;

-- Q12. The top 10 cities by customer count.
SELECT city, state, COUNT(*) AS customer_count
FROM customers
GROUP BY city, state
ORDER BY customer_count DESC
LIMIT 10;

-- Q13. Total recorded customer spending by loyalty tier.
SELECT loyalty_tier, SUM(total_spend) AS recorded_customer_spend
FROM customers
GROUP BY loyalty_tier
ORDER BY recorded_customer_spend DESC;

-- Q14. Total orders and average order amount by state.
SELECT
    delivery_state,
    COUNT(*) AS total_orders,
    AVG(final_amount) AS average_order_amount
FROM orders
GROUP BY delivery_state
ORDER BY total_orders DESC;

-- Q15. Total quantities sold by product (top 10).
SELECT
    p.product_id,
    p.product_name,
    SUM(oi.quantity) AS units_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY units_sold DESC
LIMIT 10;

-- Q16. Payment counts by payment method and status.
SELECT payment_method, payment_status, COUNT(*) AS payment_count
FROM payments
GROUP BY payment_method, payment_status
ORDER BY payment_method, payment_count DESC;

-- Q17. Customers and their orders.
SELECT
    c.customer_id,
    c.city,
    c.state,
    o.order_id,
    o.order_date,
    o.order_status,
    o.final_amount
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
LIMIT 100;

-- Q18. Each order item with its product details.
SELECT
    oi.order_id,
    p.product_name,
    p.category,
    oi.quantity,
    oi.unit_price,
    oi.item_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LIMIT 100;

-- Q19. Recorded item revenue by category.
SELECT
    p.category,
    SUM(oi.item_revenue) AS item_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY item_revenue DESC;

-- Q20. The top 10 products by recorded item revenue.
SELECT
    p.product_id,
    p.product_name,
    SUM(oi.item_revenue) AS item_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY item_revenue DESC
LIMIT 10;

-- Q21. Order count and recorded order value by customer.
SELECT
    c.customer_id,
    c.city,
    COUNT(o.order_id) AS order_count,
    SUM(o.final_amount) AS recorded_order_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.city
ORDER BY recorded_order_value DESC;

-- Q22. The top 10 cities by recorded order value.
SELECT
    delivery_city,
    delivery_state,
    COUNT(*) AS order_count,
    SUM(final_amount) AS recorded_order_value
FROM orders
GROUP BY delivery_city, delivery_state
ORDER BY recorded_order_value DESC
LIMIT 10;

-- Q23. Average recorded order amount.
SELECT AVG(final_amount) AS average_order_amount
FROM orders;

-- Q24. Total recorded payment amount by payment method.
SELECT
    payment_method,
    SUM(amount_paid) AS total_amount_paid
FROM payments
GROUP BY payment_method
ORDER BY total_amount_paid DESC;

-- Q25. Recorded item profit by category.
SELECT
    p.category,
    SUM(oi.item_cost) AS total_item_cost,
    SUM(oi.profit) AS total_profit
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY total_profit DESC;

-- Q26. The top 10 most profitable products.
SELECT
    p.product_id,
    p.product_name,
    SUM(oi.profit) AS total_profit
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_profit DESC
LIMIT 10;

-- Q27. Products with negative total profit.
SELECT
    p.product_id,
    p.product_name,
    SUM(oi.profit) AS total_profit
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_name
HAVING SUM(oi.profit) < 0
ORDER BY total_profit;

-- Q28. Count returns by reason.
SELECT
    return_reason,
    COUNT(*) AS return_count,
    SUM(refund_amount) AS recorded_refund_amount
FROM returns
GROUP BY return_reason
ORDER BY return_count DESC;

-- Q29. The total refund amount by return status.
SELECT
    return_status,
    COUNT(*) AS return_count,
    SUM(refund_amount) AS recorded_refund_amount
FROM returns
GROUP BY return_status
ORDER BY recorded_refund_amount DESC;

-- Q30. The most frequently returned products.
SELECT
    p.product_id,
    p.product_name,
    COUNT(*) AS return_records,
    SUM(r.refund_amount) AS recorded_refunds
FROM returns r
JOIN products p ON r.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY return_records DESC
LIMIT 10;

-- Q31. The average delivery time by shipping method.
SELECT
    shipping_method,
    AVG(delivery_days) AS average_delivery_days
FROM shipments
WHERE delivery_days IS NOT NULL
GROUP BY shipping_method
ORDER BY average_delivery_days;

-- Q32. The percentage of shipments marked delayed.
SELECT
    COUNT(*) AS total_shipments,
    SUM(CASE WHEN delayed_flag = 1 THEN 1 ELSE 0 END) AS delayed_shipments,
    ROUND(
        100.0 * SUM(CASE WHEN delayed_flag = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS delayed_percentage
FROM shipments;

-- Q33. Average product rating by category.
SELECT
    p.category,
    ROUND(AVG(r.rating), 2) AS average_review_rating,
    COUNT(r.review_id) AS review_count
FROM customer_reviews r
JOIN products p ON r.product_id = p.product_id
GROUP BY p.category
ORDER BY average_review_rating DESC;

-- Q34. Review sentiment and ratings.
SELECT
    review_sentiment,
    COUNT(*) AS review_count,
    ROUND(AVG(rating), 2) AS average_rating
FROM customer_reviews
GROUP BY review_sentiment
ORDER BY review_count DESC;

-- Q35. Ranking the top 3 products within each category (window function).
WITH product_revenue AS (
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        SUM(oi.item_revenue) AS revenue
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name, p.category
),
ranked_products AS (
    SELECT
        *,
        DENSE_RANK() OVER (
            PARTITION BY category
            ORDER BY revenue DESC
        ) AS category_rank
    FROM product_revenue
)
SELECT *
FROM ranked_products
WHERE category_rank <= 3
ORDER BY category, category_rank;

-- Q36. Monthly order value and previous month's value (LAG).
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m') AS sales_month,
        SUM(final_amount) AS order_value
    FROM orders
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT
    sales_month,
    order_value,
    LAG(order_value) OVER (ORDER BY sales_month) AS previous_month_value
FROM monthly_sales
ORDER BY sales_month;

-- Q37. Running monthly order value (running total).
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m') AS sales_month,
        SUM(final_amount) AS order_value
    FROM orders
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT
    sales_month,
    order_value,
    SUM(order_value) OVER (
        ORDER BY sales_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_order_value
FROM monthly_sales
ORDER BY sales_month;

-- Q38. Customers whose recorded spending is above the average (subquery).
SELECT
    customer_id,
    city,
    state,
    total_spend
FROM customers
WHERE total_spend > (
    SELECT AVG(total_spend)
    FROM customers
)
ORDER BY total_spend DESC;

-- Q39. Order items that refer to missing orders or products (should be empty).
SELECT
    oi.order_item_id,
    oi.order_id,
    oi.product_id
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE o.order_id IS NULL
   OR p.product_id IS NULL;

-- Q40. Orders without a shipment record.
SELECT
    o.order_id,
    o.order_date,
    o.order_status,
    o.delivery_city,
    o.final_amount
FROM orders o
LEFT JOIN shipments s ON o.order_id = s.order_id
WHERE s.shipment_id IS NULL
ORDER BY o.order_date;


/* =====================================================================
   PART 6. BUSINESS ANALYSIS (B1 - B15)
   All queries use vw_item_sales (cancelled orders excluded).
   ===================================================================== */

-- B1. Headline KPIs
SELECT
    ROUND(SUM(item_revenue), 2) AS revenue,
    ROUND(SUM(profit), 2) AS profit,
    ROUND(100 * SUM(profit) / SUM(item_revenue), 2) AS margin_pct,
    COUNT(DISTINCT order_id) AS orders,
    SUM(quantity) AS units,
    ROUND(SUM(item_revenue) / COUNT(DISTINCT order_id), 2) AS aov
FROM vw_item_sales;

-- B2. Monthly revenue, profit and month-on-month growth
WITH m AS (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m') AS ym,
        SUM(item_revenue) AS rev,
        SUM(profit) AS profit
    FROM vw_item_sales
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT
    ym,
    ROUND(rev, 2) AS rev,
    ROUND(profit, 2) AS profit,
    ROUND(100 * (rev - LAG(rev) OVER (ORDER BY ym))
          / NULLIF(LAG(rev) OVER (ORDER BY ym), 0), 2) AS mom_pct
FROM m
ORDER BY ym;

-- B3. Category revenue share and margin
SELECT
    category,
    ROUND(SUM(item_revenue), 2) AS revenue,
    ROUND(SUM(profit), 2) AS profit,
    ROUND(100 * SUM(profit) / SUM(item_revenue), 2) AS margin_pct,
    ROUND(100 * SUM(item_revenue) / SUM(SUM(item_revenue)) OVER (), 2) AS revenue_share_pct
FROM vw_item_sales
GROUP BY category
ORDER BY revenue DESC;

-- B4. RFM customer segments (Recency, Frequency, Monetary)

WITH cust AS (
    SELECT
        customer_id,
        MAX(order_date) AS last_dt,
        COUNT(DISTINCT order_id) AS freq,
        SUM(item_revenue) AS monetary
    FROM vw_item_sales
    GROUP BY customer_id
),
scored AS (
    SELECT
        c.customer_id,
        c.freq,
        c.monetary,
        NTILE(5) OVER (ORDER BY DATEDIFF((SELECT MAX(order_date) FROM orders), c.last_dt) DESC) AS r,
        NTILE(5) OVER (ORDER BY c.freq) AS f,
        NTILE(5) OVER (ORDER BY c.monetary) AS m
    FROM cust c
),
seg AS (
    SELECT
        scored.*,
        CASE
            WHEN r >= 4 AND f >= 4 AND m >= 4 THEN 'Champions'
            WHEN r >= 3 AND f >= 3 THEN 'Loyal'
            WHEN r >= 4 AND f <= 2 THEN 'New / Promising'
            WHEN r <= 2 AND f >= 3 THEN 'At Risk'
            WHEN r <= 2 AND f <= 2 THEN 'Lost'
            ELSE 'Needs Attention'
        END AS segment
    FROM scored
)
SELECT
    segment,
    COUNT(*) AS customers,
    ROUND(SUM(monetary), 2) AS revenue
FROM seg
GROUP BY segment
ORDER BY revenue DESC;

-- B5. Repeat vs one-time customers

WITH c AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS n
    FROM vw_item_sales
    GROUP BY customer_id
)
SELECT
    CASE WHEN n = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM c
GROUP BY CASE WHEN n = 1 THEN 'One-time' ELSE 'Repeat' END;

-- B6. Cohort retention (by first-order month)

WITH f AS (
    SELECT customer_id, MIN(order_date) AS first_date
    FROM orders
    WHERE order_status <> 'Cancelled'
    GROUP BY customer_id
),
a AS (
    SELECT DISTINCT
        o.customer_id,
        DATE_FORMAT(f.first_date, '%Y-%m') AS cohort,
        TIMESTAMPDIFF(MONTH,
                      DATE_FORMAT(f.first_date, '%Y-%m-01'),
                      DATE_FORMAT(o.order_date, '%Y-%m-01')) AS month_no
    FROM orders o
    JOIN f ON o.customer_id = f.customer_id
    WHERE o.order_status <> 'Cancelled'
)
SELECT
    cohort,
    month_no,
    COUNT(*) AS active_customers,
    ROUND(100 * COUNT(*) /
          FIRST_VALUE(COUNT(*)) OVER (PARTITION BY cohort ORDER BY month_no), 2) AS retention_pct
FROM a
GROUP BY cohort, month_no
ORDER BY cohort, month_no;

-- B7. Marketing channel performance
SELECT
    marketing_channel,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(SUM(item_revenue), 2) AS revenue,
    ROUND(SUM(item_revenue) / COUNT(DISTINCT order_id), 2) AS aov,
    ROUND(100 * SUM(profit) / SUM(item_revenue), 2) AS margin_pct
FROM vw_item_sales
GROUP BY marketing_channel
ORDER BY revenue DESC;

-- B8. Coupon vs no coupon
SELECT
    CASE WHEN coupon_code IS NULL THEN 'No coupon' ELSE 'Coupon used' END AS coupon_flag,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(item_revenue) / COUNT(DISTINCT order_id), 2) AS aov,
    ROUND(100 * SUM(profit) / SUM(item_revenue), 2) AS margin_pct
FROM vw_item_sales
GROUP BY CASE WHEN coupon_code IS NULL THEN 'No coupon' ELSE 'Coupon used' END;

-- B9. Does discounting reduce profit margin? (discount stored as 0-100)
SELECT
    CASE
        WHEN item_discount_pct = 0  THEN '0 No discount'
        WHEN item_discount_pct < 10 THEN '1 Under 10%'
        WHEN item_discount_pct < 20 THEN '2 10-19%'
        WHEN item_discount_pct < 30 THEN '3 20-29%'
        ELSE '4 30%+'
    END AS discount_band,
    SUM(quantity) AS units,
    ROUND(SUM(item_revenue), 2) AS revenue,
    ROUND(100 * SUM(profit) / SUM(item_revenue), 2) AS margin_pct
FROM vw_item_sales
GROUP BY discount_band
ORDER BY discount_band;

-- B10. Return rate and refund burden by category
SELECT
    s.category,
    s.line_count,
    COALESCE(r.return_count, 0) AS returns,
    ROUND(100 * COALESCE(r.return_count, 0) / s.line_count, 2) AS return_rate_pct,
    ROUND(100 * COALESCE(r.refunds, 0) / s.revenue, 2) AS refund_pct_of_revenue
FROM (
    SELECT category, COUNT(*) AS line_count, SUM(item_revenue) AS revenue
    FROM vw_item_sales
    GROUP BY category
) s
LEFT JOIN (
    SELECT p.category, COUNT(*) AS return_count, SUM(r.refund_amount) AS refunds
    FROM returns r
    JOIN products p ON r.product_id = p.product_id
    GROUP BY p.category
) r ON s.category = r.category
ORDER BY return_rate_pct DESC;

-- B11. Delivery performance by warehouse and shipping method
SELECT
    warehouse_city,
    shipping_method,
    COUNT(*) AS shipments,
    ROUND(AVG(delivery_days), 2) AS avg_days,
    ROUND(100 * SUM(delayed_flag) / COUNT(*), 2) AS delayed_pct
FROM shipments
GROUP BY warehouse_city, shipping_method
ORDER BY delayed_pct DESC;

-- B12. Do delays hurt ratings?
SELECT
    CASE WHEN s.delayed_flag = 1 THEN 'Delayed' ELSE 'On time' END AS delivery,
    COUNT(*) AS reviews,
    ROUND(AVG(r.rating), 2) AS avg_rating
FROM customer_reviews r
JOIN shipments s ON r.order_id = s.order_id
GROUP BY CASE WHEN s.delayed_flag = 1 THEN 'Delayed' ELSE 'On time' END;

-- B13. Payment failure rate and fee cost by payment method
SELECT
    payment_method,
    COUNT(*) AS attempts,
    ROUND(100 * SUM(payment_status = 'Failed') / COUNT(*), 2) AS failure_pct,
    ROUND(SUM(transaction_fee), 2) AS fees,
    ROUND(100 * SUM(transaction_fee) / NULLIF(SUM(amount_paid), 0), 2) AS fee_pct_of_paid
FROM payments
GROUP BY payment_method
ORDER BY failure_pct DESC;

-- B14. Pareto: how many products make 80% of revenue?
WITH p AS (
    SELECT product_id, SUM(item_revenue) AS rev
    FROM vw_item_sales
    GROUP BY product_id
),
c AS (
    SELECT
        rev,
        SUM(rev) OVER (ORDER BY rev DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_rev,
        SUM(rev) OVER () AS total,
        COUNT(*) OVER () AS n
    FROM p
)
SELECT
    COUNT(*) AS products_for_80pct,
    MAX(n) AS total_products,
    ROUND(100 * COUNT(*) / MAX(n), 2) AS pct_of_products
FROM c
WHERE cum_rev - rev < 0.8 * total;

-- B15. When do people buy? (weekday x hour heatmap data)
SELECT
    DAYOFWEEK(order_date) AS dow,
    DAYNAME(order_date) AS weekday,
    HOUR(order_time) AS hr,
    COUNT(*) AS orders,
    ROUND(SUM(final_amount), 2) AS order_value
FROM orders
WHERE order_status <> 'Cancelled'
GROUP BY DAYOFWEEK(order_date), DAYNAME(order_date), HOUR(order_time)
ORDER BY dow, hr;


/* =====================================================================
   PART 7. CHECKS BEHIND THE DASHBOARD FINDINGS
   ===================================================================== */

-- 7.1 Payment status mix
--     Observed: Success 82,137 | Refunded 10,690 | Failed 5,068 |
--               Not Charged 1,876 | Pending 229  (total 100,000 = 1 per order)
SELECT payment_status, COUNT(*) AS total_payments
FROM payments
GROUP BY payment_status
ORDER BY total_payments DESC;

-- 7.2 Reviews join to shipments without duplicating rows
--     Observed: joined_rows = unique_reviews = 77,530
SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT r.review_id) AS unique_reviews
FROM customer_reviews r
JOIN shipments s ON r.order_id = s.order_id;

-- 7.3 Revenue by year (Rs crore) and orders
--     Observed: 2023 = 61.06 Cr | 2024 = 59.85 Cr | 2025 = 104.79 Cr
SELECT
    YEAR(o.order_date) AS yr,
    ROUND(SUM(oi.item_revenue) / 10000000, 2) AS revenue_cr,
    COUNT(DISTINCT o.order_id) AS orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status <> 'Cancelled'
GROUP BY YEAR(o.order_date);

-- 7.4 Monthly pattern in 2025 (revenue concentrated in Q4)
SELECT
    DATE_FORMAT(o.order_date, '%Y-%m') AS ym,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.item_revenue) / 10000000, 2) AS revenue_cr
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status <> 'Cancelled'
  AND o.order_date >= '2025-01-01'
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY ym;

-- 7.5 Delay flag agrees with the actual dates (within about 1 percentage point)
SELECT
    shipping_method,
    ROUND(100 * AVG(delayed_flag), 1) AS flagged_pct,
    ROUND(100 * AVG(actual_delivery_date > expected_delivery_date), 1) AS late_by_dates_pct
FROM shipments
GROUP BY shipping_method;
