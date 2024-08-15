# flink-mysql-starrocks

## Launch the environment

Docker Compose is used. These services are provided

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
docker compose exec MySQL mysql -uroot -p 123456 --prompt="MySQL > "
```

### PostgreSQL

Launch the PostgreSQL CLI in the container (you can use Dbeaver or other clients if you like) and run the SQL queries in the file `postgres.sql`

```bash
docker compose exec postgres psql -U postgres
```

## Flink SQL

Tables in Flink SQL are interfaces to tables in the source (MySQL and PostgreSQL) databases, and to the sink table in StarRocks.

Launch the Flink SQL client

```bash
docker compose run sql-client
```
### Source tables

Run the individual commands from the file flink-sql.sql. Only the first source is shown here:

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