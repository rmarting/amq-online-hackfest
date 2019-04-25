for i in $(seq 1 15); do
  oc process -f scenario2-application-user-template.yml -p TENANT=scenario2-dev -p APP_ID=app$i -p APP_PWD='dGVzdA==' | oc apply -n scenario2-dev -f -
done;
