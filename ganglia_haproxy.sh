#!/bin/bash

HAUSER=yoda
HAPASS=PASSWORD

for X in `curl -s -u $HAUSER:$HAPASS "http://127.0.0.1/haproxy?stats;csv" | grep app | tr [A-Z] [a-z] ` ; 
do 
 GSESSION="-c /etc/ganglia/gmond.conf --name `echo $X | awk -F "," '{print "hp_sessions_"$2}'`  --value `echo $X | awk -F "," '{print $5}'`  --type int32 --group Haproxy"
 GCONRATE="-c /etc/ganglia/gmond.conf --name `echo $X | awk -F "," '{print "hp_connrate_"$2}'`  --value `echo $X | awk -F "," '{print $34}'` --type int32 --group Haproxy"
 /usr/bin/gmetric $GSESSION
 /usr/bin/gmetric $GCONRATE
done

