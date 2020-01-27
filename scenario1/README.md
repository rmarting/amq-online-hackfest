# Scenario 01

[Description](https://github.com/gpe-mw-training/amq-online-hackfest/blob/master/scenario1.md)

## Deploy Administrative Resources

As ```cluster-admin``` deploy following objects in ```amq-online-infra``` namespace:

1.- [Standard Infra Config](https://enmasse.io/documentation/0.29.2/kubernetes/#infrastructure-configuration-messaging):

```bash
oc apply -f admin/01-scenario1-infra-config.yml
```

2.- [Address Plan](https://enmasse.io/documentation/0.29.2/kubernetes/#con-address-plans-messaging):

```bash
oc apply -f admin/02-address-plan/
```

3.- [Address Space Plan](https://enmasse.io/documentation/0.29.2/kubernetes/#con-address-space-plans-messaging):

```bash
oc apply -f admin/03-scenario1-address-space-plan.yml
```

### Sizing Spreadsheet

[Scenario 1 Load Estimation](https://docs.google.com/spreadsheets/d/1Ga2Rq9OlayxJrlx-eHrK_Pe5PDmk3WA_akzbgCbgQ1I/edit#gid=0)

## Deploy Tenant Resources

As non ```cluster-admin``` user create a new project to define our scenario:

```bash
oc login -u user1
oc new-project user1
```

Deploy tenant resources:

1.- Deploy [Address Space](https://enmasse.io/documentation/0.29.2/kubernetes/#con-address-space-messaging):

```bash
oc apply -f users/scenario1-address-space.yml
```

2.- Deploy [Addresses](https://enmasse.io/documentation/0.29.2/kubernetes/#con-address-messaging):

```bash
oc apply -f users/02-address/
```

3.- Create users and custom resources using a OpenShift Template called [scenario1-user-template.yml](./users/templates/scenario1-user-template.yml)

For a single user:

```bash
$ oc process -f users/templates/scenario1-user-template.yml -p USER_ID=customer0 -p USER_PWD=$(echo -n test | base64) | oc apply -f -
messaginguser.user.enmasse.io/scenario1.customer0 created
address.enmasse.io/scenario1.results-customer0 created
```

To deploy bulk or users there is a simple shell script [create-users.sh](./users/create-users.sh) to do that:

```bash
for i in $(seq 1 100); do
  oc process -f users/templates/scenario1-user-template.yml -p USER_ID=customer$i -p USER_PWD=dGVzdA== | oc apply -f -
done;
```

To create an admin user:

```bash
oc process -f users/templates/scenario1-user-admin-template.yml -p USER_ID=admin -p USER_PWD=dGVzdA== | oc apply -f -
```

To activate ```online``` window (script [go-online.sh](./users/go-online.sh)):

```bash
oc patch address scenario1.input-batch  --patch '{"spec":{"plan":"scenario1-offline-queue"}}'
oc patch address scenario1.input-online --patch '{"spec":{"plan":"scenario1-available-queue"}}'
```

To activate ```batch``` window (script [go-batch.sh](./users/go-batch.sh)):

```bash
oc patch address scenario1.input-batch  --patch '{"spec":{"plan":"scenario1-available-queue"}}'
oc patch address scenario1.input-online --patch '{"spec":{"plan":"scenario1-offline-queue"}}'
```

## Testing

Install ```cli-proton-python``` library:

```bash
sudo pip install cli-proton-python
```

This library provides to clients to produce and to consume messages:

```bash
cli-proton-python-sender --help
cli-proton-python-receiver --help
```

To debug ```qpid-proton```:

```bash
PN_TRACE_FRM=1 python client-sender.py -u amqps://test:test@$MESSAGING_ENDPOINT:443/input_batch
```

### Messaging Endpoint

AddressSpace includes a list of endpoints as:

* messaging: Main endpoint to be used by consumers and producers
* messaging-wss: Messaging endpoint to be used with Web Sockets
* console: console: Management Web console

Extract the **messaging** endpoint to an environment variable:

```bash
export MESSAGING_ENDPOINT=$(oc get addressspace scenario1 --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].externalHost}')
```

### Sender

Online senders (script [customer-send.sh](./users/customer-send.sh)):

```bash
cli-proton-python-sender \
  -b amqps://customer1:test@$MESSAGING_ENDPOINT:443 \
  -c 1000 \
  --msg-address=input_online \
  --msg-content-from-file=./users/messages/small-message.txt
```

Batch senders:

* Medium messages:

```bash
cli-proton-python-sender \
  -b amqps://customer1:test@$MESSAGING_ENDPOINT:443 \
  -c 500 \
  --msg-address=input_batch \
  --msg-content-from-file=./users/messages/medium-message.txt
```

* Large messages:

```bash
cli-proton-python-sender \
  -b amqps://customer1:test@$MESSAGING_ENDPOINT:443 \
  -c 500 \
  --msg-address=input_batch \
  --msg-content-from-file=./users/messages/large-message.txt
```

### Receiver

Customers consume messages as  (script [customer-receiver.sh](./users/customer-reciever.sh)):

```bash
cli-proton-python-receiver \
  -b amqps://customer25:test@$MESSAGING_ENDPOINT:443/results_customer25 \
  -c 100
```

Admin users could consume messages as:

```bash
cli-proton-python-receiver \
  -b amqps://admin:test@$MESSAGING_ENDPOINT:443/input_batch \
  -c 100
```
