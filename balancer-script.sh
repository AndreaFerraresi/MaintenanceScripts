#!/bin/bash
set -e

usage() {
  cat << EOU
  usage: $0 -b balancer_ip -p balancer_port -a action [enable|disable] -B balancer_name -w worker -A

  DESCRIPTION
  -b The load balancer ip eg. 10.10.1.1
  -p The load balancer port default is 8080
  -a The action could be enable or disable 
  -B the balancer name eg. http_mod_balancer
  -w the worker url eg. ajp://url:1010
  -A Switch on the action on all the workers

EOU
}

RED="\033[0;31m"

BALANCER_IP=""
ACTION=""
ALL="0"
PORT="8080"
BALANCER_NAME=""
WORKER_URL=""

while getopts "h:a:b:B:p:w:A" OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    b)
      BALANCER_IP=$OPTARG
      ;;
    a)
      ACTION=$OPTARG
      ;;
    p)
      PORT=$OPTARG
      ;;
    A)
      ALL=1
      ;;
    w)
      WORKER_URL=$OPTARG
      ;;
    B)
      BALANCER_NAME=$OPTARG
      ;;
    ?)
      echo -e "$RED Invalid argument"
      usage
      exit 1 
      ;;
  esac
done

if [ -z $BALANCER_IP ] || [ -z $ACTION ]; then
  echo "[ERROR] Balancer IP and Action must be setted"
  echo ""
  usage
  exit 1
fi

is_valid_ip() {
#It checks if balancer_ip is a valid IP
  echo "$BALANCER_IP" | awk -F '[.]' 'function ok(n) {return (n ~ /^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$/)}{exit (ok($1) && ok($2) && ok($3) && ok($4))}'
  echo $?
}

if [ -n "$PORT" ] && [ ! $(echo "$PORT" | grep -E "^[0-9]+$") ]; then
  echo ""
  echo -e "Server port must be an integer"
  usage
  exit 1
fi

BALANCER_MANAGER_URL=http://$BALANCER_IP:$PORT/balancer-manager

if [ "$ACTION" == "enable" ]; then
  echo "Enabling balancing on:"
else
  echo "Disabling Balancing on:"
fi

if [ "$ALL" -eq "1" ]; then
  ALL_BALANCERS=`curl -s ${BALANCER_MANAGER_URL} | sed -n "/href=/s/.*href=\([^>]*\).*/\1/p"`
  WORKERS=`echo $ALL_BALANCERS | tr ' ' '\n'`

  for w in $WORKERS #Some magic for clean up the content retrieved by cURL
  do
    WORKER=${w%&*}
    WORKER=${WORKER#\"}
    NONCE=${w##*&}
    NONCE=${NONCE%\"}

    echo " ${BALANCER_MANAGER_URL}${WORKER}"

    curl -s -o /dev/null "${BALANCER_MANAGER_URL}${WORKER}&dw=${ACTION}&${NONCE}"
  done
else #Just in case we want disable a worker at time
  BALANCER_NONSE=`curl -s ${BALANCER_MANAGER_URL}  | sed -n "/href=/s/.*href=\([^>]*\).*/\1/p" | tail -1 | sed -n "s/.*nonce=\(.*\)\"/\1/p"`

  if [ "${BALANCER_NONSE}" == "" ]; then
    echo "Could not extract nonce from ${BALANCER_MANAGER_URL}"
    exit 1
  fi

  echo " ${BALANCER_MANAGER_URL}?b=${BALANCER_NAME}&w=${WORKER_URL}"

  curl -s -o /dev/null "${BALANCER_MANAGER_URL}?b=${BALANCER_NAME}&w=${WORKER_URL}&dw=${ACTION}&nonce=${BALANCER_NONSE}"
fi
