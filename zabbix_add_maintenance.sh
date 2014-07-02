#!/bin/bash

####################################
#                                  #
# Zabbix shops Maintenance Switch  #
# Script                           #
#                                  #  
# mrenaud 2013-11-18               #
# aferraresi 2014-7-2              #
# Usage:                           #
# zabbixmnt <duration in minutes>  #
#                                  #
# Default: 60 minutes              #
#                                  #
####################################

# Define constants

CFG_PROGRAM_ONAME=`basename $0`
CFG_PROGRAM_NAME="Create Zabbix maintenance"
CFG_PROGRAM_AUTHOR="Matthias Renaud <matthias.renaud@ricardo.ch>, Andrea Ferraresi <andrea.ferraresi@ricardo.ch>"
CFG_PROGRAM_VERSION="0.42"

ZBX_URL='https://monitoring_url/zabbix'
ZBX_USER='<username>'
ZBX_PWD='<password>'
ZBX_API="$ZBX_URL/api_jsonrpc.php"
HOST_GRP="<hostgrp>"

DUR_SEC=$1

# If no parameter is given, use default value (1 hour)

if [ -z "$DUR_SEC" ]; then
  #DURATION=3600
  DURATION=14400 # 4 hours keep people sleeping during the night
else
  DURATION=`expr $DUR_SEC \* 60`
fi

# Get Zabbix auth token

AUTH_TOKEN=`curl -i -s -k -X POST -H 'Content-Type:application/json' -d "{\"jsonrpc\": \"2.0\",\"method\":\"user.authenticate\",\"params\":{\"user\":\"$ZBX_USER\",\"password\":\"$ZBX_PWD\"},\"auth\": null,\"id\":0}" $ZBX_API | tail -n 1 | cut -d '"' -f 8`

# Retrieve Host ID via Zabbix API

HOSTGRP_ID=`curl -i -s -k -X POST -H 'Content-Type:application/json' -d "{\"jsonrpc\": \"2.0\",\"method\":\"hostgroup.get\",\"params\":{\"output\":\"extend\",\"filter\":{\"name\":[\"$HOST_GRP\"]}},\"auth\":\"$AUTH_TOKEN\",\"id\":1}" $ZBX_API | tail -n 1 | cut -d '"' -f 10`
# Some calculations for end time of maintenance

TIMESTAMP_H=`date`
TIMESTAMP=`date +%s`
MNT_END=`expr $TIMESTAMP + $DURATION`

# Create maintenance

MNT_ID=`curl -i -s -k -X POST -H 'Content-Type:application/json' -d "{\"jsonrpc\": \"2.0\",\"method\":\"maintenance.create\",\"params\":{\"name\":\"[SHOPS DEPLOYMENT] - $HOST_GRP - $TIMESTAMP_H\",\"active_till\":$MNT_END,\"groupids\":[\"$HOSTGRP_ID\"],\"timeperiods\":[{\"period\":$DURATION}]},\"auth\":\"$AUTH_TOKEN\",\"id\":2}" $ZBX_API | tail -n 1 | cut -d '"' -f 10`
echo "Host group $HOSTGRP set on maintenance for $DUR_SEC minutes."

#echo $AUTH_TOKEN
#echo $HOST
#echo $HOST_ID
#echo $MNT_ID
#echo $DURATION

