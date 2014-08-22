#!/bin/bash 

config_host=127.0.0.1
config_port=11211

Newdatafile=/tmp/ganglia_data/memcached/memcached-stats.new
Olddatafile=/tmp/ganglia_data/memcached/memcached-stats.old

if [ ! `type -P bc ` ]
  then 
    if [ `grep -o 'Debian\|Ubuntu' /etc/issue` ]
      then
       apt-get update  > /dev/null  2>&1
       apt-get -y install bc > /dev/null  2>&1
      else
       yum -yq install bc > /dev/null  2>&1
    fi
fi

if [ ! -d /tmp/ganglia_data/memcached ]
 then
    mkdir -p /tmp/ganglia_data/memcached
fi

func_trim(){
	var=$1
	if [ "$var" == "" ]
	then
	     echo -1
	     return 0
	fi
	if [[ $var = *[![:digit:].]* ]]
	then
	     echo -1
	else
	     echo ${var//%/}
	fi
}


function record_value
{
    if [ $# -lt 1 ]; then
        printf "You must specify a look-up value\n"
        exit 192
    fi
    LOOKUP_VAR=$1
    Metric_NAME=${2}
    Metric_TYPE=${3-float}
    Metric_UNITS=${4-units}
    Metric_VALUE=$(grep ^$LOOKUP_VAR $Newdatafile | awk '{print $2}')
    Metric_TRIM=`func_trim $Metric_VALUE`
    #echo $LOOKUP_VAR$Metric_TRIM
    /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name $LOOKUP_VAR --value $Metric_TRIM --type int32 --group Memcached
}

function record_value_rate
{
    if [ $# -lt 1 ]; then
        printf "You must specify a look-up value\n"
        exit 192
    fi
    memcached_VAR=$1
    Metric_NAME=${2-unspecified}
    Metric_TYPE=${3-float}
    Metric_UNITS=${4-"per second"}

    PREVIOUS_VALUE=`grep "$memcached_VAR[^_]" "$Olddatafile" |  grep -o "[0-9]\{1,\}"`
    NEW_VALUE=`grep "$memcached_VAR[^_]" "$Newdatafile" |  grep -o "[0-9]\{1,\}"`
    DELTA_VALUE=$(((NEW_VALUE-PREVIOUS_VALUE)))
    PREVIOUS_TIMESTAMP=`date -r "$Olddatafile" +%s`
    NEW_TIMESTAMP=`date -r "$Newdatafile" +%s`
    DELTA_TIMESTAMP=$[ $NEW_TIMESTAMP-$PREVIOUS_TIMESTAMP ]
    if [ $DELTA_VALUE -lt 0 ] || [ $DELTA_TIMESTAMP -lt 0 ]; then
        printf "skipping\n"
    else
        DELTA_RATE=`echo "scale=4; $DELTA_VALUE/$DELTA_TIMESTAMP" | bc -l`
	      #echo $memcached_VAR $DELTA_RATE | tr -d ""
	      #echo $memcached_VAR $DELTA_RATE
	      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name $memcached_VAR --value $DELTA_RATE --type int32 --group Memcached
    fi
}

tmetric=${1}
echo -e "stats\nquit" | nc $config_host  $config_port|tr -d ""| sed -s s/"STAT "/"memcached."/g \
 | grep 'cmd_get\|cmd_set\|get_hits\|set_hits\|delete_misses\|delete_hits\|bytes_read\|bytes_written\|curr_connections\|curr_items\|limit_maxbytes\|bytes\|rusage_user\|rusage_system' \
 | awk '{print $1":", $2 }'> "$Newdatafile"

if ! [ -e "$Olddatafile" ]
then
      cp "$Newdatafile" "$Olddatafile"
      sleep 1
echo -e "stats\nquit" | nc $config_host  $config_port| tr -d "" | sed -s s/"STAT "/"memcached."/g \
 | grep 'cmd_get\|cmd_set\|get_hits\|set_hits\|delete_misses\|delete_hits\|bytes_read\|bytes_written\|curr_connections\|curr_items\|limit_maxbytes\|bytes\|rusage_user\|rusage_system' \
 | awk '{print $1":", $2 }'> "$Newdatafile"
fi 

record_value_rate "memcached.cmd_get"
record_value_rate "memcached.cmd_set"
record_value_rate "memcached.get_hits"
record_value_rate "memcached.set_hits"
record_value_rate "memcached.delete_misses"
record_value_rate "memcached.delete_hits"
record_value_rate "memcached.bytes_read"
record_value_rate "memcached.bytes_written"
record_value "memcached.curr_connections"
record_value "memcached.curr_items"
record_value "memcached.limit_maxbytes"
record_value "memcached.bytes"
record_value "memcached.rusage_user"
record_value "memcached.rusage_system"

cp "$Newdatafile" "$Olddatafile"

