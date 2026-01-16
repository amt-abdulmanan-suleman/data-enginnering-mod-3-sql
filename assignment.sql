-- Active: 1766944731416@@mysql-3099dfd3-sulemanabdulmanan-5813.i.aivencloud.com@22696
-- Products Table --
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    reorder_level INT DEFAULT 0
);

-- Customers Table --
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20)
);

-- Orders Table --
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2) DEFAULT 0,
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id) ON DELETE CASCADE
);
-- Order Details Table --
CREATE TABLE order_details (
    order_detail_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders (order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE
);

-- Inventory Logs Table --
CREATE TABLE inventory_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    change_type VARCHAR(50) NOT NULL, -- e.g., 'Order Placed', 'Restock'
    quantity_change INT NOT NULL,
    log_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products (product_id) ON DELETE CASCADE
);

-- Add a customer
INSERT INTO
    customers (customer_name, email, phone)
VALUES (
        'John Tagoe',
        'johnman@example.com',
        '1234567890'
    );

INSERT INTO
    products (
        product_name,
        category,
        price,
        stock_quantity,
        reorder_level
    )
VALUES (
        'Laptop Pro 15',
        'Electronics',
        1500.00,
        25,
        5
    ),
    (
        'Wireless Mouse',
        'Accessories',
        25.50,
        150,
        20
    ),
    (
        'Mechanical Keyboard',
        'Accessories',
        89.99,
        80,
        15
    ),
    (
        'Smartphone X',
        'Electronics',
        999.00,
        40,
        10
    ),
    (
        'Office Chair Deluxe',
        'Furniture',
        199.99,
        30,
        5
    );
-- Order Placement and Inventory Management --
BEGIN;
-- Create an order
INSERT INTO orders (customer_id, order_date) VALUES (1, NOW());

SET @last_order_id = LAST_INSERT_ID();

INSERT into
    order_details (
        order_id,
        product_id,
        quantity,
        price
    )
VALUES (@last_order_id, 1, 7, 70),
    (@last_order_id, 2, 8, 56);
-- Update stocks

UPDATE products
SET
    stock_quantity = stock_quantity - 7
WHERE
    product_id = 1;

UPDATE products
SET
    stock_quantity = stock_quantity - 8
WHERE
    product_id = 2;

-- Log Inventory
INSERT into
    inventory_logs (
        product_id,
        change_type,
        quantity_change
    )
VALUES (1, 'Order Placed', -7),
    (2, 'Order Placed', -8);

-- calculate and update total order amount
update orders
set
    total_amount = (
        select SUM(quantity * price)
        FROM order_details
        WHERE
            order_details.order_id = @last_order_id
    )
WHERE
    order_id = @last_order_id

COMMIT;

-- Monitoring and Reporting

-- Business insight and summary--
select
    c.customer_name,
    o.order_date,
    o.total_amount,
    count(od.order_detail_id) as total_items,
    sum(od.quantity) as total_quantities
from
    orders o
    join customers c on c.customer_id = o.customer_id
    join order_details od on od.order_id = o.order_id
GROUP BY
    c.customer_id,
    c.customer_name,
    o.order_id,
    o.order_date,
    o.total_amount
ORDER BY o.order_date DESC;

-- Low stock flagging--
SELECT
    product_id,
    product_name,
    category,
    stock_quantity,
    reorder_level,
    CASE
        WHEN stock_quantity < reorder_level THEN '⚠️ LOW – Reorder Needed'
        ELSE 'OK'
    END AS status
FROM products
WHERE
    stock_quantity < reorder_level
ORDER BY stock_quantity ASC;

SELECT
    c.customer_id,
    c.customer_name,
    c.email,
    ROUND(SUM(o.total_amount), 2) AS total_spent,
    CASE
        WHEN SUM(o.total_amount) >= 5000 THEN 'Gold'
        WHEN SUM(o.total_amount) >= 1000 THEN 'Silver'
        ELSE 'Bronze'
    END AS customer_tier
FROM customers c
    LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.email
ORDER BY total_spent DESC;
-- Or last inserted order
SET @product_id = 2;
-- The product customer ordered
-- The quantity ordered

-- CUSTOMER INSIGHTS--
START TRANSACTION;

-- Update existing order_details with bulk discount
UPDATE order_details od
JOIN products p ON p.product_id = od.product_id
SET
    od.price = p.price * CASE
        WHEN od.quantity >= 50 THEN 0.85
        WHEN od.quantity >= 20 THEN 0.90
        WHEN od.quantity >= 10 THEN 0.95
        ELSE 1
    END
WHERE
    od.order_id = @last_order_id;

-- Recalculate order total after discount
UPDATE orders
SET
    total_amount = (
        SELECT SUM(quantity * price)
        FROM order_details
        WHERE
            order_id = @last_order_id
    )
WHERE
    order_id = @last_order_id;

COMMIT;

--STOCK REPLENISHMENT--

SET @restock_extra = 50;

START TRANSACTION;

UPDATE products
SET
    stock_quantity = reorder_level + @restock_extra
WHERE
    stock_quantity < reorder_level;

INSERT INTO
    inventory_logs (
        product_id,
        change_type,
        quantity_change
    )
SELECT product_id, 'Replenishment', (
        reorder_level + @restock_extra - stock_quantity
    )
FROM products
WHERE
    stock_quantity = reorder_level + @restock_extra;

COMMIT;
--AUTOMATION PROCESS--
DELIMITER $$

CREATE TRIGGER trg_order_details_after_insert
AFTER INSERT ON order_details
FOR EACH ROW
BEGIN
    DECLARE discount_price DECIMAL(10,2);

    -- 1. Apply bulk discount based on quantity
    SET discount_price = NEW.quantity *
        CASE
            WHEN NEW.quantity >= 50 THEN NEW.price * 0.85
            WHEN NEW.quantity >= 20 THEN NEW.price * 0.90
            WHEN NEW.quantity >= 10 THEN NEW.price * 0.95
            ELSE NEW.price
        END;

    -- 2. Update the price in order_details
    UPDATE order_details
    SET price = discount_price / NEW.quantity
    WHERE order_detail_id = NEW.order_detail_id;

    -- 3. Reduce stock
    UPDATE products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;

    -- 4. Insert inventory log
    INSERT INTO inventory_logs (product_id, change_type, quantity_change)
    VALUES (NEW.product_id, 'Order Placed', -NEW.quantity);

    -- 5. Update order total
    UPDATE orders o
    SET total_amount = (
        SELECT SUM(quantity * price)
        FROM order_details
        WHERE order_id = o.order_id
    )
    WHERE o.order_id = NEW.order_id;

END$$

DELIMITER;
-- Enable event scheduler --
SET GLOBAL event_scheduler = ON;

DELIMITER $$

CREATE EVENT replenish_stock_daily
ON SCHEDULE EVERY 1 DAY
DO
BEGIN
    DECLARE restock_qty INT DEFAULT 50;

    -- 1. Update stock for low inventory
    UPDATE products
    SET stock_quantity = stock_quantity + restock_qty
    WHERE stock_quantity < reorder_level;

    -- 2. Insert logs for replenished stock
    INSERT INTO inventory_logs (product_id, change_type, quantity_change)
    SELECT product_id, 'Replenishment', restock_qty
    FROM products
    WHERE stock_quantity >= reorder_level
          AND stock_quantity - restock_qty < reorder_level;

END$$

DELIMITER;

--Update Customer Tiers Automatically--
DELIMITER $$

CREATE EVENT update_customer_tiers
ON SCHEDULE EVERY 1 WEEK
DO
BEGIN
    UPDATE customers c
    LEFT JOIN (
        SELECT customer_id, SUM(total_amount) AS total_spent
        FROM orders
        GROUP BY customer_id
    ) o_sum ON c.customer_id = o_sum.customer_id
    SET c.customer_tier = CASE
        WHEN IFNULL(o_sum.total_spent,0) >= 5000 THEN 'Gold'
        WHEN IFNULL(o_sum.total_spent,0) >= 1000 THEN 'Silver'
        ELSE 'Bronze'
    END;
END$$

DELIMITER;

--View: Summarize Orders--
CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    o.order_id,
    c.customer_name,
    o.order_date,
    o.total_amount,
    COUNT(od.order_detail_id) AS total_items,
    SUM(od.quantity) AS total_quantity
FROM
    orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_details od ON o.order_id = od.order_id
GROUP BY
    o.order_id,
    c.customer_name,
    o.order_date,
    o.total_amount
ORDER BY o.order_date DESC;

SELECT * FROM vw_order_summary;

-- View: Low Stock Products--
CREATE OR REPLACE VIEW vw_low_stock AS
SELECT
    product_id,
    product_name,
    category,
    stock_quantity,
    reorder_level,
    CASE
        WHEN stock_quantity < reorder_level THEN '⚠️ LOW – Reorder Needed'
        ELSE 'OK'
    END AS status
FROM products
WHERE
    stock_quantity < reorder_level
ORDER BY stock_quantity ASC;

SELECT * FROM vw_low_stock;

-- Place Order Procedure --
DELIMITER $$

CREATE PROCEDURE sp_place_order(
    IN p_customer_id INT,
    IN p_product_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE v_order_id INT;
    DECLARE v_price DECIMAL(10,2);

    START TRANSACTION;

    -- Create order
    INSERT INTO orders (customer_id)
    VALUES (p_customer_id);

    SET v_order_id = LAST_INSERT_ID();

    -- Get discounted price
    SELECT fn_discounted_price(price, p_quantity)
    INTO v_price
    FROM products
    WHERE product_id = p_product_id;

    -- Insert order details
    INSERT INTO order_details (order_id, product_id, quantity, price)
    VALUES (v_order_id, p_product_id, p_quantity, v_price);

    -- Reduce stock
    UPDATE products
    SET stock_quantity = stock_quantity - p_quantity
    WHERE product_id = p_product_id;

    -- Inventory log
    INSERT INTO inventory_logs (product_id, change_type, quantity_change)
    VALUES (p_product_id, 'Order Placed', -p_quantity);

    -- Update order total
    UPDATE orders
    SET total_amount = (
        SELECT SUM(quantity * price)
        FROM order_details
        WHERE order_id = v_order_id
    )
    WHERE order_id = v_order_id;

    COMMIT;
END$$

DELIMITER;

-- Customer Tier --
CREATE FUNCTION fn_customer_tier(total_spent DECIMAL(10,2))
RETURNS VARCHAR(10)
DETERMINISTIC
BEGIN
    RETURN CASE
        WHEN total_spent >= 5000 THEN 'Gold'
        WHEN total_spent >= 1000 THEN 'Silver'
        ELSE 'Bronze'
    END;
END$$

DELIMITER $$

-- Restock Inventory --
CREATE PROCEDURE sp_restock_inventory(
    IN p_extra_stock INT
)
BEGIN
    START TRANSACTION;

    UPDATE products
    SET stock_quantity = reorder_level + p_extra_stock
    WHERE stock_quantity < reorder_level;

    INSERT INTO inventory_logs (product_id, change_type, quantity_change)
    SELECT
        product_id,
        'Replenishment',
        reorder_level + p_extra_stock - stock_quantity
    FROM products
    WHERE stock_quantity = reorder_level + p_extra_stock;

    COMMIT;
END$$

DELIMITER;

DELIMITER $$

-- Discount calculation--
CREATE FUNCTION fn_discounted_price(
    base_price DECIMAL(10,2),
    qty INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN base_price * CASE
        WHEN qty >= 50 THEN 0.85
        WHEN qty >= 20 THEN 0.90
        WHEN qty >= 10 THEN 0.95
        ELSE 1
    END;
END$$

DELIMITER;