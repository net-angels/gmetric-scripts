#!/bin/bash

export LC_ALL=C
source /etc/bashrc 2> /dev/null
source /etc/profile 2> /dev/null


INT1=`ip add | grep -o '10.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/'|tr -d "/"`
INT2=`ip add | grep -o '172.16.[0-9]\{1,3\}\.[0-9]\{1,3\}/'|tr -d "/"`
INT3=`ip add | grep -o '192.168.[0-9]\{1,3\}\.[0-9]\{1,3\}/'|tr -d "/"`
EXT1=`ip add | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/' |tr -d "/"| grep -v 127.0.0.1`

if [ $INT1 ] ; then IP=$INT1
elif [ $INT2 ] ; then IP=$INT2
elif [ $INT3 ] ; then IP=$INT3

else IP=$EXT1
fi

if [ ! `type -P curl` ]
then
if [ `type -P apt-get ` ]
  then
        DISTRO_FAMILY=dpkg
        apt-get -qq -y install curl > /dev/null
elif  [ `type -P yum ` ]
   then
        DISTRO_FAMILY=rpm
        yum -q -y install curl
else
   DISTRO_FAMILY=UNSUPPORTED
fi
fi


curldata=$(curl -s "http://127.0.0.1:9200/_nodes/$IP/stats?all=true" | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}'|tr -d '"')

METRICS="heap_committed_in_bytes|heap_used_in_bytes|non_heap_committed_in_bytes|non_heap_used_in_bytes|open_file_descriptors|http:current_open:|index_time_in_millis:|index_current:|delete_time_in_millis:|delete_current:|query_current:|query_time_in_millis:|fetch_time_in_millis:|fetch_current:|merges:current:"

echo -n "$curldata" | egrep -i $METRICS | while read LINE 
do
 LINE2=`echo ${LINE//[-'"'' ',]/}`
 NAME=`echo es_${LINE2} |sed -e 's/merges:current/merges_current/g' -e 's/mem:heap/mem_heap/g' -e 's/http:current/http_current/g' | cut -d ":" -f 1`
 VALUE=`echo es_${LINE2} |sed -e 's/merges:current/merges_current/g' -e 's/mem:heap/mem_heap/g' -e 's/http:current/http_current/g' | cut -d ":" -f 2`
 /usr/bin/gmetric -c /etc/ganglia/gmond.conf --name $NAME --value $VALUE --type int32 -unit $NAME
done

