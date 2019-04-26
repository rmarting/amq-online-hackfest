# Scenario 01

[Description](https://github.com/gpe-mw-training/amq-online-hackfest/blob/master/scenario1.md)

## Deploy Enmasse

Install Monitoring Operator following instructions 
from [https://github.com/integr8ly/application-monitoring-operator](https://github.com/integr8ly/application-monitoring-operator)

Create a new Inventory to deploy Enmasse using Ansible Playbook.

Sample inventory defined as [scenario1-with-standard-authservice.txt](./enmasse/scenario1-with-standard-authservice.txt) file:

```
tar xvzf enmasse-0.28.0-rc6.tgz

cd ansible

ansible-playbook -i inventory/scenario1-with-standard-authservice.txt playbooks/openshift/deploy_all.yml
```

Installation must be done with a ```cluster-admin``` user.


### https://github.com/EnMasseProject/enmasse/pull/2733/

Have to replace "${OAUTH_PROXY_IMAGE}" with "openshift/oauth-proxy:latest" in enmasse-0.28.0-rc6  


## Deploy Administrative Resources

As ```cluster-admin``` deploy following objects in ```enmasse-infra``` namespace:

1.- StandardInfraConfig: 

```
oc apply -f admin/scenario1-infraconfig.yml
```

2.- Address Plan:

```
oc apply -f admin/AddressPlan-scenario1-alerts-topic.yml
oc apply -f admin/AddressPlan-scenario1-available-queue.yml
oc apply -f admin/AddressPlan-scenario1-batch-queue.yml
oc apply -f admin/AddressPlan-scenario1-offline-queue.yml
oc apply -f admin/AddressPlan-scenario1-online-queue.yml
oc apply -f admin/AddressPlan-scenario1-results-queue.yml
```

3.- Address Space Plan:

```
oc apply -f admin/scenario1-address-space-plan.yml
```

### Sizing spreadsheet

https://docs.google.com/spreadsheets/d/1Ga2Rq9OlayxJrlx-eHrK_Pe5PDmk3WA_akzbgCbgQ1I/edit#gid=0


## Deploy Tenant Resources

As non ```cluster-admin``` user create a new project to define our scenario:

```
oc login -u user1
oc new-project user1
```

Deploy tenant resources:

1.- Deploy Address Space:

```
oc apply -f users/scenario1-address-space.yml
```

2.- Deploy Global Addresses:

```
oc apply -f users/scenario1-address-input-online.yml
oc apply -f users/scenario1-address-input-batch.yml
oc apply -f users/scenario1-address-alerts-topic.yml  
```

3.- Create users and custom resources using a OpenShift Template 
called [scenario1-user-template.yml](./users/scenario1-user-template.yml)

For a single user:

```
$ oc process -f users/scenario1-user-template.yml -p USER_ID=customer0 -p USER_PWD=$(echo -n test | base64) | oc apply -f -
messaginguser.user.enmasse.io/scenario1.customer0 created
address.enmasse.io/scenario1.results-customer0 created
```

To deploy bulk or users there is a simple shell script to do that similar to:

```
for i in $(seq 1 100); do
  oc process -f users/scenario1-user-template.yml -p USER_ID=customer$i -p USER_PWD=dGVzdA== | oc apply -f -
done;
```

To create an admin user:

```
oc process -f users/scenario1-user-admin-template.yml -p USER_ID=admin -p USER_PWD=dGVzdA== | oc apply -f -
```

To activate ```online``` window:

```
oc patch address scenario1.input-batch  --patch '{"spec":{"plan":"scenario1-offline-queue"}}'
oc patch address scenario1.input-online --patch '{"spec":{"plan":"scenario1-available-queue"}}'
```

To activate ```batch``` window:

```
oc patch address scenario1.input-batch  --patch '{"spec":{"plan":"scenario1-available-queue"}}'
oc patch address scenario1.input-online --patch '{"spec":{"plan":"scenario1-offline-queue"}}'
```

## Testing

Install ```cli-proton-python``` library:

```
sudo pip install cli-proton-python
```

This library provides to clients to consumer and produce messages:

```
cli-proton-python-sender --help
cli-proton-python-receiver --help
```

To debug ```qpid-proton```:

```
PN_TRACE_FRM=1 python client-sender.py -u amqps://test:test@messaging-uziryb7z2e-enmasse-infra.apps.amqhackfest-emea02.openshift.opentlc.com:443/input_batch
```

### Sender

Online senders:

```
cli-proton-python-sender \
  -b amqps://customer1:test@messaging-r9nbg9z7zi-enmasse-infra.apps.amqhackfest-emea02.openshift.opentlc.com:443 \
  -c 10000 \
  --msg-address=input_online \
  --msg-content-from-file=./users/messages/small-message.txt
```

Batch senders:

* medium messages:

```
cli-proton-python-sender \
  -b amqps://customer1:test@messaging-r9nbg9z7zi-enmasse-infra.apps.amqhackfest-emea02.openshift.opentlc.com:443 \
  -c 5 \
  --msg-address=input_batch \
  --msg-content-from-file=./users/messages/medium-message.txt
```

* large messages:

```
cli-proton-python-sender \
  -b amqps://customer1:test@messaging-r9nbg9z7zi-enmasse-infra.apps.amqhackfest-emea02.openshift.opentlc.com:443 \
  -c 5 \
  --msg-address=input_batch \
  --msg-content-from-file=./users/messages/large-message.txt
```

### Receiver

Customers consume messages as:

```
cli-proton-python-receiver \
  -b amqps://customer25:test@messaging-r9nbg9z7zi-enmasse-infra.apps.amqhackfest-emea02.openshift.opentlc.com:443/results_customer25 \
  -c 100
```

Admin users could consume messages as:

```
cli-proton-python-receiver \
  -b amqps://admin:test@messaging-r9nbg9z7zi-enmasse-infra.apps.amqhackfest-emea02.openshift.opentlc.com:443/input_batch \
  -c 100
```
