# flink-mysql-starrocks

- the Dockerfile sets up the Flink containers
- the compose file deploys mysql, starrocks, and a Flink cluster
- there is a SQL file to create the MySQL DB and table, and load some rows.
- there is a config file for CDC in /opt/flink/flinkcdc (I don't remember the details, but in the quick start linked below there is a step where you run the job, use the file I put in the opt/flink/flickcdc-something-or-other file)

Use the quick start at https://nightlies.apache.org/flink/flink-cdc-docs-release-3.1/docs/get-started/quickstart/mysql-to-starrocks/

