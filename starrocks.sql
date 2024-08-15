CREATE DATABASE default_database;

USE default_database;

CREATE TABLE enriched_orders (
   order_id INT,
   order_date DATETIME,
   customer_name STRING,
   price DECIMAL(10, 5),
   product_id INT,
   order_status BOOLEAN,
   product_name STRING,
   product_description STRING,
   shipment_id INT,
   origin STRING,
   destination STRING,
   is_arrived BOOLEAN
  )
PRIMARY KEY (order_id)
DISTRIBUTED BY HASH (order_id)
;

