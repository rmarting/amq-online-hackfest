#!/bin/bash

show_usage() {
  echo -e "Usage: admin-receiver TYPE COUNT"
  echo ""
  echo "arguments:"
  echo -e "\tTYPE [online|batch]"
  echo -e "\tCOUNT Number of messages"
}

if [ $# -lt 2 ]
then
  show_usage
  exit 1
fi

TYPE=$1
COUNT=$2

echo "Consuming $COUNT messages from input_$TYPE address"

cli-proton-python-receiver \
  -b amqps://admin:test@messaging-r9nbg9z7zi-enmasse-infra.apps.amqhackfest-emea02.openshift.opentlc.com:443/input_$TYPE \
  -c $COUNT
