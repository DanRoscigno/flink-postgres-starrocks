FROM flink:1.18.1-scala_2.12-java8

RUN apt update
RUN apt install -y neovim

RUN wget -P /opt/flink/lib \
https://repo1.maven.org/maven2/com/ververica/flink-sql-connector-postgres-cdc/3.0.1/flink-sql-connector-postgres-cdc-3.0.1.jar

RUN wget -P /opt/flink/lib \
https://repo1.maven.org/maven2/com/starrocks/flink-connector-starrocks/1.2.9_flink-1.18/flink-connector-starrocks-1.2.9_flink-1.18.jar

RUN wget -P /opt/flink/lib \
https://repo1.maven.org/maven2/com/ververica/flink-sql-connector-mysql-cdc/3.0.1/flink-sql-connector-mysql-cdc-3.0.1.jar

RUN wget -P /opt/flink/lib \
https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.27/mysql-connector-java-8.0.27.jar

RUN wget -P /opt/flink \
https://dlcdn.apache.org/flink/flink-cdc-3.1.0/flink-cdc-3.1.0-bin.tar.gz

RUN cd /opt/flink && tar xzf flink-cdc-3.1.0-bin.tar.gz

RUN wget -P /opt/flink/flink-cdc-3.1.0/lib \
https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-pipeline-connector-starrocks/3.1.0/flink-cdc-pipeline-connector-starrocks-3.1.0.jar

RUN wget -P /opt/flink/flink-cdc-3.1.0/lib \
https://repo1.maven.org/maven2/org/apache/flink/flink-cdc-pipeline-connector-mysql/3.1.0/flink-cdc-pipeline-connector-mysql-3.1.0.jar

RUN echo "execution.checkpointing.interval: 3000" >> /opt/flink/conf/flink-conf.yaml
