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

echo "Consuming $COUNT messages from results_customer$CUSTOMER_ID address"

cli-proton-python-receiver \
  -b amqps://customer$CUSTOMER_ID:test@messaging-r9nbg9z7zi-enmasse-infra.apps.amqhackfest-emea02.openshift.opentlc.com:443/results_customer$CUSTOMER_ID \
  -c $COUNT
