# Scenario 02

[Description](https://github.com/gpe-mw-training/amq-online-hackfest/blob/master/scenario2.md)

## Deploy Enmasse

**NOTE**: If you completed [scenario1](../scenario1) and you deployed Enmasse, this
step is not needed and you can move to the next step.

Install Monitoring Operator following instructions 
from [https://github.com/integr8ly/application-monitoring-operator](https://github.com/integr8ly/application-monitoring-operator)

Create a new Inventory to deploy Enmasse using Ansible Playbook.

Sample inventory defined as [scenario1-with-standard-authservice.txt](../scenario1/enmasse/scenario1-with-standard-authservice.txt) file:

```
tar xvzf enmasse-0.28.0-rc6.tgz
cd ansible
ansible-playbook -i inventory/scenario1-with-standard-authservice.txt playbooks/openshift/deploy_all.yml
```

Installation must be done with a ```cluster-admin``` user.

### https://github.com/EnMasseProject/enmasse/pull/2733/

Have to replace ```${OAUTH_PROXY_IMAGE}``` with ```openshift/oauth-proxy:latest``` in ```enmasse-0.28.0-rc6```  

## Deploy Administrative Resources

As ```cluster-admin``` deploy following objects in ```enmasse-infra``` namespace:

1.- StandardInfraConfig: 

```
oc apply -f admin/scenario2-infraconfig.yml
oc apply -f admin/scenario2-infraconfig-non-prod.yml
```

2.- Address Plan:

```
oc apply -f admin/AddressPlan-scenario2-queue.yml
oc apply -f admin/AddressPlan-scenario2-topic.yml
```

3.- Address Space Plan:

```
oc apply -f admin/scenario2-address-space-plan-dev.yml
oc apply -f admin/scenario2-address-space-plan-qe.yml
oc apply -f admin/scenario2-address-space-plan-prod.yml
```

## Deploy Tenant Resources

As non ```cluster-admin``` user create a new project to define each logical
environment (dev, qe, prod):

```
oc login -u user2
oc new-project scenario2-dev
oc new-project scenario2-qe
oc new-project scenario2-prod
```

Deploy tenant resources:

1.- Deploy Address Space:

```
oc apply -f users/scenario2-address-space-dev.yml -n scenario2-dev
oc apply -f users/scenario2-address-space-qe.yml -n scenario2-qe
oc apply -f users/scenario2-address-space-prod.yml -n scenario2-prod
```

To allow applications identify the endpoint for each AddressSpace, we 
created a ConfigMap including the messaging endpoint provided by each
AddressSpace.

Similar to:

```
oc create configmap scenario2-endpoints-configmap \
    --from-literal=messaging-endpoint=messaging-dxnt0n4qcf.enmasse-infra.svc.cluster.local \
    -n scenario2-dev
    
oc create configmap scenario2-endpoints-configmap \
    --from-literal=messaging-endpoint=messaging-gszuvdhzon.enmasse-infra.svc.cluster.local \
    -n scenario2-qe

oc create configmap scenario2-endpoints-configmap \
    --from-literal=messaging-endpoint=messaging-h0zbd2mvkw.enmasse-infra.svc.cluster.local \
    -n scenario2-prod
```

2.- Deploy Addresses for each AddressSpace using a single template [scenario2-address-template.yml](./users/scenario2-address-template.yml).
This template is applied with different shells scripts similars to:

```
for i in $(seq 1 10); do
  oc process -f scenario2-address-template.yml -p TENANT=scenario2-dev -p ADDRESS=queue$i -p ADDRESS_NAME=queue/$i -p ADDRESS_TYPE=queue | oc apply -n scenario2-dev -f -
  oc process -f scenario2-address-template.yml -p TENANT=scenario2-dev -p ADDRESS=topic$i -p ADDRESS_NAME=topic/$i -p ADDRESS_TYPE=topic | oc apply -n scenario2-dev -f -
done;  
```

Scripts to automate address creation:

```
cd users
./create-application-address-dev.sh
./create-application-address-qe.sh
./create-application-address-prod.sh
```

**NOTE**: There is a issue in Brokered Address Spaces when you want to use
wildcards in address name. If you want to use asterisk, the you put at the end and
a slash character (/) should be added. Otherwise you will not be granted to
send or consume messages. 

3.- Create users and custom resources using a OpenShift Template 
called [scenario2-application-user-template.yml](./users/scenario2-application-user-template.yml)

For a single user:

```
oc process -f scenario2-application-user-template.yml -p TENANT=scenario2-dev -p APP_ID=app$i -p APP_PWD=$(echo -n test | base64) | oc apply -n scenario2-dev -f -
```

A secret it will be created to save and secure the password defined for this user. Applications
must mount this secret on its Deployments to access the password and used to connect to brokers.

To deploy bulk of users there are simple shell scripts to do for each AddressSpace:

```
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

```
$ oc get svc | grep messaging
messaging-dxnt0n4qcf   ClusterIP   172.30.55.34     <none>        5672/TCP,5671/TCP  5h
messaging-gszuvdhzon   ClusterIP   172.30.61.7      <none>        5672/TCP,5671/TCP  2h
messaging-h0zbd2mvkw   ClusterIP   172.30.18.179    <none>        5672/TCP,5671/TCP  3h
```

So the internal messaging endpoints will be similar to:

```
messaging-dxnt0n4qcf.enmasse-infra.svc.cluster.local
messaging-gszuvdhzon.enmasse-infra.svc.cluster.local
messaging-h0zbd2mvkw.enmasse-infra.svc.cluster.local
```

The great [Using Quiver with AMQ on Red Hat OpenShift Container Platform](https://developers.redhat.com/blog/2019/04/24/using-quiver-with-amq-on-red-hat-openshift-container-platform/) 
blog post at [Red Hat Developer Portal](https://developers.redhat.com) describes a easy way
to test AMQ brokers using a tool called [Quiver](https://github.com/ssorj/quiver)

Prepare our namespace to deploy Quiver pods:

```
oc import-image quiver:latest --from=docker.io/ssorj/quiver --confirm
oc policy add-role-to-user view system:serviceaccount:$(oc project -q):default
```

Deploy Quiver pods to send and consume messages for each AddressSpaces. The following
commands show how to do it for one environment:

```
oc process -f https://raw.githubusercontent.com/ssorj/quiver/0.2.0/packaging/openshift/openshift-pod-template.yml \
  DOCKER_IMAGE=$(oc get is quiver -o jsonpath='{.status.dockerImageRepository}'):latest \
  DOCKER_CMD="[\"quiver\", \"amqp://app2:test@messaging-dxnt0n4qcf.enmasse-infra.svc.cluster.local:5672/queue/2\", \"--impl\", \"qpid-jms\", \"--verbose\", \"--timeout\", \"60\"]" \
  | oc create -f -

oc process -f https://raw.githubusercontent.com/ssorj/quiver/0.2.0/packaging/openshift/openshift-pod-template.yml \
  DOCKER_IMAGE=$(oc get is quiver -o jsonpath='{.status.dockerImageRepository}'):latest \
  DOCKER_CMD="[\"quiver\", \"amqp://app4:test@messaging-dxnt0n4qcf.enmasse-infra.svc.cluster.local:5672/queue/4\", \"--impl\", \"qpid-jms\", \"--verbose\", \"--timeout\", \"60\"]" \
  | oc create -f -         

oc process -f https://raw.githubusercontent.com/ssorj/quiver/0.2.0/packaging/openshift/openshift-pod-template.yml \
  DOCKER_IMAGE=$(oc get is quiver -o jsonpath='{.status.dockerImageRepository}'):latest \
  DOCKER_CMD="[\"quiver\", \"amqp://app6:test@messaging-dxnt0n4qcf.enmasse-infra.svc.cluster.local:5672/queue/6\", \"--impl\", \"qpid-jms\", \"--verbose\", \"--timeout\", \"60\"]" \
  | oc create -f -
         
oc process -f https://raw.githubusercontent.com/ssorj/quiver/0.2.0/packaging/openshift/openshift-pod-template.yml \
  DOCKER_IMAGE=$(oc get is quiver -o jsonpath='{.status.dockerImageRepository}'):latest \
  DOCKER_CMD="[\"quiver\", \"amqp://app8:test@messaging-dxnt0n4qcf.enmasse-infra.svc.cluster.local:5672/queue/8\", \"--impl\", \"qpid-jms\", \"--verbose\", \"--timeout\", \"60\"]" \
  | oc create -f -
```
