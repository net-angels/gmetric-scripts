#!/bin/bash 

Newdatafile=/tmp/esmon/new
Olddatafile=/tmp/esmon/old

if [ ! -d /tmp/esmon ]
 then
   mkdir /tmp/esmon
fi


function record_value
{
    grep $1 $Newdatafile
}

function record_value_rate
{
    es_VAR=$1
    PREVIOUS_VALUE=`grep "$es_VAR[^_]" "$Olddatafile" |  grep -o "[0-9]\{1,\}"`
    NEW_VALUE=`grep "$es_VAR[^_]" "$Newdatafile" |  grep -o "[0-9]\{1,\}"`
    DELTA_VALUE=$(((NEW_VALUE-PREVIOUS_VALUE)))
    PREVIOUS_TIMESTAMP=`date -r "$Olddatafile" +%s`
    NEW_TIMESTAMP=`date -r "$Newdatafile" +%s`
    DELTA_TIMESTAMP=$[ $NEW_TIMESTAMP-$PREVIOUS_TIMESTAMP ]
    if [ $DELTA_VALUE -lt 0 ] || [ $DELTA_TIMESTAMP -lt 0 ]; then
        printf "skipping\n"
    else
        DELTA_RATE=`echo "scale=4; $DELTA_VALUE/$DELTA_TIMESTAMP" | bc -l`
              echo $es_VAR $DELTA_RATE
    fi
}

URL="http://127.0.0.1:9200/_nodes/_local/stats/?all=true"

curl -s  "$URL" | sed -e 's/[{}]/''/g' \
        | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' \
        | grep '"query_total"\|"index_total"\|"get"\|heap_committed_in_bytes\|heap_used_in_bytes\|open_file_descriptors\|current_open' \
        | sed -s s/'":"'/_/g| tr -d '"' | sed -s s/total/per_second/g | sed -s s/indexing_//g | sed -s s/mem_heap_used_in_bytes/heap_used_in_bytes/g \
        | tr ':' ' ' | awk '{print "es_"$1,$2}'> $Newdatafile

es_metrics () {
        record_value_rate es_index_per_second
        record_value_rate es_get_per_second
        record_value_rate es_query_per_second
	 
	record_value es_open_file_descriptors
	record_value es_heap_used_in_bytes
	record_value es_heap_committed_in_bytes
	record_value es_non_heap_used_in_bytes
	record_value es_non_heap_committed_in_bytes
	record_value es_http_current_open
	
}


es_metrics | while read STATS 
do
        NAME=`echo $STATS | awk '{print $1}'`
        VALUE=`echo $STATS | awk '{print $2}'`
	/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name $NAME --value $VALUE --type int32 -unit $NAME -g ElasticSearch
done

cp "$Newdatafile" "$Olddatafile"

