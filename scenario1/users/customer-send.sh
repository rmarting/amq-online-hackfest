#!/bin/bash

show_usage() {
  echo -e "Usage: customer-send CUSTOMER_ID COUNT TYPE SIZE"
  echo ""
  echo "arguments:"
  echo -e "\tCUSTOMER_ID Customer ID"
  echo -e "\tCOUNT Number of messages"
  echo -e "\tTYPE [online|batch]"
  echo -e "\tSIZE [small|medium|large]"
}

if [ $# -lt 4 ]
then
  show_usage
  exit 1
fi

CUSTOMER_ID=$1
COUNT=$2
TYPE=$3
SIZE=$4
MESSAGING_ENDPOINT=$(oc get addressspace scenario1 --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].externalHost}')

echo "Sending $COUNT $TYPE messages to input_$TYPE address at $MESSAGING_ENDPOINT"

cli-proton-python-sender \
  -b amqps://customer$CUSTOMER_ID:test@$MESSAGING_ENDPOINT:443 \
  -c $COUNT \
  --msg-address=input_$TYPE \
  --msg-content-from-file=./messages/$SIZE-message.txt
