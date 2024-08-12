# flink-postgres-starrocks

Experimenting with using Apache Flink to migrate tables from PostgreSQL to StarRocks.

The Docker Compose file will launch PostgreSQL and Flink. It also describes a Flink SQL service which can be launched with `docker compose run`.

PostgreSQL is configured with WAL set to `logical` as this is needed when using the `postgres-cdc` plugin.

The file `postgres.sql` contains DDL and DML to create and load a table in PostgreSQL.

The file `flink.sql` contains Flink SQL commands to create a Flink table associated with the PostgreSQL table.
