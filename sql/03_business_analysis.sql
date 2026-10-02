-- Olist E-Commerce Analytics
-- 03_business_analysis_v2.sql
-- Updated business-focused SQL analysis using calendar-date delivery logic
-- MySQL 8+
--
-- IMPORTANT:
-- Delivery lateness is evaluated by CALENDAR DATE, not exact timestamp.
-- An order delivered on the estimated delivery date is treated as ON TIME.

USE olist_analytics;

-- 1. EXECUTIVE OVERVIEW
SELECT
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(oi.order_item_id) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_value,
    ROUND(AVG(oi.price), 2) AS avg_item_price
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- 2. MONTHLY SALES TREND + MONTH-OVER-MONTH GROWTH
WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS order_month,
        COUNT(DISTINCT o.order_id) AS orders,
        ROUND(SUM(oi.price), 2) AS product_revenue,
        ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
        ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_value
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
),
with_previous_month AS (
    SELECT
        *,
        LAG(total_order_value) OVER (ORDER BY order_month) AS previous_month_value
    FROM monthly_sales
)
SELECT
    order_month,
    orders,
    product_revenue,
    freight_revenue,
    total_order_value,
    ROUND(
        100 * (total_order_value - previous_month_value)
        / NULLIF(previous_month_value, 0),
        2
    ) AS mom_growth_pct
FROM with_previous_month
ORDER BY order_month;

-- 3. TOP PRODUCT CATEGORIES BY REVENUE
SELECT
    COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown') AS product_category,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT oi.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(AVG(oi.price), 2) AS avg_item_price
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown')
ORDER BY product_revenue DESC
LIMIT 20;

-- 4. CATEGORY REVENUE RANKING
WITH category_sales AS (
    SELECT
        COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown') AS product_category,
        ROUND(SUM(oi.price), 2) AS product_revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown')
)
SELECT
    product_category,
    product_revenue,
    DENSE_RANK() OVER (ORDER BY product_revenue DESC) AS revenue_rank
FROM category_sales
ORDER BY revenue_rank, product_category;

-- 5. CUSTOMER REPEAT-PURCHASE RATE
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_orders
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS customers,
    SUM(delivered_orders > 1) AS repeat_customers,
    ROUND(100 * SUM(delivered_orders > 1) / COUNT(*), 2) AS repeat_customer_pct,
    ROUND(AVG(delivered_orders), 2) AS avg_orders_per_customer,
    MAX(delivered_orders) AS max_orders_by_customer
FROM customer_orders;

-- 6. CUSTOMER GEOGRAPHY / STATE PERFORMANCE
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_order_value DESC;

-- 7. DELIVERY PERFORMANCE
SELECT
    COUNT(*) AS delivered_orders_with_date,
    SUM(
        DATE(order_delivered_customer_date) <= DATE(order_estimated_delivery_date)
    ) AS on_time_orders,
    SUM(
        DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)
    ) AS late_orders,
    ROUND(
        100 * SUM(
            DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date)
        ) / COUNT(*),
        2
    ) AS late_delivery_pct,
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                HOUR,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        ) / 24,
        2
    ) AS avg_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- 8. DELIVERY PERFORMANCE BY CUSTOMER STATE
SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders_with_date,
    SUM(
        DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
    ) AS late_orders,
    ROUND(
        100 * SUM(
            DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
        ) / COUNT(*),
        2
    ) AS late_delivery_pct,
    ROUND(
        AVG(
            TIMESTAMPDIFF(
                HOUR,
                o.order_purchase_timestamp,
                o.order_delivered_customer_date
            )
        ) / 24,
        2
    ) AS avg_delivery_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_delivery_pct DESC;

-- 9. DOES LATE DELIVERY AFFECT REVIEW SCORE?
SELECT
    CASE
        WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
            THEN 'Late'
        ELSE 'On time / early'
    END AS delivery_performance,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(r.review_score_mean), 2) AS avg_review_score,
    ROUND(AVG(r.review_score_min), 2) AS avg_min_review_score,
    ROUND(100 * SUM(r.review_score_mean <= 2) / COUNT(*), 2) AS low_review_pct
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY
    CASE
        WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
            THEN 'Late'
        ELSE 'On time / early'
    END;

-- 10. REVIEW SCORE BY DELIVERY DELAY BAND
WITH reviewed_deliveries AS (
    SELECT
        o.order_id,
        DATEDIFF(
            o.order_delivered_customer_date,
            o.order_estimated_delivery_date
        ) AS delay_days,
        r.review_score_mean
    FROM orders o
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    CASE
        WHEN delay_days <= -7 THEN '7+ days early'
        WHEN delay_days BETWEEN -6 AND -1 THEN '1-6 days early'
        WHEN delay_days = 0 THEN 'On estimated date'
        WHEN delay_days BETWEEN 1 AND 3 THEN '1-3 days late'
        WHEN delay_days BETWEEN 4 AND 7 THEN '4-7 days late'
        ELSE '8+ days late'
    END AS delivery_delay_band,
    COUNT(*) AS orders,
    ROUND(AVG(review_score_mean), 2) AS avg_review_score
FROM reviewed_deliveries
GROUP BY
    CASE
        WHEN delay_days <= -7 THEN '7+ days early'
        WHEN delay_days BETWEEN -6 AND -1 THEN '1-6 days early'
        WHEN delay_days = 0 THEN 'On estimated date'
        WHEN delay_days BETWEEN 1 AND 3 THEN '1-3 days late'
        WHEN delay_days BETWEEN 4 AND 7 THEN '4-7 days late'
        ELSE '8+ days late'
    END
ORDER BY MIN(delay_days);

-- 11. SELLER PERFORMANCE
WITH seller_order_performance AS (
    SELECT DISTINCT
        oi.seller_id,
        o.order_id,
        CASE
            WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
                THEN 1
            ELSE 0
        END AS late_order
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
seller_revenue AS (
    SELECT
        oi.seller_id,
        ROUND(SUM(oi.price), 2) AS product_revenue,
        ROUND(SUM(oi.freight_value), 2) AS freight_value,
        COUNT(*) AS items_sold
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)
SELECT
    s.seller_id,
    s.seller_state,
    sr.items_sold,
    sr.product_revenue,
    sr.freight_value,
    COUNT(sop.order_id) AS delivered_orders_with_date,
    ROUND(100 * AVG(sop.late_order), 2) AS late_delivery_pct
FROM sellers s
JOIN seller_revenue sr ON s.seller_id = sr.seller_id
LEFT JOIN seller_order_performance sop ON s.seller_id = sop.seller_id
GROUP BY
    s.seller_id,
    s.seller_state,
    sr.items_sold,
    sr.product_revenue,
    sr.freight_value
HAVING delivered_orders_with_date >= 10
ORDER BY product_revenue DESC
LIMIT 25;

-- 12. FREIGHT COST BY CATEGORY
SELECT
    COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown') AS product_category,
    COUNT(*) AS items_sold,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_value,
    ROUND(AVG(oi.price), 2) AS avg_item_price,
    ROUND(
        100 * SUM(oi.freight_value)
        / NULLIF(SUM(oi.price), 0),
        2
    ) AS freight_to_price_pct
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown')
HAVING COUNT(*) >= 50
ORDER BY freight_to_price_pct DESC;

-- 13. PAYMENT METHOD USAGE
SELECT
    payment_type,
    COUNT(*) AS payment_records,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS avg_payment_value,
    ROUND(AVG(payment_installments), 2) AS avg_installments
FROM payments
WHERE payment_metadata_anomaly = 0
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- 14. INSTALLMENT BEHAVIOUR FOR CREDIT CARDS
SELECT
    payment_installments,
    COUNT(*) AS payment_records,
    ROUND(AVG(payment_value), 2) AS avg_payment_value,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM payments
WHERE payment_type = 'credit_card'
  AND payment_installments > 0
GROUP BY payment_installments
ORDER BY payment_installments;

-- 15. TOP SELLERS WITH REVENUE RANK
WITH seller_sales AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        COUNT(DISTINCT oi.order_id) AS orders,
        ROUND(SUM(oi.price), 2) AS product_revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN sellers s ON oi.seller_id = s.seller_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, s.seller_state
)
SELECT
    seller_id,
    seller_state,
    orders,
    product_revenue,
    DENSE_RANK() OVER (ORDER BY product_revenue DESC) AS revenue_rank
FROM seller_sales
ORDER BY revenue_rank
LIMIT 25;

-- 16. YEARLY SUMMARY
SELECT
    YEAR(o.order_purchase_timestamp) AS order_year,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(oi.order_item_id) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY YEAR(o.order_purchase_timestamp)
ORDER BY order_year;
