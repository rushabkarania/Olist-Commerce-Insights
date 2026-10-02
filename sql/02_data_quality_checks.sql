-- Olist E-Commerce Analytics
-- 02_data_quality_checks.sql
-- Final SQL validation after loading cleaned datasets

USE olist_analytics;

-- -----------------------------------------------------
-- 1. Row counts
-- -----------------------------------------------------
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'category_translation', COUNT(*) FROM category_translation
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews;

-- -----------------------------------------------------
-- 2. Primary-key / uniqueness checks
-- -----------------------------------------------------
SELECT
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_customer_ids
FROM customers;

SELECT
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_ids
FROM orders;

SELECT
    COUNT(*) - COUNT(DISTINCT product_id) AS duplicate_product_ids
FROM products;

SELECT
    COUNT(*) - COUNT(DISTINCT seller_id) AS duplicate_seller_ids
FROM sellers;

SELECT
    COUNT(*) - COUNT(DISTINCT geolocation_zip_code_prefix) AS duplicate_geo_zip_prefixes
FROM geolocation;

-- Composite key checks
SELECT
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '|', order_item_id))
        AS duplicate_order_item_keys
FROM order_items;

SELECT
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '|', payment_sequential))
        AS duplicate_payment_keys
FROM payments;

-- -----------------------------------------------------
-- 3. Referential-integrity checks
-- -----------------------------------------------------

-- Orders without valid customers
SELECT COUNT(*) AS orders_without_customer
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items without valid orders
SELECT COUNT(*) AS order_items_without_order
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items without valid products
SELECT COUNT(*) AS order_items_without_product
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Order items without valid sellers
SELECT COUNT(*) AS order_items_without_seller
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Payments without valid orders
SELECT COUNT(*) AS payments_without_order
FROM payments p
LEFT JOIN orders o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Reviews without valid orders
SELECT COUNT(*) AS reviews_without_order
FROM order_reviews r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- -----------------------------------------------------
-- 4. Known anomaly counts retained intentionally
-- -----------------------------------------------------

SELECT
    SUM(delivered_missing_delivery_date) AS delivered_missing_delivery_date,
    SUM(canceled_but_delivered) AS canceled_but_delivered,
    SUM(delivered_missing_approval) AS delivered_missing_approval
FROM orders;

SELECT
    SUM(payment_metadata_anomaly) AS payment_metadata_anomalies,
    SUM(zero_value_payment) AS zero_value_payments
FROM payments;

SELECT
    SUM(multiple_reviews) AS orders_with_multiple_reviews,
    SUM(conflicting_scores) AS orders_with_conflicting_review_scores
FROM order_reviews;

SELECT
    SUM(product_weight_g IS NULL) AS products_missing_weight,
    SUM(product_category_name = 'unknown') AS products_unknown_category
FROM products;

-- -----------------------------------------------------
-- 5. Missing geolocation coverage
-- -----------------------------------------------------

SELECT COUNT(*) AS customers_without_geo_match
FROM customers c
LEFT JOIN geolocation g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;

SELECT COUNT(*) AS sellers_without_geo_match
FROM sellers s
LEFT JOIN geolocation g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;

-- -----------------------------------------------------
-- 6. Orders without payment record
-- -----------------------------------------------------

SELECT COUNT(*) AS orders_without_payment
FROM orders o
LEFT JOIN payments p
    ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

-- -----------------------------------------------------
-- 7. Basic numeric sanity checks
-- -----------------------------------------------------

SELECT
    SUM(price <= 0) AS non_positive_prices,
    SUM(freight_value < 0) AS negative_freight_values
FROM order_items;

SELECT
    SUM(payment_value < 0) AS negative_payment_values,
    SUM(payment_installments < 0) AS negative_installments
FROM payments;

SELECT
    MIN(review_score_mean) AS min_review_score,
    MAX(review_score_mean) AS max_review_score
FROM order_reviews;
