#!/bin/bash

kubectl create -f ./sc.default.yaml

if [[ -z $(echo $GITHUB_TOKEN) ]]; then echo "export GITHUB_TOKEN= token with permission to public repos for ksonnet to download stuff"; fi

echo "Setting up automation..."
 if [[ -z $(find /usr/local/bin/ -name "ks") ]]; then
	## KSONNET
	wget https://github.com/ksonnet/ksonnet/releases/download/v0.13.0/ks_0.13.0_linux_amd64.tar.gz -O ksonnet.tar.gz
	mkdir -p ksonnet
	tar -xvf ksonnet.tar.gz -C ksonnet --strip-components=1
	sudo cp ksonnet/ks /usr/local/bin
	rm -fr ksonnet
else
	echo "ksonnet already setup!"
fi


## Setup channel with kubernetes cluster
#mkdir -p ~/.kube
#juju scp kubernetes-master/0:config ~/.kube/config
#sudo snap install kubectl --classic


# From: https://github.com/canonical-labs/kaggle-kubeflow-tutorial/blob/master/install-kubeflow.sh

# Create a namespace for kubeflow deployment
NAMESPACE=${NAMESPACE:-kubeflow}
kubectl create namespace ${NAMESPACE}

# Which version of Kubeflow to use
# For a list of releases refer to:
# https://github.com/kubeflow/kubeflow/releases
VERSION=${VERSION:-v0.2.7}

# Initialize a ksonnet app. Set the namespace for it's default environment.
APP_NAME=${APP_NAME:-my-kubeflow}
ks init ${APP_NAME}
cd ${APP_NAME}
ks env set default --namespace ${NAMESPACE}

# Install Kubeflow components
ks registry add kubeflow github.com/kubeflow/kubeflow/tree/${VERSION}/kubeflow

ks pkg install kubeflow/argo
ks pkg install kubeflow/core
ks pkg install kubeflow/examples
ks pkg install kubeflow/katib
ks pkg install kubeflow/mpi-job
ks pkg install kubeflow/pytorch-job
ks pkg install kubeflow/seldon
ks pkg install kubeflow/tf-serving

# Create templates for core components
ks generate kubeflow-core kubeflow-core --name=kubeflow-core
ks param set kubeflow-core jupyterHubImage gcr.io/kubeflow/jupyterhub-k8s:1.0.1
# Enable collection of anonymous usage metrics
# Skip this step if you don't want to enable collection.
ks param set kubeflow-core reportUsage true
ks param set kubeflow-core usageId $(uuidgen)
# For non-cloud use .. use NodePort (instead of ClusterIp)
#ks param set kubeflow-core jupyterHubServiceType NodePort
ks param set kubeflow-core jupyterHubServiceType LoadBalancer
# Deploy Kubeflow
ks apply default -c kubeflow-core

ks generate argo kubeflow-argo --name=kubeflow-argo
ks apply default -c kubeflow-argo

# NB logDir is where the TF events are written. At this high level, might not be useful
# ks is 0.2.7 complains about logDir intermittently .. will adjust for 0.3.x
# see issue https://github.com/kubeflow/kubeflow/issues/1330
# ks generate tensorboard kubeflow-tensorboard --name=kubeflow-tensorboard --logDir=logs
# ks apply default -c kubeflow-tensorboard

until [[ `kubectl get pods -n=kubeflow | grep -o 'ContainerCreating' | wc -l` == 0 ]] ; do
  echo "Checking kubeflow status until all pods are running ("`kubectl get pods -n=kubeflow | grep -o 'ContainerCreating' | wc -l`" not running). Sleeping for 10 seconds."
  sleep 10
done

# Print port information
PORT=`kubectl get svc -n=kubeflow -o go-template='{{range .items}}{{if eq .metadata.name "tf-hub-lb"}}{{(index .spec.ports 0).nodePort}}{{"\n"}}{{end}}{{end}}'`
echo ""
echo "JupyterHub Port: ${PORT}"
echo ""
