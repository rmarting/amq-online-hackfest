for i in $(seq 1 10); do
  oc process -f scenario2-address-template.yml -p TENANT=scenario2-dev -p ADDRESS=appq$i -p ADDRESS_NAME=queue/$i -p ADDRESS_TYPE=queue | oc apply -n scenario2-dev -f -
  oc process -f scenario2-address-template.yml -p TENANT=scenario2-dev -p ADDRESS=appt$i -p ADDRESS_NAME=topic/$i -p ADDRESS_TYPE=topic | oc apply -n scenario2-dev -f -
done;
