# AMQ Online Hackfest

Solutions implemented to cover scenarios proposed during AMQ Online HackFest in Munich.

Original scenarios provided from:

* [https://github.com/gpe-mw-training/amq-online-hackfest](https://github.com/gpe-mw-training/amq-online-hackfest)

## Deploy Enmasse

Download Enmasse relase from [Enmasse Relase 0.29.2](https://github.com/EnMasseProject/enmasse/releases/tag/0.29.2).

Create a new Inventory to deploy Enmasse using Ansible Playbook.

Sample inventory defined as [scenario1-with-standard-authservice.txt](./enmasse/scenario1-with-standard-authservice.txt) file:

```bash
> tar xvzf enmasse-0.29.2.tgz
> cd ansible
> ansible-playbook -i enmasse/scenarios-with-standard-authservice.txt playbooks/openshift/deploy_all.yml
```

Installation must be done with a ```cluster-admin``` user.

## Undeploy Enmasse

Using Ansible Playbook:

```bash
ansible-playbook -i enmasse/scenarios-with-standard-authservice.txt playbooks/openshift/uninstall.yml
```

Deleting resources:

```bash
> oc delete clusterrolebindings -l app=enmasse
> oc delete crd -l app=enmasse
> oc delete clusterroles -l app=enmasse
> oc delete apiservices -l app=enmasse
> oc delete oauthclients -l app=enmasse
> oc delete clusterservicebrokers -l app=enmasse
> oc delete project amq-online-infra
> oc delete project amq-online-monitoring
```
