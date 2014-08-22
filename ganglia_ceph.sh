#!/bin/bash

rados df | grep total | while read STATS 
do
	`echo $STATS | awk '{print "/usr/bin/gmetric -c /etc/ganglia/gmond.conf --name ceph_df_"$2, "--value", $3, "--type int32 -unit", "ceph_df_"$2 }'`
done
