#!/bin/bash

juju add-model k8s-test

juju model-config juju-model-default.yaml
juju model-default juju-model-default.yaml
juju model-defaults juju-model-default.yaml

juju deploy bundle.yaml


sleep 900
juju expose kubernetes-worker
juju expose kubeapi-load-balancer
juju expose landscape-haproxy
juju trust aws-integrator

sleep 900

echo "Working around a k8s-aws bug... https://github.com/kubernetes-incubator/kube-aws/issues/1085"
mkdir -p ~/.kube
juju scp kubernetes-master/0:config ~/.kube/config
sudo snap install kubectl --classic
kubectl create -f ./sc.default.yaml
