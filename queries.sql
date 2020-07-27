CREATE SOURCE CONNECTOR mysql_source_connector WITH (
'connector.class'='io.debezium.connector.mysql.MySqlConnector',
'database.hostname'='mysql',
'database.port'='3306',
'database.user'='mysqluser',
'database.password'='mysqlpw',
'database.server.id'='12345',
'database.server.name'='dc',
'database.whitelist'='orders',
'table.blacklist'='orders.dc_out_of_stock_events',
'database.history.kafka.bootstrap.servers'='broker:29092',
'database.history.kafka.topic'='debezium_dbhistory',
'include.schema.changes'='false',
'snapshot.mode'='when_needed',
'transforms'='unwrap,sourcedc,TopicRename,extractKey',
'transforms.unwrap.type'='io.debezium.transforms.UnwrapFromEnvelope',
'transforms.sourcedc.type'='org.apache.kafka.connect.transforms.InsertField$Value',
'transforms.sourcedc.static.field'='sourcedc',
'transforms.sourcedc.static.value'='dc',
'transforms.TopicRename.type'='org.apache.kafka.connect.transforms.RegexRouter',
'transforms.TopicRename.regex'='(.*)\\.(.*)\\.(.*)',
'transforms.TopicRename.replacement'='$1_$3',
'transforms.extractKey.type'='org.apache.kafka.connect.transforms.ExtractField$Key',
'transforms.extractKey.field'='id',
'key.converter'='org.apache.kafka.connect.converters.IntegerConverter'
);

CREATE STREAM sales_orders WITH (KAFKA_TOPIC='dc_sales_orders', VALUE_FORMAT='AVRO');
CREATE STREAM sales_order_details WITH (KAFKA_TOPIC='dc_sales_order_details', VALUE_FORMAT='AVRO');
CREATE STREAM purchase_orders WITH (KAFKA_TOPIC='dc_purchase_orders', VALUE_FORMAT='AVRO');
CREATE STREAM purchase_order_details WITH (KAFKA_TOPIC='dc_purchase_order_details', VALUE_FORMAT='AVRO');
CREATE STREAM products WITH (KAFKA_TOPIC='dc_products', VALUE_FORMAT='AVRO');
CREATE STREAM customers WITH (KAFKA_TOPIC='dc_customers', VALUE_FORMAT='AVRO');
CREATE STREAM suppliers WITH (KAFKA_TOPIC='dc_suppliers', VALUE_FORMAT='AVRO');

CREATE TABLE customers_tbl (
    ROWKEY      INT PRIMARY KEY,
    FIRST_NAME  VARCHAR,
    LAST_NAME   VARCHAR,
    EMAIL       VARCHAR,
    CITY        VARCHAR,
    COUNTRY     VARCHAR,
    SOURCEDC    VARCHAR
)
WITH (
    KAFKA_TOPIC='dc_customers',
    VALUE_FORMAT='AVRO'
);

CREATE TABLE suppliers_tbl (
    ROWKEY      INT PRIMARY KEY,
    NAME        VARCHAR,
    EMAIL       VARCHAR,
    CITY        VARCHAR,
    COUNTRY     VARCHAR,
    SOURCEDC    VARCHAR
)
WITH (
  KAFKA_TOPIC='dc_suppliers',
  VALUE_FORMAT='AVRO'
);

CREATE TABLE products_tbl (
    ROWKEY      INT PRIMARY KEY,
    NAME        VARCHAR,
    DESCRIPTION VARCHAR,
    PRICE       DECIMAL(10,2),
    COST        DECIMAL(10,2),
    SOURCEDC    VARCHAR
)
WITH (
  KAFKA_TOPIC='dc_products',
  VALUE_FORMAT='AVRO'
);

SET 'auto.offset.reset'='earliest';
CREATE STREAM sales_enriched WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc_sales_enriched') AS SELECT
    o.id order_id,
    od.id order_details_id,
    o.order_date,
    od.product_id product_id,
    pt.name product_name,
    pt.description product_desc,
    od.price product_price,
    od.quantity product_qty,
    o.customer_id customer_id,
    ct.first_name customer_fname,
    ct.last_name customer_lname,
    ct.email customer_email,
    ct.city customer_city,
    ct.country customer_country
FROM sales_orders o
INNER JOIN sales_order_details od WITHIN 1 SECONDS ON (o.id = od.sales_order_id)
INNER JOIN customers_tbl ct ON (o.customer_id = ct.rowkey)
INNER JOIN products_tbl pt ON (od.product_id = pt.rowkey);

SET 'auto.offset.reset'='earliest';
CREATE STREAM purchases_enriched WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc_purchases_enriched') AS SELECT
    o.id order_id,
    od.id order_details_id,
    o.order_date,
    od.product_id product_id,
    pt.name product_name,
    pt.description product_desc,
    od.cost product_cost,
    od.quantity product_qty,
    o.supplier_id supplier_id,
    st.name supplier_name,
    st.email supplier_email,
    st.city supplier_city,
    st.country supplier_country
FROM purchase_orders o
INNER JOIN purchase_order_details od WITHIN 1 SECONDS ON (o.id = od.purchase_order_id)
INNER JOIN suppliers_tbl st ON (o.supplier_id = st.rowkey)
INNER JOIN products_tbl pt ON (od.product_id = pt.rowkey);

SET 'auto.offset.reset'='earliest';
CREATE STREAM product_supply_and_demand WITH (PARTITIONS=1, KAFKA_TOPIC='dc_product_supply_and_demand') AS SELECT
    product_id,
    product_qty * -1 "QUANTITY"
FROM sales_enriched;

INSERT INTO product_supply_and_demand SELECT
    product_id,
    product_qty "QUANTITY"
FROM purchases_enriched;

SET 'auto.offset.reset'='earliest';
CREATE TABLE current_stock WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc_current_stock') AS SELECT
    product_id,
    SUM(quantity) "STOCK_LEVEL"
FROM product_supply_and_demand
GROUP BY product_id;

SET 'auto.offset.reset'='earliest';
CREATE TABLE product_demand_last_3mins_tbl WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc_product_demand_last_3mins')
AS SELECT
    timestamptostring(windowStart,'HH:mm:ss') "WINDOW_START_TIME",
    timestamptostring(windowEnd,'HH:mm:ss') "WINDOW_END_TIME",
    product_id as rowkey,
    AS_VALUE(product_id) as product_id,
    SUM(product_qty) "DEMAND_LAST_3MINS"
FROM sales_enriched
WINDOW HOPPING (SIZE 3 MINUTES, ADVANCE BY 1 MINUTE)
GROUP BY product_id EMIT CHANGES;

CREATE STREAM product_demand_last_3mins WITH (KAFKA_TOPIC='dc_product_demand_last_3mins', VALUE_FORMAT='AVRO');

SET 'auto.offset.reset' = 'latest';
CREATE STREAM out_of_stock_events WITH (PARTITIONS = 1, KAFKA_TOPIC = 'dc_out_of_stock_events')
AS SELECT
    cs.product_id as rowkey,
    AS_VALUE(cs.product_id) as PRODUCT_ID,
    pd.window_start_time,
    pd.window_end_time,
    cs.stock_level,
    pd.demand_last_3mins,
    (cs.stock_level * -1) + pd.DEMAND_LAST_3MINS "QUANTITY_TO_PURCHASE"
FROM product_demand_last_3mins pd
INNER JOIN current_stock cs ON pd.product_id = cs.product_id
WHERE stock_level <= 0;

CREATE SINK CONNECTOR jdbc_mysql_sink WITH (
'connector.class'='io.confluent.connect.jdbc.JdbcSinkConnector',
'topics'='dc_out_of_stock_events',
'connection.url'='jdbc:mysql://mysql:3306/orders',
'connection.user'='mysqluser',
'connection.password'='mysqlpw',
'insert.mode'='INSERT',
'batch.size'='3000',
'auto.create'='true',
'key.converter'='org.apache.kafka.connect.storage.StringConverter'
);
