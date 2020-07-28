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
