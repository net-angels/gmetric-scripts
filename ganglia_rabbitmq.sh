#!/bin/bash

USER=admin
PASS=admin

curl -s -u $USER:$PASS  http://localhost:15672/api/overview  | sed -e 's/[{}]/''/g' | awk -v RS=',"' -F: '/rate/ {print "rmq_"$1,$3}' | tr -d '"' | while read X 
 do 
 /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name `echo $X | awk '{print $1}'`  --value `echo $X | awk  '{print $2}'`  --type int32 --group RabbitMQ 
done
