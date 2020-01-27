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
MESSAGING_ENDPOINT=$(oc get addressspace scenario1 --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].externalHost}')

echo "Consuming $COUNT messages from input_$TYPE address from $MESSAGING_ENDPOINT"

cli-proton-python-receiver \
  -b amqps://admin:test@messaging-vs1msx9v1r-amq-online-infra.apps.labs.sandbox1320.opentlc.com:443/input_$TYPE \
  -c $COUNT
