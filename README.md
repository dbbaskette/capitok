# capitok
End to End demo environment using Cluster API for a base K8S Cluster for Tanzu Application Service on K8S

These instructions are designed to work on a mac

Prereqs:
* kubectl
* docker
* kind
* AWS cli
* jq
* Clone of this repo

## Building the Workload Cluster
1. Install clusterctl binary 
    ```
    curl -L  https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.3/clusterctl-darwin-amd64
    chmod +x ./clusterctl
    sudo mv ./clusterctl /usr/local/bin/clusterctl
    ```
1. Install clusterawsadm binary
    ```
    curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v0.5.2/clusterawsadm-darwin-amd64
    chmod +x ./clusterctl
    sudo mv ./clusterctl /usr/local/bin/clusterctl
    ```
1. Export AWS Variables
    ```
    source env-files/aws-exports.sh
    ```
1. Create local management cluster:
    ```
    kind create cluster --name clusterapi
    ```
1. Create the Cloudformation Stack
    ```
    clusterawsadm alpha bootstrap create-stack
    ```
1. Initialize the Management Cluster
    ```
    clusterctl init --infrastructure aws
    ```
1. Backup the kubeconfig
    ```
    cp $HOME/.kube/config  $HOME/.kube/config.capi
    ```
1. Build the cluster configuration
    ```
    clusterctl config cluster tas --kubernetes-version v1.15.7 --control-plane-machine-count=1 --worker-machine-count=6 --kubeconfig=$HOME/.kube/config.capi > tas.yaml
    ```
1. Modify the tas.yaml file to adjust root disk sizing.  Add these lines to the AWSMachineTemplate spec.  The result should look like this:

    ```
    rootVolume:
        size: 25
    ```
    result:
    ```
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
    kind: AWSMachineTemplate
    metadata:
    name: tas-md-0
    namespace: default
    spec:
    template:
        spec:
        iamInstanceProfile: nodes.cluster-api-provider-aws.sigs.k8s.io
        instanceType: t3.xlarge
        sshKeyName: tmc
        rootVolume:
            size: 25
    ```
1. Create your Workload cluster for your TAS deployment:
    ```
    kubectl --kubeconfig=$HOME/.kube/config.capi  apply -f ./tas.yaml
    ```
    Output:
    
    ```
    cluster.cluster.x-k8s.io/tas created
    awscluster.infrastructure.cluster.x-k8s.io/tas created
    kubeadmcontrolplane.controlplane.cluster.x-k8s.io/tas-control-plane created
    awsmachinetemplate.infrastructure.cluster.x-k8s.io/tas-control-plane created
    machinedeployment.cluster.x-k8s.io/tas-md-0 created
    awsmachinetemplate.infrastructure.cluster.x-k8s.io/tas-md-0 created
    kubeadmconfigtemplate.bootstrap.cluster.x-k8s.io/tas-md-0 created
    ```
1. Monitor the status until complete (it will take awhile). **kubeadmcontrolplane** will report as *initialized*:
    ```
    kubectl --kubeconfig=$HOME/.kube/config.capi  get cluster --all-namespaces
    kubectl --kubeconfig=$HOME/.kube/config.capi  get machines --all-namespaces
    kubectl --kubeconfig=$HOME/.kube/config.capi  get kubeadmcontrolplane --all-namespaces
    ```
    ```
    ![]()

## Preparing the Workload Cluster for TAS
1. Get the kubeconfig for the Workload cluster:
    ```
    kubectl --kubeconfig=$HOME/.kube/config.capi --namespace=default get secret/tas-kubeconfig -o jsonpath={.data.value} | base64 --decode > /Users/dbaskette/.kube/config.tas
    ```
1. Make the kubeconfig the default;
    ```
    cp $HOME/.kube/config.tas $HOME/.kube/config
    ```
1. Install the Calico Networking CNI into the cluster
    ```
    kubectl --kubeconfig=$HOME/.kube/config.tas apply -f https://docs.projectcalico.org/v3.12/manifests/calico.yaml







