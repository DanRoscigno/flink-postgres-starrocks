# flink-mysql-starrocks

The following is a modification of the Flink CDC quick start at https://nightlies.apache.org/flink/flink-cdc-docs-release-3.1/docs/get-started/quickstart/mysql-to-starrocks/ . Rather than install Flink locally I added Flink containers to the existing tutorial.

<!--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
-->

# Streaming ELT from MySQL to StarRocks

This tutorial is to show how to quickly build a Streaming ELT job from MySQL to StarRocks using Flink CDC, including the
feature of sync all table of one database, schema change evolution and sync sharding tables into one table.  
All exercises in this tutorial are performed in the Flink CDC CLI, and the entire process uses standard SQL syntax,
without a single line of Java/Scala code or IDE installation.

## Preparation
Prepare a Linux or MacOS computer with Docker installed.

### Flink, MySQL, and StarRocks are all deployed in Docker

1. Deploy with Docker Compose

> Note
>
> I have the --wait in the compose line in anticipation of adding healthchecks, this needs to be done.

   ```shell
   docker compose build
   docker compose up --detach --wait --wait-timeout 120
   ```

2. Have a look at the Flink setup

  - Look at the `flink.Dockerfile` and see that there are jar files downloaded and placed into `$FLINK_HOME/lib` and others placed into `$FLINK_HOME/cdc/lib`. It is important that these jar files get placed into the correct dir. Having a jar file in the wrong place could cause Flink to fail with error messages that are not clear.

  - Also in the `flink.Dockerfile` see that checkpointing is enabled by appending the following parameter to the conf/flink-conf.yaml configuration file. Checkpointing will happen every 3 seconds.

   ```yaml
   execution.checkpointing.interval: 3000
   ```

3. Open the Flink Web UI

If successfully started, you can access the Flink Web UI at [http://localhost:8081/](http://localhost:8081/).

### Examine the configs for MySQL and StarRocks

The MySQL and StarRocks configs are in `docker-compose.yaml`.

  - MySQL hostname, username, and password are in the Compose file:
  > Note:
  >
  > From a Docker perspective, the hostname of the MySQL service is the service name, which is `MySQL`. When accessing the MySQL service from within the Docker environment, use `MySQL` and port `3306`. When accessing the MySQL service from the Docker host (for example, your laptop) use `localhost` and port `3306`.
  >
  > The `root` password is `123456`. I am not sure if the non-root `mysqluser` is ever used. I have not used it yet.

  ```yaml
    MySQL:
    image: debezium/example-mysql:2.1
    ports:
      - "3306:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=123456
      - MYSQL_USER=mysqluser
      - MYSQL_PASSWORD=mysqlpw
  ```

  - StarRocks allin1 is used. I am not a fan, as this is not a "real" StarRocks deployment. I will probably change this to 2 FEs and 3 BEs. For now, the service name is `StarRocks`, and so from within Docker the hostname is `StarRocks` and the ports are `9030` and `8080`.

  ```yaml
    StarRocks:
    image: starrocks/allin1-ubuntu:3.2.6
    ports:
      - "8080:8080"
      - "9030:9030"
  ```

  - SQL Client

  This is probably not used, I should remove it and see.

  - jobmanager

  > Note
  >
  > `jobmanager` uses the Docker image built based on the `flink.Dockerfile`. The compose file exposes port 8081 for the Flink Web UI and mounts `mysql-to-starrocks.yaml` in the running `jobmanager` service. The `rpc.address` setting is used for communication between `jobmanager` and `taskmanager`.

  ```yaml
    jobmanager:
    image: starrocks/flink
    build:
      dockerfile: ./flink.Dockerfile
    ports:
      - "8081:8081"
    volumes:
      - ./mysql-to-starrocks.yaml:/opt/flink/flink-cdc-3.1.0/mysql-to-starrocks.yaml
    command: jobmanager
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
  ```

  - taskmanager

  > Note
  >
  > `taskmanager` uses the same Docker image as `jobmanager`. based on the `flink.Dockerfile`. No ports are exposed as the taskmanager only needs access within the Docker environment. The `rpc.address` setting is used for communication between `jobmanager` and `taskmanager`. `taskmanager.numberOfTaskSlots` is set to `2` to allow the `taskmanager` to accept two tasks/pipelines instead of the default, which is one.

  ```yaml
    taskmanager:
    image: starrocks/flink
    build:
      dockerfile: ./flink.Dockerfile
    depends_on:
      - jobmanager
    command: taskmanager
    scale: 1
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        taskmanager.numberOfTaskSlots: 2
  ```

#### Prepare records for MySQL
1. Enter MySQL container

   ```shell
   docker-compose exec MySQL mysql -uroot -p123456
   ```

2. create `app_db` database and `orders`,`products`,`shipments` tables, then insert records

    ```sql
    -- create database
    CREATE DATABASE app_db;
   
    USE app_db;
   
   -- create orders table
   CREATE TABLE `orders` (
   `id` INT NOT NULL,
   `price` DECIMAL(10,2) NOT NULL,
   PRIMARY KEY (`id`)
   );
   
   -- insert records
   INSERT INTO `orders` (`id`, `price`) VALUES (1, 4.00);
   INSERT INTO `orders` (`id`, `price`) VALUES (2, 100.00);
   
   -- create shipments table
   CREATE TABLE `shipments` (
   `id` INT NOT NULL,
   `city` VARCHAR(255) NOT NULL,
   PRIMARY KEY (`id`)
   );
   
   -- insert records
   INSERT INTO `shipments` (`id`, `city`) VALUES (1, 'beijing');
   INSERT INTO `shipments` (`id`, `city`) VALUES (2, 'xian');
   
   -- create products table
   CREATE TABLE `products` (
   `id` INT NOT NULL,
   `product` VARCHAR(255) NOT NULL,
   PRIMARY KEY (`id`)
   );
   
   -- insert records
   INSERT INTO `products` (`id`, `product`) VALUES (1, 'Beer');
   INSERT INTO `products` (`id`, `product`) VALUES (2, 'Cap');
   INSERT INTO `products` (`id`, `product`) VALUES (3, 'Peanut');
    ```

## Submit job with Flink CDC CLI

1. Flink CDC CLI is installed in the Flink Image. These lines from `flink.Dockerfile` download Flink CDC CLI, unpack it, and add the StarRocks and MySQL connectors to the `flink-cdc-3.1.0/lib` folder:

  ```bash
  RUN wget -P /opt/flink \
  https://dlcdn.apache.org/flink/flink-cdc-3.1.0/flink-cdc-3.1.0-bin.tar.gz

  RUN cd /opt/flink && tar xzf flink-cdc-3.1.0-bin.tar.gz

  RUN wget -P /opt/flink/flink-cdc-3.1.0/lib \
  https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-pipeline-connector-starrocks/3.1.0/flink-cdc-pipeline-connector-starrocks-3.1.0.jar
  
  RUN wget -P /opt/flink/flink-cdc-3.1.0/lib \
  https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-pipeline-connector-mysql/3.1.0/flink-cdc-pipeline-connector-mysql-3.1.0.jar
  ```

   The `flink-cdc-3.1.0` directory will contain four directories: `bin`, `lib`, `log`, and `conf`.

   The compose file mounts the file `mysql-to-starrocks.yaml` in the `flink-cdc-3.1.0` folder.

3. Write task configuration yaml file.
   Here is an example file for synchronizing the entire database `mysql-to-starrocks.yaml`：

   > Note:
   >
   > The following YAML file is already mounted in the `flink-cdc-3.1.0` folder on the `jobmanager` service. and the hostnames are set to match the service names in the compose file (by default, Docker hostnames are set the service name of the services). Additionally, the usernames and passwords are set based on the usernames and passwords set in the compose file.

   ```yaml
   ################################################################################
   # Description: Sync MySQL all tables to StarRocks
   ################################################################################
   source:
     type: mysql
     hostname: MySQL
     port: 3306
     username: root
     password: 123456
     tables: app_db.\.*
     server-id: 5400-5404
     server-time-zone: UTC

   sink:
     type: starrocks
     name: StarRocks Sink
     jdbc-url: jdbc:mysql://StarRocks:9030
     load-url: StarRocks:8080
     username: root
     password: ""
     table.create.properties.replication_num: 1

   pipeline:
     name: Sync MySQL Database to StarRocks
     parallelism: 2
   ```

Notice that:  
* `tables: app_db.\.*` in the source causes all tables in the database `app_db` to be synchronized to the sink through Regular Expression Matching.   
* `table.create.properties.replication_num` in the sink is set to `1` because there is only one StarRocks BE node in the allin1 Docker image.

4. Finally, submit job to Flink Standalone cluster using Cli.

   ```shell
   bash bin/flink-cdc.sh mysql-to-starrocks.yaml
   ```
   
After a successful submission, the output is similar to:

   ```shell
   Pipeline has been submitted to cluster.
   Job ID: 02a31c92f0e7bc9a1f4c0051980088a0
   Job Description: Sync MySQL Database to StarRocks
   ```

We can find a job  named `Sync MySQL Database to StarRocks` is running through Flink Web UI.

Connect to StarRocks with a SQL client such as DBeaver using `mysql://127.0.0.1:9030`. You can view the data written to three tables in StarRocks.

### Synchronize Schema and Data changes

CDC is a continuous process, as changes are made to the source data, the changes are propagated to the sink.

Enter MySQL container

 ```shell
 docker-compose exec MySQL mysql -uroot -p123456
 ```

Modify the schema and records in MySQL, and the tables in StarRocks will reflect the same changes in real time：

1. insert one record in `orders` from MySQL:

   ```sql
   INSERT INTO app_db.orders (id, price) VALUES (3, 100.00);
   ```

2. add one column in `orders` from MySQL:

   ```sql
   ALTER TABLE app_db.orders ADD amount varchar(100) NULL;
   ```   

3. update one record in `orders` from MySQL:

   ```sql
   UPDATE app_db.orders SET price=100.00, amount=100.00 WHERE id=1;
   ```
4. delete one record in `orders` from MySQL:

   ```sql
   DELETE FROM app_db.orders WHERE id=2;
   ```

Re-run the SQL queries in the StarRocks SQL client (DBeaver if you used that) every time you execute a step, and you can see that the `orders` table displayed in StarRocks will be updated in real-time, like the following：

Similarly, by modifying the `shipments` and `products` tables, you can also see the results of synchronized changes in real-time in StarRocks.

## Clean up
After finishing the tutorial, run the following command to stop all containers in the directory of `docker-compose.yml`:

   ```shell
   docker-compose down -v
   ```
