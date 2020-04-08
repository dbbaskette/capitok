# capitok
End to End demo environment using Cluster API for a base K8S Cluster for Tanzu Application Service on K8S

These instructions are designed to work on a mac


Setup ClusterAPI and AWS
------------------------

Prereqs:
* kubectl
* docker
* kind
* AWS cli
* jq


1) Install clusterctl binary 
    ```
    curl -L  https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.3/clusterctl-darwin-amd64
    chmod +x ./clusterctl
    sudo mv ./clusterctl /usr/local/bin/clusterctl
    ```
2) Install clusterawsadm binary
    ```
    curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v0.5.2/clusterawsadm-darwin-amd64
    chmod +x ./clusterctl
    sudo mv ./clusterctl /usr/local/bin/clusterctl
    ```
3) Export AWS Variables
    ```
    source env-files/aws-exports.sh
    ```
4) Create local management cluster:
    ```
    kind create cluster --name clusterapi
    ```
5) Create the Cloudformation Stack
    ```
    clusterawsadm alpha bootstrap create-stack
    ```
6) Initialize the Management Cluster
    ```
    clusterctl init --infrastructure aws
    ```
7) Backup the kubeconfig
    ```
    cp $HOME/.kube/config  $HOME/.kube/config.capi
    ```
8) Build the cluster configuration
    ```
    clusterctl config cluster tas --kubernetes-version v1.15.7 --control-plane-machine-count=1 --worker-machine-count=6 --kubeconfig=$HOME/.kube/config.capi > tas.yaml
    ```
9) Modify the tas.yaml file to adjust root disk sizing.  Add:
    ```
    rootVolume:
        size: 25
to the AWSMachineTemplate spec.  The result should look like this:

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
10) Create your Workload cluster for your TAS deployment:
    ```
    kubectl --kubeconfig=/Users/dbaskette/.kube/config.capi  apply -f ./tas.yaml
    ```



