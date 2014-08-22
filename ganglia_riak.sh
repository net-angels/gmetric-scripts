#!/bin/bash
export LC_ALL=C
source /etc/bashrc 2> /dev/null
source /etc/profile 2> /dev/null

func_tr(){
shopt -s extglob
while read line; do

       case $line in

            *"$2"*)

            echo "riak."${line//+("$2")/"$3"}

            ;;

            *)
            echo "riak."$line
            ;;

       esac
done <<< "$1"
shopt -u extglob
}

INT1=`ip add | grep -o '10.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/'|tr -d "/"`
INT2=`ip add | grep -o '172.16.[0-9]\{1,3\}\.[0-9]\{1,3\}/'|tr -d "/"`
INT3=`ip add | grep -o '192.168.[0-9]\{1,3\}\.[0-9]\{1,3\}/'|tr -d "/"`
EXT1=`ip add | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/' |tr -d "/"| grep -v 127.0.0.1`

if [ $INT1 ] ; then IP=$INT1
elif [ $INT2 ] ; then IP=$INT2
elif [ $INT3 ] ; then IP=$INT3

else IP=$EXT1
fi


#if [ `curl -s -o /tmp/riak_stats -w "%{http_code}" http://$IP:8098/stats -H "Accept: text/plain"` -eq 200 ]
# then
#   echo "riak.node.status:1" > /dev/null 
#  else
#   echo "riak.node.status:0" > /dev/null
#   exit 1
#fi

METRICS="node_gets|node_gets_total|node_puts|node_puts_total|vnode_gets|vnode_gets_total|vnode_puts_total."

#curl -s  http://$IP:8098/stats -H "Accept: text/plain" | egrep -i $METRICS  | tr -d '"' | tr -d "," | tr ":" " "


curl -s  http://$IP:8098/stats -H "Accept: text/plain" | egrep -i $METRICS  | tr -d '"' | tr -d "," | tr ":" " " | while read STATS 
do

        `echo $STATS | awk '{print "/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name riak_"$1, "--value", $2, "--type int32 -unit", "riak_"$1 }'`

done

