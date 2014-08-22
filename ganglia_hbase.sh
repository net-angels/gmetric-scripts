#!/bin/bash

# Monitors HBase region servers by calling /jmx via web UI. 
# Tested with HBase 0.98  version. 

HOST=127.0.0.1
Newdatafile=/tmp/hbasemon/new
Olddatafile=/tmp/hbasemon/old

if [ ! -d /tmp/hbasemon ]
 then
   mkdir /tmp/hbasemon
fi

curl -s "http://$HOST:60030/jmx"|grep -A5 '"HeapMemoryUsage"\|totalRequestCount'|grep 'committed\|init\|max\|used\|totalRequestCount\|readRequestCount\|writeRequestCount'|sed -s s/RequestCount/_requests/g|tr -d ','| tr -d '"'|sed -s s/'  '//g|tr -d : > $Newdatafile

function record_value
{
    grep $1 $Newdatafile
}

function record_value_rate
{
    hbase_VAR=$1
    PREVIOUS_VALUE=`grep "$hbase_VAR[^_]" "$Olddatafile" |  grep -o "[0-9]\{1,\}"`
    NEW_VALUE=`grep "$hbase_VAR[^_]" "$Newdatafile" |  grep -o "[0-9]\{1,\}"`
    DELTA_VALUE=$(((NEW_VALUE-PREVIOUS_VALUE)))
    PREVIOUS_TIMESTAMP=`date -r "$Olddatafile" +%s`
    NEW_TIMESTAMP=`date -r "$Newdatafile" +%s`
    DELTA_TIMESTAMP=$[ $NEW_TIMESTAMP-$PREVIOUS_TIMESTAMP ]
    if [ $DELTA_VALUE -lt 0 ] || [ $DELTA_TIMESTAMP -lt 0 ]; then
        printf "skipping\n"
    else
        DELTA_RATE=`echo "scale=4; $DELTA_VALUE/$DELTA_TIMESTAMP" | bc -l`
              echo $hbase_VAR $DELTA_RATE
    fi
}

hbase_metrics () {
	        record_value_rate total_requests
	        record_value_rate read_requests
	        record_value_rate write_requests
}

hbase_metrics | while read STATS 
do
        NAME=`echo $STATS | awk '{print $1}'`
        VALUE=`echo $STATS | awk '{print $2}'`
	/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name hbase_$NAME --value $VALUE --type int32 -unit hbase_$NAME -g HBase
done


grep 'committed\|init\|max\|used' $Newdatafile | awk '{print "hbase_"$1"_heap", $2}' | while read METR
do 
	NAME=`echo $METR | awk '{print $1}'`
	VALUE=`echo $METR | awk '{print $2}'`
	/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name $NAME --value $VALUE --type int32 -unit $NAME -g HBase
done

cp "$Newdatafile" "$Olddatafile"
