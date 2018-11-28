#!/bin/bash

sudo rm -rf ./my-kubeflow /usr/local/bin/ks
kubectl delete sc gp2
kubectl -n kubeflow delete po,svc --all
