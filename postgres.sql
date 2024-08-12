-- Most of this file is copied from the blog:
-- https://soumilshah1995.blogspot.com/2023/09/flink-change-data-capture-cdc-with.html


-- WAL level must be logical for CDC. The Docker Compose file starts PostgreSQL with wal_level set to logical.
SHOW wal_level;

-- Create a table named 'shipments' with the following columns:
CREATE TABLE shipments (
  shipment_id SERIAL NOT NULL PRIMARY KEY, -- Auto-incremented shipment ID, primary key
  order_id SERIAL NOT NULL, -- Auto-incremented order ID, not null
  origin VARCHAR(255) NOT NULL, -- Origin location, not null
  destination VARCHAR(255) NOT NULL, -- Destination location, not null
  is_arrived BOOLEAN NOT NULL -- Boolean indicating if the shipment has arrived, not null
);

-- Reset the sequence for the 'shipment_id' column to start from 1001
ALTER SEQUENCE public.shipments_shipment_id_seq RESTART WITH 1001;

-- Set the REPLICA IDENTITY for the 'shipments' table to FULL, which allows replica tables to store full row values.
ALTER TABLE public.shipments REPLICA IDENTITY FULL;

-- Insert three records into the 'shipments' table with default values for 'shipment_id', and specific values for other columns.
INSERT INTO shipments
VALUES (default, 10001, 'Beijing', 'Shanghai', false), -- Insert shipment from Beijing to Shanghai, not arrived
       (default, 10002, 'Hangzhou', 'Shanghai', false), -- Insert shipment from Hangzhou to Shanghai, not arrived
       (default, 10003, 'Shanghai', 'Hangzhou', false); -- Insert shipment from Shanghai to Hangzhou, not arrived

-- Verify
select * from shipments;

