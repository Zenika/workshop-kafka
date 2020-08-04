#!/bin/bash

##########################################################
#export ccloud_cluster_endpoint=?????
#export ccloud_api_key=?????
#export ccloud_api_secret=?????
###########################################################

export ext_ip=`dig +short myip.opendns.com @resolver1.opendns.com`
export dc=`python3 script/getuuid.py`
export ccloud_topics=sales_orders,sales_order_details,purchase_orders,purchase_order_details,customers,suppliers,products
export cloud_replication_factor=3

rm mount/ccloud.properties
rm .env

echo "ssl.endpoint.identification.algorithm=https" >> mount/ccloud.properties
echo "sasl.mechanism=PLAIN" >> mount/ccloud.properties
echo "request.timeout.ms=20000" >> mount/ccloud.properties
echo "bootstrap.servers=${ccloud_cluster_endpoint}" >> mount/ccloud.properties
echo "retry.backoff.ms=500" >> mount/ccloud.properties
echo "sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${ccloud_api_key}\" password=\"${ccloud_api_secret}\";" >> mount/ccloud.properties
echo "security.protocol=SASL_SSL" >> mount/ccloud.properties

# Create .env file for Docker
echo "CLOUD_REPLICATION_FACTOR=${cloud_replication_factor}" >> .env
echo "EXT_IP=`dig +short myip.opendns.com @resolver1.opendns.com`" >> .env
echo "CCLOUD_CLUSTER_ENDPOINT=${ccloud_cluster_endpoint}" >> .env
echo "CCLOUD_API_KEY=${ccloud_api_key}" >> .env
echo "CCLOUD_API_SECRET=${ccloud_api_secret}" >> .env
echo "DC=${dc}" >> .env
echo "CCLOUD_TOPICS=${ccloud_topics}" >> .env

sed 's/dcxx/'"${dc}"'/g' template/simulate_dbtrans.py.tpl > mount/db_transaction_simulator/simulate_dbtrans.py
sed 's/dcxx/'"${dc}"'/g' template/mysql_schema.sql.tpl > mount/mysql_schema.sql
sed 's/dcxx/'"${dc}"'/g' template/login.tpl > mount/c3/login

asciidoctor asciidoc/workshop.adoc -o asciidoc/index.html -a stylesheet=stylesheet.css -a externalip=${ext_ip} -a dc=${dc} -a "feedbackformurl=${feedback_form_url}"

# Inject c&p functionality into rendered html file.
sed -i -e '/<title>/r asciidoc/clipboard.html' asciidoc/index.html