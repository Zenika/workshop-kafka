#!/bin/bash

sudo apt -y update
sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

sudo usermod -aG docker ubuntu
sudo chmod 666 /var/run/docker.sock

sudo curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

sudo apt-get install -y asciidoctor

git clone https://github.com/Zenika/workshop-kafka.git /home/ubuntu/workshop-kafka

cd /home/ubuntu/workshop-kafka

asciidoctor asciidoc/workshop.adoc -o asciidoc/index.html -a stylesheet=stylesheet.css
sed -i -e '/<title>/r asciidoc/clipboard.html' asciidoc/index.html

docker-compose up -d workshop-docs
