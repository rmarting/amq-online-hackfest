# Scenario 02

[Description](https://github.com/gpe-mw-training/amq-online-hackfest/blob/master/scenario2.md)

## Deploy Administrative Resources

As ```cluster-admin``` deploy following objects in ```amq-online-infra``` namespace:

1.- [Brokered Infra Config](https://enmasse.io/documentation/0.29.2/kubernetes/#infrastructure-configuration-messaging):

```bash
oc apply -f admin/01-infra-config/
```

2.- [Address Plan](https://enmasse.io/documentation/0.29.2/kubernetes/#con-address-plans-messaging):

```bash
oc apply -f admin/02-address-plan/
```

3.- [Address Space Plan](https://enmasse.io/documentation/0.29.2/kubernetes/#con-address-space-plans-messaging):

```bash
oc apply -f admin/03-address-space-plan
```

## Deploy Tenant Resources

As non ```cluster-admin``` user create a new project to define each logical
environment (dev, qe, prod):

```bash
oc login -u user2
oc new-project scenario2-dev
oc new-project scenario2-qe
oc new-project scenario2-prod
```

Deploy tenant resources:

1.- Deploy [Address Space](https://enmasse.io/documentation/0.29.2/kubernetes/#con-address-space-messaging):

```bash
oc apply -f users/01-scenario2-address-space-dev.yml    -n scenario2-dev
oc apply -f users/02-scenario2-address-space-qe.yml     -n scenario2-qe
oc apply -f users/03-scenario2-address-space-prod.yml   -n scenario2-prod
```

To allow applications identify the endpoint for each AddressSpace, we created
a ConfigMap including the messaging endpoint provided by each AddressSpace.

Development:

```bash
oc create configmap scenario2-endpoints-configmap \
    --from-literal=messaging-endpoint=$(oc get addressspace scenario2-dev --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].serviceHost}') \
    -n scenario2-dev
```

QE:

```bash
oc create configmap scenario2-endpoints-configmap \
    --from-literal=messaging-endpoint=$(oc get addressspace scenario2-qe --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].serviceHost}') \
    -n scenario2-qe
```

Production:

```bash
oc create configmap scenario2-endpoints-configmap \
    --from-literal=messaging-endpoint=$(oc get addressspace scenario2-prod --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].serviceHost}') \
    -n scenario2-prod
```

2.- Deploy Addresses for each AddressSpace using a single template [scenario2-address-template.yml](./users/scenario2-address-template.yml).

This template is applied with different shells scripts similars to:

```bash
for i in $(seq 1 10); do
  oc process -f scenario2-address-template.yml -p TENANT=scenario2-dev -p ADDRESS=queue$i -p ADDRESS_NAME=queue/$i -p ADDRESS_TYPE=queue | oc apply -n scenario2-dev -f -
  oc process -f scenario2-address-template.yml -p TENANT=scenario2-dev -p ADDRESS=topic$i -p ADDRESS_NAME=topic/$i -p ADDRESS_TYPE=topic | oc apply -n scenario2-dev -f -
done;  
```

Scripts to automate address creation:

```bash
cd users
./create-application-address-dev.sh
./create-application-address-qe.sh
./create-application-address-prod.sh
```

**NOTE**: There is a issue in Brokered Address Spaces when you want to use
wildcards in address name. If you want to use asterisk, then you put at the end
a slash character (/) should be added. Otherwise you will not be granted to
send or consume messages.

3.- Create users and custom resources using a OpenShift Template 
called [scenario2-application-user-template.yml](./users/scenario2-application-user-template.yml)

For a single user:

```bash
oc process -f scenario2-application-user-template.yml -p TENANT=scenario2-dev -p APP_ID=app$i -p APP_PWD=$(echo -n test | base64) | oc apply -n scenario2-dev -f -
```

A secret it will be created to save and secure the password defined for this user. Applications
must mount this secret on its Deployments to access the password and used to connect to brokers.

To deploy bulk of users there are simple shell scripts to do for each AddressSpace:

```bash
cd users
./create-application-users-dev.sh
./create-application-users-qe.sh
./create-application-users-prod.sh
```

## Testing

As Brokered Address Spaces we omitted to create a external route to connect with
the address created, so these resources are only available to be used inside
OpenShift cluster.

To connect to each AddressSpace we need to identify each ```messaging``` service.

```bash
> oc get addressspace scenario2-dev --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].serviceHost}' -n scenario2-dev
messaging-fyvaav0jzc.amq-online-infra.svc
> oc get addressspace scenario2-qe --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].serviceHost}' -n scenario2-qe
messaging-qlnvynk857.amq-online-infra.svc
> oc get addressspace scenario2-prod --output='jsonpath={.status.endpointStatuses[?(@.name=="messaging")].serviceHost}' -n scenario2-prod
messaging-mceyuz2c3u.amq-online-infra.svc
```

The great [Using Quiver with AMQ on Red Hat OpenShift Container Platform](https://developers.redhat.com/blog/2019/04/24/using-quiver-with-amq-on-red-hat-openshift-container-platform/)
blog post at [Red Hat Developer Portal](https://developers.redhat.com) describes a easy way
to test AMQ brokers using a tool called [Quiver](https://github.com/ssorj/quiver)

Prepare our namespace to deploy Quiver pods:

```bash
oc import-image quiver:latest --from=docker.io/ssorj/quiver --confirm
oc policy add-role-to-user view system:serviceaccount:$(oc project -q):default
```

Deploy Quiver pods to send and consume messages for each AddressSpaces. The following
commands show how to do it for each environment:

Development:

```bash
oc process -f https://raw.githubusercontent.com/ssorj/quiver/0.3.0/packaging/openshift/openshift-pod-template.yml \
  DOCKER_IMAGE=$(oc get is quiver -n scenario2-dev -o jsonpath='{.status.dockerImageRepository}'):latest \
  DOCKER_CMD="[\"quiver\", \"amqp://app2:test@messaging-fyvaav0jzc.amq-online-infra.svc:5672/queue/2\", \"--impl\", \"qpid-jms\", \"--verbose\", \"--timeout\", \"60\"]" \
  | oc create -n scenario2-dev -f -
```

QE:

```bash
oc process -f https://raw.githubusercontent.com/ssorj/quiver/0.3.0/packaging/openshift/openshift-pod-template.yml \
  DOCKER_IMAGE=$(oc get is quiver -n scenario2-qe -o jsonpath='{.status.dockerImageRepository}'):latest \
  DOCKER_CMD="[\"quiver\", \"amqp://app4:test@messaging-qlnvynk857.amq-online-infra.svc:5672/queue/4\", \"--impl\", \"qpid-jms\", \"--verbose\", \"--timeout\", \"60\"]" \
  | oc create -n scenario2-qe -f -
```

Production:

```bash
oc process -f https://raw.githubusercontent.com/ssorj/quiver/0.3.0/packaging/openshift/openshift-pod-template.yml \
  DOCKER_IMAGE=$(oc get is quiver -o jsonpath='{.status.dockerImageRepository}'):latest \
  DOCKER_CMD="[\"quiver\", \"amqp://app6:test@messaging-mceyuz2c3u.amq-online-infra.svc:5672/queue/6\", \"--impl\", \"qpid-jms\", \"--verbose\", \"--timeout\", \"60\"]" \
  | oc create -n scenario2-prod -f -
```
