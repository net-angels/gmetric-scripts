#!/bin/bash
Newdatafile=/tmp/ganglia_data/bind9/bind-stats.new
Olddatafile=/tmp/ganglia_data/bind9/bind-stats.old

if [ ! -d /tmp/ganglia_data/bind9 ]
then
  mkdir -p /tmp/ganglia_data/bind9
fi

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
    echo $LOOKUP_VAR$Metric_TRIM
}

function record_value_rate
{
    if [ $# -lt 1 ]; then
        printf "You must specify a look-up value\n"
        exit 192
    fi
    bind_VAR=$1
    Metric_NAME=${2-unspecified}
    Metric_TYPE=${3-float}
    Metric_UNITS=${4-"per second"}

    PREVIOUS_VALUE=`grep "$bind_VAR[^_]" "$Olddatafile" |  grep -o "[0-9]\{1,\}"`
    NEW_VALUE=`grep "$bind_VAR[^_]" "$Newdatafile" |  grep -o "[0-9]\{1,\}"`
    DELTA_VALUE=$(((NEW_VALUE-PREVIOUS_VALUE)))
    PREVIOUS_TIMESTAMP=`date -r "$Olddatafile" +%s`
    NEW_TIMESTAMP=`date -r "$Newdatafile" +%s`
    DELTA_TIMESTAMP=$[ $NEW_TIMESTAMP-$PREVIOUS_TIMESTAMP ]
    if [ $DELTA_VALUE -lt 0 ] || [ $DELTA_TIMESTAMP -lt 0 ]; then
        printf "skipping\n"
    else
        DELTA_RATE=`echo "scale=4; $DELTA_VALUE/$DELTA_TIMESTAMP" | bc -l`
              echo $bind_VAR $DELTA_RATE
    fi
}

tmetric=${1}



/usr/sbin/rndc stats 
cat /var/cache/bind/zones.stats  \
	|  sed -ne '/++ Incoming Requests ++/,/++ Zone Maintenance Statistics ++/p' \
	| grep 'QUERY\|[0-9] responses sent\|successful answer\|resulted in authoritative answe\|resulted in non authoritative answer\|SERVFAIL\|NXDOMAIN\|queries caused recursion' \
       	| sed -e 's/^[ \t]*//' | sed 's/ /:/' | tr " " "_" |awk -F ':' '{print $2":",$1}'| tr "[A-Z]" "[a-z]" > "$Newdatafile"

if ! [ -e "$Olddatafile" ]
then
 cp "$Newdatafile" "$Olddatafile"
  sleep 1
cat /var/cache/bind/zones.stats  \
	|  sed -ne '/++ Incoming Requests ++/,/++ Zone Maintenance Statistics ++/p' \
	| grep 'QUERY\|[0-9] responses sent\|successful answer\|resulted in authoritative answe\|resulted in non authoritative answer\|SERVFAIL\|NXDOMAIN\|queries caused recursion' \
        | sed -e 's/^[ \t]*//' | sed 's/ /:/' |awk -F ':' '{print $2":", $1}' | tr "[A-Z]" "[a-z]" > "$Newdatafile"
fi

QUERY () { 
	record_value_rate "query:"|awk '{print $2}' 
} 
RESP_SEND () {
	record_value_rate "responses_sent:"|awk '{print $2}' 
} 
Q_SUCCESS () {
        record_value_rate "queries_resulted_in_successful_answer:"|awk '{print $2}'
} 
Q_AUTHOR () {
        record_value_rate "queries_resulted_in_authoritative_answer:"|awk '{print $2}'
}
Q_NAUTHOR () {
        record_value_rate "queries_resulted_in_non_authoritative_answer:"|awk '{print $2}'
}
Q_SFAIL () {
        record_value_rate "queries_resulted_in_servfail:"|awk '{print $2}'
}
Q_NXDOM () {
        record_value_rate "queries_resulted_in_nxdomain:"|awk '{print $2}'
}
Q_RECUR () {
        record_value_rate "queries_caused_recursion:"|awk '{print $2}'
}


/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name b9_query --value `QUERY` --type int32 –unit b9_query
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name b9_response_sent --value `RESP_SEND` --type int32 –unit b9_response_sent
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name b9_queries_success --value `Q_SUCCESS` --type int32 –unit b9_queries_success
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name b9_authoritative --value `Q_AUTHOR` --type int32 –unit b9_authoritative
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name b9_not_authoritative --value `Q_NAUTHOR` --type int32 –unit b9_not_authoritative
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name b9_failed --value `Q_SFAIL` --type int32 –unit b9_failed
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name b9_nxdomain --value `Q_NXDOM` --type int32 –unit b9_nxdomain
/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name b9_recursion --value `Q_RECUR` --type int32 –unit b9_recursion

cat /dev/null > /var/cache/bind/zones.stats
cp "$Newdatafile" "$Olddatafile"
