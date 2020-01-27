#!/bin/bash
for i in $(seq 1 100); do
  oc process -f ./templates/scenario1-user-template.yml -p USER_ID=customer$i -p USER_PWD=dGVzdA== | oc apply -f -
done;
