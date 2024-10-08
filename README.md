# flink-mysql-starrocks

Based on the Ververica blog [Build Streaming ETL for MySQL and Postgres based on Flink CDC](https://www.ververica.com/blog/how-to-guide-build-streaming-etl-for-mysql-and-postgres-based-on-flink-cdc).

## Launch the environment

Docker Compose is used.

```bash
docker compose up --detach --wait --wait-timeout 120
```

These services are provided:

```bash
docker compose ps --format json | \
jq '{Service: .Service, State: .State, Status: .Status}'
```

```json
{
  "Service": "MySQL",
  "State": "running",
  "Status": "Up About an hour"
}
{
  "Service": "StarRocks",
  "State": "running",
  "Status": "Up About an hour"
}
{
  "Service": "jobmanager",
  "State": "running",
  "Status": "Up About an hour"
}
{
  "Service": "postgres",
  "State": "running",
  "Status": "Up About an hour"
}
{
  "Service": "taskmanager",
  "State": "running",
  "Status": "Up About an hour"
}
```

Additionally, a service that is not auto-started is provided to run the Flink SQL client.

## Source databases

### MySQL

Launch the MySQL CLI in the container (you can use Dbeaver or other clients if you like) and run the SQL queries in the file `mysql.sql`

```bash
docker compose exec MySQL mysql -uroot -p123456 --prompt="MySQL > "
```

### PostgreSQL

Launch the PostgreSQL CLI in the container (you can use Dbeaver or other clients if you like) and run the SQL queries in the file `postgres.sql`

```bash
docker compose exec postgres psql -U postgres
```

## Destination database

StarRocks is the destination. Connect with the MySQL CLI and run the queries in `starrocks.sql`

```bash
docker compose exec StarRocks mysql -uroot \
  -hStarRocks -P9030 --prompt="StarRocks > "
```
## Flink SQL

Tables in Flink SQL are interfaces to tables in the source (MySQL and PostgreSQL) databases, and to the sink table in StarRocks.

Launch the Flink SQL client

```bash
docker compose run sql-client
```
### Source tables

Run the individual commands from the file `flink-sql.sql`. Only the first source is shown here:

```sql
CREATE TABLE products (
    id INT,
    name STRING,
    description STRING,
    PRIMARY KEY (id) NOT ENFORCED
  ) WITH (
    'connector' = 'mysql-cdc',
    'hostname' = 'MySQL',
    'port' = '3306',
    'username' = 'root',
    'password' = '123456',
    'database-name' = 'mydb',
    'table-name' = 'products'
  );
```

Note the entries in the `WITH` section above.

- `connector` specifies the class to use to connect to the database that contains the data
- `hostname`: the hostname (because this is a Docker Compose environment, the hostname is set to the service name specified in the compose file by default)
- The rest of the properties specify the port, authentication, database name, and table name.

## Sink (destination) tables

```sql
CREATE TABLE enriched_orders (
   order_id INT,
   order_date TIMESTAMP(0),
   customer_name STRING,
   price DECIMAL(10, 5),
   product_id INT,
   order_status BOOLEAN,
   product_name STRING,
   product_description STRING,
   shipment_id INT,
   origin STRING,
   destination STRING,
   is_arrived BOOLEAN,
   PRIMARY KEY (order_id) NOT ENFORCED
 ) WITH (
    'connector' = 'starrocks',
    'jdbc-url' = 'jdbc:mysql://StarRocks:9030/',
    'load-url' = 'http://StarRocks:8080',
    'database-name' = 'default_database',
    'table-name' = 'enriched_orders',
    'username' = 'root',
    'password' = ''
 );
```

## Flink Web UI

http://localhost:8081/#/job/running

> Note:
>
> CDC jobs run continuously, so the job will not move from the RUNNING to COMPLETE state.

```bash
mysql -P9030 -h 127.0.0.1 -u root --prompt="StarRocks > "
```

```sql
use default_database;
select * from enriched_orders\G
```

```sql
*************************** 1. row ***************************
           order_id: 10001
         order_date: 2020-07-30 10:08:22
      customer_name: Jark
              price: 50.50000
         product_id: 102
       order_status: 0
       product_name: car battery
product_description: 12V car battery
        shipment_id: 1001
             origin: Beijing
        destination: Shanghai
         is_arrived: 0
*************************** 2. row ***************************
           order_id: 10002
         order_date: 2020-07-30 10:11:09
      customer_name: Sally
              price: 15.00000
         product_id: 105
       order_status: 0
       product_name: hammer
product_description: 14oz carpenter's hammer
        shipment_id: 1002
             origin: Hangzhou
        destination: Shanghai
         is_arrived: 0
*************************** 3. row ***************************
           order_id: 10003
         order_date: 2020-07-30 12:00:30
      customer_name: Edward
              price: 25.25000
         product_id: 106
       order_status: 0
       product_name: hammer
product_description: 16oz carpenter's hammer
        shipment_id: 1003
             origin: Shanghai
        destination: Hangzhou
         is_arrived: 0
3 rows in set (0.03 sec)
```

## Update the source data

Next, modify the data in the tables in the MySQL and Postgres databases and the orders data displayed in Kibana will also be updated in real time.

Insert a data into a MySQL `orders` table

```sql
USE mydb;

INSERT INTO orders
VALUES (default, '2020-07-30 15:22:00', 'Jark', 29.71, 104, false);
```

Update the status of an order in the MySQL orders table

```sql
USE mydb;

UPDATE orders SET order_status = true WHERE order_id = 10004;
```

Insert a data into the Postgres shipments table

```sql
INSERT INTO shipments
VALUES (default,10004,'Shanghai','Beijing',false);
```

Update the status of a shipment in the Postgres shipments table

```sql
UPDATE shipments SET is_arrived = true WHERE shipment_id = 1004;
```

Delete data in the MYSQL orders table.

```sql
DELETE FROM orders WHERE order_id = 10004;
```

## Verify that the data is updated in StarRocks

## Cleanup

```bash
docker compose down -v
```
