# capitok
End to End demo environment using Cluster API for a base K8S Cluster for Tanzu Application Service on K8S

These instructions are designed to work on a mac

Prereqs:
* kubectl
* docker
* kind
* AWS cli
* jq
* helm v3
* Clone of this repo
* DNS Domain managed managed at AWS, or change NS entries to 

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

    ![Cluster Ready](https://github.com/dbbaskette/capitok/raw/master/images/cluster-complete.png)







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
1. Add AWS EBS Storage Class for Dynamic Volume Provisioning
    ```
    kubectl create -f yaml/aws-ebs-storageclass.yaml
    ```

## Setup cert-manager and Let's encrypt for SSH certs
1. Install NGINX Ingress Controller. 
    ```
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/cloud-generic.yaml

    ```
1. Make a note of the AWS elb assigned to NGINX
    ```
    kubectl get svc ingress-nginx --namespace=ingress-nginx -o=jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    ```

1. Install cert-manager.
    ```
    kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.14.2/cert-manager.yaml
    ```
1. Edit the yaml/staging-issuer.yaml file and add your email address. The create the staging issuer object.
    ```
    kubectl create -f yaml/staging-issuer.yaml
    ```
1. Create the simple echo test services
    ```
    kubectl apply -f yaml/echo1.yaml
    kubectl apply -f yaml/echo2.yaml
    ```
1. Create the ingress for the test services
    ```
    kubectl apply -f yaml/echo-ingress-staging.yaml
    ```
1. Create a Route53 Zone that matches your Personal DNS domain. Edit your Personal DNS domain to use the same NS records as this new Route53 Zone.  You could also do this as a subdomain, but that's not covered here.
1. Create Route53 CNAME Records for Test Services
    ```
    echo1.<YOUR-DOMAIN>   CNAME <ELB Address from Step Above>
    echo2.<YOUR-DOMAIN>   CNAME <ELB Address from Step Above>
    ```
1. Check if cert was created. This should return Successfully created Certificate echo-tls
    ```
    kubectl describe ingress
    ```
1. Test the service:
    ```
    curl https://echo1.<TOUR-DOMAIN>
    curl https://echo2.<TOUR-DOMAIN>
    ```
1. Edit the yaml/prod-issuer.yaml file and add your email address. The create the production issuer object.
    ```
    kubectl create -f yaml/prod-issuer.yaml
    ```
1. Create the ingress for the production issuer
    ```
    kubectl apply -f yaml/echo-ingress-prod.yaml
    ```
1.  Verify certificate was created properly
    ```
    kubectl describe certificate
    ```
## Install Harbor Container Registry

1. Add Bitnami Repo to Helm
    ```
    helm repo add bitnami https://charts.bitnami.com/bitnami
    ```
1. Edit yaml/harbor-value.yaml and insert your domain name
1. Install harbor via Helm
    ```
    helm install harbor-release bitnami/harbor -f yaml/harbor-values.yaml
1. When install is complete, use kubectl to get the elb address (should be smae as echo tests). Then, create a Route53 CNAME record that points harbor.<YOUR-DOMAIN> to that elb address.
    ```
    kubectl get ingress harbor-release-ingress
    ```
1. You can now login to harbor with the *admin* user.  Run this command to get the password:
    ```
    kubectl get secret --namespace default harbor-release-core-envvars -o=jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' | base64 --decode
    ```
1. Create a project in harbor called tas-workloads.
    ![Create Project](https://github.com/dbbaskette/capitok/raw/master/images/harbor-repo1.png)
## INSTALL TAS for Kubernetes
1. Obtain the tarfile release of tas for k8s and extract it.
1. Remove the custom overlay that uses clusterIP instead of a Load Balancer
    ```
    rm -f ./custom-overlays/replace-loadbalancer-with-clusterip.yaml
    ```
1. Edit yaml/tas-exports.sh and then source it.
    ```
    source yaml/tas-exports.sh
    ```
1. Generate Deployment defaults
    ```
    ./bin/generate-values.sh -d "tas.<YOUR-DOMAIN>" > /tmp/deployment-values.yml
    ```
1. Install TAS for K8s
    ```
    ./bin/install-tas.sh /tmp/deployment-values.yml
    ```
1. Get the name of the AWS ELB created for the Istio Gateway.
    ```
    kubectl get svc istio-ingressgateway --namespace=istio-system
    ```
1. Create a ROUTE53 cname record in your DNS Zone that redirects a wildcard tas domain to the ELB from the previous step.
    ```
    *.tas.<YOUR_DOMAIN>.  CNAME <ELB-ADDRESS>
    ```
## LOGIN TO TAS for K8S AND TEST
1. Set the API Target
    ```
    cf api --skip-ssl-validation https://api.tas.<YOUR-DOMAIN>
    ```
1. Get the admin password from the deployment file
    ```
    cat /tmp/deployment-values.yml| grep cf_admin_password
    ```
1. Login as admin
    ```
    cf auth admin <password>
    ```
1. Enable docker container support (THIS IS A TEMP STEP)
    ```
    cf enable-feature-flag diego_docker
    ```
1. Create Test Org and Space
    ```
    cf create-org test-org
    cf create-space -o test-org test-space
    cf target -o test-org -s test-space
    ```
1. Clone Application for deployment and build it
    ```
    git clone https://github.com/cloudfoundry-samples/spring-music.git
    cd spring-music
    ./gradlew clean assemble
    ```
1. Push application to TAS
    ```
    cf push
    ```






    















