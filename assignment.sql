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
-- Order Placement and Inventory Management --
BEGIN;
-- Create an order
INSERT INTO orders (customer_id, order_date) VALUES (7, NOW());

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