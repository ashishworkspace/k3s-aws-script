#!/bin/bash

### installing essentials

sudo yum update -y
sudo yum install git -y

### install requirements for longhorn
sudo yum install -y iscsi-initiator-utils

### install docker for docker registry.

sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

### install custom metrics server dependency


### run docker registry.
sudo docker run -d -p 5000:5000 --restart=always -e REGISTRY_STORAGE_DELETE_ENABLED=true --name registry registry:2

### allow insecure registries in docker daemon

export INSTANCE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
export NODE_PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

cat << EOF >> /etc/docker/daemon.json
{"insecure-registries": ["$INSTANCE_IP:5000"]}
EOF

### restart docker service, so that above values are updated for docker daemon
sudo service docker restart

### add registry as private registry in k3s configuration

cat << EOF >> /home/ec2-user/registries.yaml
mirrors:
  docker.io:
    endpoint:
      - "https://registry-1.docker.io"
  $INSTANCE_IP:5000:
    endpoint:
      - "http://$INSTANCE_IP:5000"
EOF

### install k3s server

export K3S_NODE_NAME=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
export PROVIDER_ID=aws:///$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)/$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

export INSTALL_K3S_EXEC=" \
    --token=coIeS98V5UxzKYTLX0Uzzd4pkxfPSwBxiCUFtUm1sURd66mnZlT3uhk \
    --flannel-backend=none \
    --cluster-cidr=192.168.0.0/16
    --disable-cloud-controller \
    --kubelet-arg cloud-provider=external \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --node-label KubernetesCluster=k3s-cluster \
    --node-label groupRole=master \
    --private-registry \"/home/ec2-user/registries.yaml\" \
    --tls-san $NODE_PUBLIC_IP \
    --kubelet-arg provider-id=$PROVIDER_ID \
    --kubelet-arg allowed-unsafe-sysctls=kernel.msg*,net.core.somaxconn "

curl -sfL https://get.k3s.io | sh -

### copy node token for scp command
echo -n $(sudo cat /var/lib/rancher/k3s/server/node-token) > /home/ec2-user/node-token

### run aws cloud controller manager manifest.
kubectl apply -f https://raw.githubusercontent.com/ashishworkspace/k3s-master-slave-script/master/cloud-provider-aws/master/manifests/rbac.yaml
kubectl apply -f https://raw.githubusercontent.com/ashishworkspace/k3s-master-slave-script/master/cloud-provider-aws/master/manifests/aws-cloud-controller-manager-daemonset.yaml

### run calico manifest here.
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

### run longhorn manifest for persistence
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
