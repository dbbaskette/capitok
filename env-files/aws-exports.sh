export AWS_REGION=<us-east-1>
export AWS_ACCESS_KEY_ID=<access_key>
export AWS_SECRET_ACCESS_KEY=<secret_access_key>
export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm alpha bootstrap encode-aws-credentials)
export AWS_SSH_KEY_NAME=<aws_ssh_key>
export AWS_CONTROL_PLANE_MACHINE_TYPE=t3.xlarge 
export AWS_NODE_MACHINE_TYPE=t3.xlarge