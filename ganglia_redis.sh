TEMP=/tmp/redis_check_tmp.txt
HOST=127.0.0.1
METRICS='connected_clients\|used_memory\|used_memory_rss\|used_memory_peak\|changes_since_last_save\|total_commands_processed\|keyspace_\|uptime_in_seconds'

(printf "INFO\r\n"; sleep 0.1) | nc -q1 $HOST 6379 | grep $METRICS|grep -v human |cat -v | tr -d '^M' > /tmp/redis_check_tmp.txt
TIMESTAMP=`grep uptime_in_seconds /tmp/redis_check_tmp.txt| cut -d ':' -f2`

for GANG in `cat $TEMP | grep -v uptime_in_seconds`
  do
   NAME=`echo $GANG|cut -d ':' -f1`
   VALUE=`echo $GANG|cut -d ':' -f2 | cat -v | tr -d '^M'`
    if [ $NAME = total_commands_processed ];
     then
      VALUE2=`echo $VALUE/$TIMESTAMP | bc`
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE2 --type int32 --group Redis
    elif [ $NAME = keyspace_hits ]
     then
      VALUE2=`echo $VALUE/$TIMESTAMP | bc`
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE2 --type int32 --group Redis
    elif [ $NAME = keyspace_misses ]
     then
      VALUE2=`echo $VALUE/$TIMESTAMP | bc`
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE2 --type int32 --group Redis
    elif [ $NAME = changes_since_last_save ]
     then
      VALUE2=`echo $VALUE/$TIMESTAMP | bc`
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE2 --type int32 --group Redis
    else
      /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name redis_$NAME --value $VALUE --type int32 --group Redis
    fi
 done
