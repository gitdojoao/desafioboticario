#!/bin/sh
yum install -y httpd
service httpd start
chkconfig httpd on

echo "Desafio Boticario - Hello from AWS EC2!" > /var/www/html/index.html