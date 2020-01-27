#!/bin/bash

show_usage() {
	echo -e "Usage: customer-receiver CUSTOMER_ID COUNT"
	echo ""
	echo "arguments:"
	echo -e "\tCUSTOMER_ID Customer ID"
	echo -e "\tCOUNT Number of messages"
}

if [ $# -lt 2 ]
then
  show_usage
  exit 1
fi

CUSTOMER_ID=$1
COUNT=$2
MESSAGING_ENDPOINT=$(oc get addressspace scenario1 --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].externalHost}')

echo "Consuming $COUNT messages from results_customer$CUSTOMER_ID address at $MESSAGING_ENDPOINT"

cli-proton-python-receiver \
  -b amqps://customer$CUSTOMER_ID:test@$MESSAGING_ENDPOINT:443/results_customer$CUSTOMER_ID \
  -c $COUNT
