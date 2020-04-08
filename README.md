# capitok
End to End demo environment using Cluster API for a base K8S Cluster for Tanzu Application Service on K8S

These instructions are designed to work on a mac


Setup ClusterAPI and AWS
------------------------

Prereqs:
* kubectl
* docker
* kind


1) Install clusterctl binary 
    ```
    curl -L  https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.3/clusterctl-darwin-amd64
    chmod +x ./clusterctl
    sudo mv ./clusterctl /usr/local/bin/clusterctl
    ```


