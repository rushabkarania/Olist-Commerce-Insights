-- Olist E-Commerce Analytics
-- 02_load_data.sql
-- Loads the cleaned CSV files from data/processed into MySQL.
--
-- IMPORTANT:
-- Start the MySQL client with local infile enabled:
-- mysql --local-infile=1 -u root -p
--
-- This script assumes the project is located at:
-- C:/path/to/Olist-Commerce-Analytics/
--
-- If you move the project, update the file paths below.

USE olist_analytics;

SET SESSION local_infile = 1;

-- -----------------------------------------------------
-- Optional: clear tables before reloading
-- Child tables first because of foreign keys
-- -----------------------------------------------------
DELETE FROM order_reviews;
DELETE FROM payments;
DELETE FROM order_items;
DELETE FROM orders;
DELETE FROM geolocation;
DELETE FROM category_translation;
DELETE FROM sellers;
DELETE FROM products;
DELETE FROM customers;

-- -----------------------------------------------------
-- 1. Customers
-- -----------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/path/to/Olist-Commerce-Analytics/data/processed/customers_clean.csv'
INTO TABLE customers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
);

-- -----------------------------------------------------
-- 2. Products
-- -----------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/path/to/Olist-Commerce-Analytics/data/processed/products_clean.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    product_id,
    product_category_name,
    @product_name_length,
    @product_description_length,
    @product_photos_qty,
    @product_weight_g,
    @product_length_cm,
    @product_height_cm,
    @product_width_cm
)
SET
    product_name_length = NULLIF(@product_name_length, ''),
    product_description_length = NULLIF(@product_description_length, ''),
    product_photos_qty = NULLIF(@product_photos_qty, ''),
    product_weight_g = NULLIF(@product_weight_g, ''),
    product_length_cm = NULLIF(@product_length_cm, ''),
    product_height_cm = NULLIF(@product_height_cm, ''),
    product_width_cm = NULLIF(@product_width_cm, '');

-- -----------------------------------------------------
-- 3. Sellers
-- -----------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/path/to/Olist-Commerce-Analytics/data/processed/sellers_clean.csv'
INTO TABLE sellers
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
);

-- -----------------------------------------------------
-- 4. Category Translation
-- -----------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/path/to/Olist-Commerce-Analytics/data/processed/category_translation_clean.csv'
INTO TABLE category_translation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    product_category_name,
    product_category_name_english
);

-- -----------------------------------------------------
-- 5. Geolocation
-- -----------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/path/to/Olist-Commerce-Analytics/data/processed/geolocation_zip_clean.csv'
INTO TABLE geolocation
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng
);

-- -----------------------------------------------------
-- 6. Orders
-- -----------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/path/to/Olist-Commerce-Analytics/data/processed/orders_clean.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    customer_id,
    order_status,
    @order_purchase_timestamp,
    @order_approved_at,
    @order_delivered_carrier_date,
    @order_delivered_customer_date,
    @order_estimated_delivery_date,
    @delivered_missing_delivery_date,
    @canceled_but_delivered,
    @delivered_missing_approval
)
SET
    order_purchase_timestamp =
        NULLIF(@order_purchase_timestamp, ''),
    order_approved_at =
        NULLIF(@order_approved_at, ''),
    order_delivered_carrier_date =
        NULLIF(@order_delivered_carrier_date, ''),
    order_delivered_customer_date =
        NULLIF(@order_delivered_customer_date, ''),
    order_estimated_delivery_date =
        NULLIF(@order_estimated_delivery_date, ''),
    delivered_missing_delivery_date =
        CASE
            WHEN LOWER(@delivered_missing_delivery_date) IN ('true', '1') THEN 1
            ELSE 0
        END,
    canceled_but_delivered =
        CASE
            WHEN LOWER(@canceled_but_delivered) IN ('true', '1') THEN 1
            ELSE 0
        END,
    delivered_missing_approval =
        CASE
            WHEN LOWER(@delivered_missing_approval) IN ('true', '1') THEN 1
            ELSE 0
        END;

-- -----------------------------------------------------
-- 7. Order Items
-- -----------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/path/to/Olist-Commerce-Analytics/data/processed/order_items_clean.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    @shipping_limit_date,
    price,
    freight_value
)
SET
    shipping_limit_date = NULLIF(@shipping_limit_date, '');

-- -----------------------------------------------------
-- 8. Payments
-- -----------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/path/to/Olist-Commerce-Analytics/data/processed/payments_clean.csv'
INTO TABLE payments
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value,
    @payment_metadata_anomaly,
    @zero_value_payment
)
SET
    payment_metadata_anomaly =
        CASE
            WHEN LOWER(@payment_metadata_anomaly) IN ('true', '1') THEN 1
            ELSE 0
        END,
    zero_value_payment =
        CASE
            WHEN LOWER(@zero_value_payment) IN ('true', '1') THEN 1
            ELSE 0
        END;

-- -----------------------------------------------------
-- 9. Order-level Reviews
-- -----------------------------------------------------
LOAD DATA LOCAL INFILE
'C:/path/to/Olist-Commerce-Analytics/data/processed/reviews_order_clean.csv'
INTO TABLE order_reviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    review_count,
    review_score_mean,
    review_score_min,
    review_score_max,
    @multiple_reviews,
    @conflicting_scores
)
SET
    multiple_reviews =
        CASE
            WHEN LOWER(@multiple_reviews) IN ('true', '1') THEN 1
            ELSE 0
        END,
    conflicting_scores =
        CASE
            WHEN LOWER(@conflicting_scores) IN ('true', '1') THEN 1
            ELSE 0
        END;

-- -----------------------------------------------------
-- Quick row-count verification
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
