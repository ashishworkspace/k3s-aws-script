#!/bin/bash

sudo yum update -y
sudo yum install -y iscsi-initiator-utils

### add registry as private registry in k3s configuration

cat << EOF >> /home/ec2-user/registries.yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry-1.docker.io"
  10.0.0.73:5000:
    endpoint:
      - "http://10.0.0.73:5000"
EOF

### install k3s agent with private registry configuration and docker enabled.

export K3S_NODE_NAME=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
export PROVIDER_ID=aws:///$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

export INSTALL_K3S_EXEC=" \
--kubelet-arg cloud-provider=external \
--node-label KubernetesCluster=k3s-cluster \
--node-label slave=k3s-slave \
--node-label groupRole=worker \
--node-label instanceEnv=prod \
--private-registry \"/home/ec2-user/registries.yaml\" \
--kubelet-arg provider-id=$PROVIDER_ID \
--kubelet-arg allowed-unsafe-sysctls=kernel.msg*,net.core.somaxconn"

curl -sfL https://get.k3s.io | K3S_URL="https://3.110.214.30:6443" K3S_TOKEN="coIeS98V5UxzKYTLX0Uzzd4pkxfPSwBxiCUFtUm1sURd66mnZlT3uhk" sh -
