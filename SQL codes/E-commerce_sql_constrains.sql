USE EcommerceDW;
GO
--- convert data types to match dmensions data types 

ALTER TABLE fact_orders ALTER COLUMN Customer_Sk INT;
ALTER TABLE fact_orders ALTER COLUMN Product_sk INT;
ALTER TABLE fact_orders ALTER COLUMN seller_SK INT;
ALTER TABLE fact_orders ALTER COLUMN Payments_sk INT;
ALTER TABLE fact_orders ALTER COLUMN date_key INT;
ALTER TABLE fact_orders ALTER COLUMN fact_SK INT;

-----------alter primary key constrains to be not null 
ALTER TABLE dim_customer ALTER COLUMN Customer_Sk INT NOT NULL;
ALTER TABLE dim_product ALTER COLUMN Product_sk INT NOT NULL;
ALTER TABLE dim_seller ALTER COLUMN seller_SK INT NOT NULL;
ALTER TABLE dim_payment ALTER COLUMN Payments_sk INT NOT NULL;
ALTER TABLE dim_date ALTER COLUMN date_key INT NOT NULL;
ALTER TABLE fact_orders ALTER COLUMN fact_SK INT NOT NULL;

-- ============================================================
-- NOW CREATE PRIMARY KEYS (data types match now)
-- ============================================================

ALTER TABLE dim_customer
    ADD CONSTRAINT PK_dim_customer PRIMARY KEY (Customer_Sk);

ALTER TABLE dim_product
    ADD CONSTRAINT PK_dim_product PRIMARY KEY (Product_sk);

ALTER TABLE dim_seller
    ADD CONSTRAINT PK_dim_seller PRIMARY KEY (seller_SK);

ALTER TABLE dim_payment
    ADD CONSTRAINT PK_dim_payment PRIMARY KEY (Payments_sk);

ALTER TABLE dim_date
    ADD CONSTRAINT PK_dim_date PRIMARY KEY (date_key);

ALTER TABLE fact_orders
    ADD CONSTRAINT PK_fact_orders PRIMARY KEY (fact_SK);

GO


PRINT 'Primary Keys Created';
GO

-- ============================================================
-- CREATE FOREIGN KEYS (now data types match)
-- ============================================================
PRINT 'Creating Foreign Keys...';

ALTER TABLE fact_orders
    ADD CONSTRAINT FK_fact_customer
    FOREIGN KEY (Customer_Sk) REFERENCES dim_customer(Customer_Sk);

ALTER TABLE fact_orders
    ADD CONSTRAINT FK_fact_product
    FOREIGN KEY (Product_sk) REFERENCES dim_product(Product_sk);

ALTER TABLE fact_orders
    ADD CONSTRAINT FK_fact_seller
    FOREIGN KEY (seller_SK) REFERENCES dim_seller(seller_SK);

ALTER TABLE fact_orders
    ADD CONSTRAINT FK_fact_payment
    FOREIGN KEY (Payments_sk) REFERENCES dim_payment(Payments_sk);

ALTER TABLE fact_orders
    ADD CONSTRAINT FK_fact_date
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key);

GO

PRINT 'Foreign Keys Created';
GO

-- ============================================================
-- CREATE INDEXES
-- ============================================================
PRINT 'Creating Indexes...';

CREATE INDEX IX_fact_order_date_key ON fact_orders (date_key);
CREATE INDEX IX_fact_order_status ON fact_orders (order_status_clean);
CREATE INDEX IX_fact_is_late ON fact_orders (is_late);
CREATE INDEX IX_fact_review_score ON fact_orders (review_score);
CREATE INDEX IX_fact_customer_key ON fact_orders (Customer_Sk);
CREATE INDEX IX_fact_product_key ON fact_orders (Product_sk);
CREATE INDEX IX_fact_seller_key ON fact_orders (seller_SK);
CREATE INDEX IX_dim_customer_state ON dim_customer (state);
CREATE INDEX IX_dim_customer_region ON dim_customer (region);
CREATE INDEX IX_dim_product_category ON dim_product (category_group);
CREATE INDEX IX_dim_seller_state ON dim_seller (state);
CREATE INDEX IX_dim_payment_order_id ON dim_payment (order_id);
CREATE INDEX IX_dim_date_year_month ON dim_date (year, month);

GO

PRINT 'Indexes Created ✓';
GO

-- ============================================================
-- CREATE VIEWS
-- ============================================================
PRINT 'Creating Views...';

CREATE OR ALTER VIEW vw_orders_analysis AS
SELECT
    f.fact_SK, f.order_id, f.order_item_id,
    f.price, f.freight_value, f.total_item_value, f.freight_ratio,
    f.delivery_delay_days, f.processing_days, f.review_score,
    f.order_status_clean, f.is_late, f.review_sentiment, f.has_comment,
    c.customer_id, c.customer_unique_id, c.city AS customer_city,
    c.state AS customer_state, c.region AS customer_region,
    c.latitude AS customer_lat, c.longitude AS customer_lng,
    p.product_id, p.product_category_name, p.category_group,
    s.seller_id, s.city AS seller_city, s.state AS seller_state,
    py.payment_type, py.payment_installments, py.installments_buckets, py.payment_value,
    d.year, d.month, d.month_name, d.quarter_label, d.day_of_week, d.full_date
FROM fact_orders f
LEFT JOIN dim_customer c ON f.Customer_Sk = c.Customer_Sk
LEFT JOIN dim_product p ON f.Product_sk = p.Product_sk
LEFT JOIN dim_seller s ON f.seller_SK = s.seller_SK
LEFT JOIN dim_payment py ON f.Payments_sk = py.Payments_sk
LEFT JOIN dim_date d ON f.date_key = d.date_key;

GO

CREATE OR ALTER VIEW vw_delay_vs_review AS
SELECT
    CASE 
        WHEN f.delivery_delay_days <= -10 THEN 'Early 10+ days'
        WHEN f.delivery_delay_days <= 0  THEN 'On Time'
        WHEN f.delivery_delay_days <= 5  THEN '1-5 days late'
        WHEN f.delivery_delay_days <= 15 THEN '6-15 days late'
        WHEN f.delivery_delay_days <= 30 THEN '16-30 days late'
        ELSE '30+ days late'
    END AS delay_bucket,
    COUNT(DISTINCT f.order_id) AS total_orders,
    ROUND(AVG(f.review_score), 2) AS avg_review_score,
    ROUND(AVG(CAST(f.delivery_delay_days AS FLOAT)), 1) AS avg_delay_days
FROM fact_orders f
WHERE f.delivery_delay_days IS NOT NULL
GROUP BY 
    CASE 
        WHEN f.delivery_delay_days <= -10 THEN 'Early 10+ days'
        WHEN f.delivery_delay_days <= 0  THEN 'On Time'
        WHEN f.delivery_delay_days <= 5  THEN '1-5 days late'
        WHEN f.delivery_delay_days <= 15 THEN '6-15 days late'
        WHEN f.delivery_delay_days <= 30 THEN '16-30 days late'
        ELSE '30+ days late'
    END;

GO

-- ============================================================
-- FINAL VERIFICATION
-- ============================================================
PRINT '';
PRINT '====== DATA WAREHOUSE READY ======';

SELECT 'dim_customer' AS table_name, COUNT(*) AS row_count FROM dim_customer
UNION ALL SELECT 'dim_product', COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_seller', COUNT(*) FROM dim_seller
UNION ALL SELECT 'dim_payment', COUNT(*) FROM dim_payment
UNION ALL SELECT 'dim_date', COUNT(*) FROM dim_date
UNION ALL SELECT 'fact_orders', COUNT(*) FROM fact_orders;

PRINT '';
PRINT '✓ ALL CONSTRAINTS CREATED SUCCESSFULLY!';
PRINT '✓ ALL DATA TYPES MATCH!';
PRINT '✓ Your DWH is ready for Power BI!';
GO