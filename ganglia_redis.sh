#!/bin/bash

TEMP1=/tmp/redis_check_new.txt
TEMP2=/tmp/redis_check_old.txt

HOST=127.0.0.1
METRICS='connected_clients\|used_memory\|used_memory_rss\|used_memory_peak\|changes_since_last_save\|total_commands_processed\|keyspace_\|uptime_in_seconds'


(printf "INFO\r\n"; sleep 0.1) | nc -q1 $HOST 6379 | grep $METRICS|grep -v human |cat -v | tr -d '^M' > $TEMP1
TIMESTAMP=`grep uptime_in_seconds $TEMP1| cut -d ':' -f2`

function Get_Diff
{
	OLD_VALUE=`grep $1 $TEMP2|cut -d ':' -f2`
	CUR_VALUE=`grep $1 $TEMP1|cut -d ':' -f2`
	VALUE_DIFF=`expr $CUR_VALUE - $OLD_VALUE`
	echo $VALUE_DIFF
}
	
TIME_DIFF=`Get_Diff uptime_in_seconds`

function Get_Value_Rate
{
	RATE=`Get_Diff $1`
	VALUE=`expr $RATE / $TIME_DIFF`
	NAME=$1
	echo $VALUE
}

for GANG in `cat $TEMP1 | grep -v uptime_in_seconds`
  do
   NAME=`echo $GANG|cut -d ':' -f1`
   VALUE=`echo $GANG|cut -d ':' -f2`
    if [ $NAME = total_commands_processed ];
     then
      VALUE2=`Get_Value_Rate $NAME`
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE2 --type int32 --group Redis
    elif [ $NAME = keyspace_hits ]
     then
      VALUE2=`Get_Value_Rate $NAME`
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE2 --type int32 --group Redis
    elif [ $NAME = keyspace_misses ]
     then
      VALUE2=`Get_Value_Rate $NAME`
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE2 --type int32 --group Redis
    elif [ $NAME = changes_since_last_save ]
     then
      VALUE2=`Get_Value_Rate $NAME`
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE2 --type int32 --group Redis
    else
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE --type int32 --group Redis#
    fi
 done

cp $TEMP1 $TEMP2
