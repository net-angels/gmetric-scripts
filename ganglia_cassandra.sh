#!/bin/bash

host=`hostname`
Newdatafile=/tmp/cassmon/new
Olddatafile=/tmp/cassmon/old

if [ ! -d /tmp/cassmon ]
 then 
   mkdir /tmp/cassmon 
fi 

function record_value
{
    grep $1 $Newdatafile
}

function record_value_rate
{
    cassa_VAR=$1
    PREVIOUS_VALUE=`grep "$cassa_VAR[^_]" "$Olddatafile" |  grep -o "[0-9]\{1,\}"`
    NEW_VALUE=`grep "$cassa_VAR[^_]" "$Newdatafile" |  grep -o "[0-9]\{1,\}"`
    DELTA_VALUE=$(((NEW_VALUE-PREVIOUS_VALUE)))
    PREVIOUS_TIMESTAMP=`date -r "$Olddatafile" +%s`
    NEW_TIMESTAMP=`date -r "$Newdatafile" +%s`
    DELTA_TIMESTAMP=$[ $NEW_TIMESTAMP-$PREVIOUS_TIMESTAMP ]
    if [ $DELTA_VALUE -lt 0 ] || [ $DELTA_TIMESTAMP -lt 0 ]; then
        printf "skipping\n"
    else
        DELTA_RATE=`echo "scale=4; $DELTA_VALUE/$DELTA_TIMESTAMP" | bc -l`
              echo $cassa_VAR $DELTA_RATE
    fi
}

links -dump http://$host:8081/mbean?objectname=org.apache.cassandra.request%3Atype%3DReadStage   | grep 'CompletedTasks\|ActiveCount\|PendingTasks'| awk '{print "cassa_reads_"$1, $5}' > $Newdatafile
links -dump http://$host:8081/mbean?objectname=org.apache.cassandra.request%3Atype%3DRequestResponseStage  | grep 'CompletedTasks\|ActiveCount\|PendingTasks'| awk '{print "cassa_requests_"$1, $5}' >> $Newdatafile
links -dump http://$host:8081/mbean?objectname=org.apache.cassandra.request%3Atype%3DMutationStage | grep 'CompletedTasks\|ActiveCount\|PendingTasks'| awk '{print "cassa_mutation_"$1, $5}' >> $Newdatafile
links -dump http://$host:8081/mbean?objectname=org.apache.cassandra.internal%3Atype%3DGossipStage | grep 'CompletedTasks\|ActiveCount\|PendingTasks'| awk '{print "cassa_gossip_"$1, $5}' >> $Newdatafile
links -dump http://$host:8081/mbean?objectname=org.apache.cassandra.db%3Atype%3DCompactionManager | grep 'CompletedTasks\|PendingTasks'| awk '{print "cassa_compacton_"$1, $5}' >> $Newdatafile 
links -dump http://$host:8081/mbean?objectname=org.apache.cassandra.db%3Atype%3DStorageProxy | grep 'RecentRangeLatencyMicros\|RecentReadLatencyMicros\|RecentWriteLatencyMicros'| awk '{print "cassa_latency_"$1, $5}' >> $Newdatafile
links -dump http://$host:8081/mbean?objectname=java.lang%3Atype%3DMemory | grep -A1 ^HeapMemoryUsage | egrep -o "used=[0-9]+|committed=[0-9]+" | awk -F "=" {'print "cassa_heap_"$1, $2'} >> $Newdatafile
links -dump http://$host:8081/mbean?objectname=java.lang%3Atype%3DMemory | grep -A1 ^NonHeapMemoryUsage | egrep -o "used=[0-9]+|committed=[0-9]+" | awk -F "=" {'print "cassa_non_heap_"$1, $2'} >> $Newdatafile
links -dump http://$host:8081/mbean?objectname=org.apache.cassandra.db%3Atype%3DCaches| grep KeyCacheHits | awk '{print "cassa_KeyCacheHits", $5}' >> $Newdatafile
links -dump http://$host:8081/mbean?objectname=org.apache.cassandra.db%3Atype%3DCaches| grep KeyCacheEntries | awk '{print "cassa_KeyCacheEntries",$5}' >> $Newdatafile

cassa_metrics () {
        record_value_rate cassa_reads_CompletedTasks
        record_value_rate cassa_requests_CompletedTasks
        record_value_rate cassa_mutation_CompletedTasks
        record_value_rate cassa_gossip_CompletedTasks
        record_value_rate cassa_compacton_CompletedTasks
        record_value_rate cassa_KeyCacheHits
	record_value cassa_reads_ActiveCount
        record_value cassa_reads_PendingTasks
        record_value cassa_requests_ActiveCount
        record_value cassa_requests_PendingTasks
        record_value cassa_mutation_ActiveCount
        record_value cassa_mutation_PendingTasks
        record_value cassa_gossip_ActiveCount
        record_value cassa_gossip_PendingTasks
        record_value cassa_compacton_PendingTasks
        record_value cassa_latency_RecentRangeLatencyMicros
        record_value cassa_latency_RecentReadLatencyMicros
        record_value cassa_latency_RecentWriteLatencyMicros
	record_value cassa_heap_committed
	record_value cassa_heap_used
	record_value cassa_non_heap_committed
	record_value cassa_non_heap_used
	record_value cassa_KeyCacheEntries
}

cassa_metrics | while read STATS 
do
	NAME=`echo $STATS | awk '{print $1}'`
	VALUE=`echo $STATS | awk '{print $2}'`
	/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name $NAME --value $VALUE --type int32 -unit $NAME -g Cassandra
done

cassa_metrics

cp "$Newdatafile" "$Olddatafile"


