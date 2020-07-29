# Workshop Kafka

Generation de la documentation pour l'image nginx sur votre machine
```
asciidoctor asciidoc/workshop.adoc -o asciidoc/index.html -a stylesheet=stylesheet.css
sed -i -e '/<title>/r asciidoc/clipboard.html' asciidoc/index.html
```

Démarrage de l'infrastructure docker
```
docker-compose up -d

Pour arrêter tout => docker-compose down -v
```

Alimentation de la base de données en temps réel
```
docker exec -dit db-trans-simulator sh -c "python -u /simulate_dbtrans.py > /proc/1/fd/1"
```

Accès à la documentation du workshop => http://localhost


Pour elasticsearch
```
curl -i -X POST -H "Accept:application/json" \
    -H  "Content-Type:application/json" http://localhost:8083/connectors/ \
    -d '{
        "name": "elasticsearch-sink",
        "config": {
             "connector.class": "io.confluent.connect.elasticsearch.ElasticsearchSinkConnector",
             "tasks.max": "1",
             "topics": "dc_out_of_stock_events",
             "connection.url": "http://elasticsearch:9200",
             "type.name": "kafka-connect",
             "key.converter": "org.apache.kafka.connect.storage.StringConverter",
             "transforms": "InsertMessageTime,ConvertTimeValue",
             "transforms.InsertMessageTime.type": "org.apache.kafka.connect.transforms.InsertField$Value",
             "transforms.InsertMessageTime.timestamp.field": "timestamp",
             "transforms.ConvertTimeValue.type": "org.apache.kafka.connect.transforms.TimestampConverter$Value",
             "transforms.ConvertTimeValue.target.type": "unix",
             "transforms.ConvertTimeValue.field": "timestamp",
             "transforms.ConvertTimeValue.format": "yyyy-MM-dd HH:mm:ss"
        }
    }'
```