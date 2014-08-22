#!/bin/bash

ACTIVE () {
 echo `curl -sq  http://127.0.0.1:8888/fpm-status | grep "^active processes" | awk '{print $3}'`
} 
IDLE () {
 echo `curl -sq  http://127.0.0.1:8888/fpm-status | grep "idle processes" | awk '{print $3}'`
} 


/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name fpm_active --value `ACTIVE` --type int32 –unit fpm_active
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name fpm_idle   --value `IDLE`   --type int32 –unit fpm_idle

