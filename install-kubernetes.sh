#!/bin/bash

PUBLIC_LAN="192.168.0.0/24"
PODS_CIDR="10.244.0.0/16"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"

BOLD="\e[1m"
END="\e[0m"

KUBE_VERSION="v1.24.3"
MASTER_IP="192.168.0.139"
HOST_IP="192.168.0.139"
HOST_MODE


clear
echo -e "${GREEN}[ ${YELLOW}This will install Kubernetes ${BLUE}${BOLD}${KUBE_VERSION}${END}${GREEN} ]${END}"
echo -e "${GREEN}[ ${YELLOW}IP address: ${BLUE}${BOLD}${HOST_IP}${END}${GREEN} ]${END}"
echo -e "${GREEN}[ ${YELLOW}LAN CIDR: ${BLUE}${BOLD}${PUBLIC_LAN}${END}${GREEN} ]${END}"
echo "Continue y/n?"
read yesno

case $yesno in
  n|N)
    echo -e "Understood my master, exiting."
    exit
    ;;
  y|Y)
    echo -e "Excelent my master, I will continue with my duty..."
    ;;
  *)
    echo -e "Didn't understand your command, my master!"
    exit
    ;;
esac

# Disable SELinux
echo -e "${RED}[${YELLOW} Disabling SELinux ${RED}]${END}"
sudo setenforce 0
sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux

# System update
echo -e "${RED}[${YELLOW} System Update ${RED}]${END}"
sudo dnf -y update

# Install tools
echo -e "${RED}[${YELLOW} Installing Tools ${RED}]${END}"
sudo dnf install -y bind-utils net-tools vim git tar wget iproute-tc

# Disable Swap
echo -e "${RED}[${YELLOW} Disabling SWAP ${RED}]${END}"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Configure firewall
echo -e "${RED}[${YELLOW} Configuring Firewall ${RED}]${END}"
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10251/tcp
firewall-cmd --permanent --add-port=10252/tcp
firewall-cmd --permanent --add-port=10255/tcp 
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --zone=public --permanent --add-source=${PUBLIC_LAN}
firewall-cmd --add-masquerade --permanent
firewall-cmd --reload

# Add hostname to /etc/hosts
echo -e "${RED}[${YELLOW} Adding hosts to /etc/hosts ${RED}]${END}"
cat <<EOF >> /etc/hosts
${HOST_IP}   $(hostname) echo.secura.net.ar
EOF

# Enabling ip6tables
echo -e "${RED}[${YELLOW} Enabling sysctl options ${RED}]${END}"
cat <<EOF >> /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system


# Add the Docker REPO
echo -e "${RED}[${YELLOW} Installing DOCKER ${RED}]${END}"
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install docker-ce --nobest -y --allowerasing
mkdir /etc/docker
cat <<EOF >> /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
      "overlay2.override_kernel_check=true"
    ]
  }
EOF
mkdir -p /etc/containerd
containerd config default>/etc/containerd/config.toml
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker

# Add the kubernetes REPO
echo -e "${RED}[${YELLOW} Installing Kubernetes ${RED}]${END}"
cat <<EOF >> /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

echo "KUBELET_EXTRA_ARGS= --runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice" > /etc/sysconfig/kubelet
systemctl enable --now kubelet

echo -e "${RED}[${YELLOW} Initializing Kubernetes ${RED}]${END}"
sudo kubeadm config images pull --cri-socket unix:///run/containerd/containerd.sock \
--kubernetes-version ${KUBE_VERSION}

sudo kubeadm init --pod-network-cidr=${PODS_CIDR} \
--upload-certs \
--kubernetes-version ${KUBE_VERSION}  \
--control-plane-endpoint $(hostname) \
--ignore-preflight-errors all  \
--cri-socket unix:///run/containerd/containerd.sock


echo -e "${RED}[${YELLOW} Adding profiles ${RED}]${END}"
if [ ${USER} == "root" ];then
  export KUBECONFIG=/etc/kubernetes/admin.conf
  
else
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
fi


echo -e "${RED}[${YELLOW} Waiting a few seconds until the master node stabilizes... ${RED}]${END}"
for i in $(seq 1 60)
do
  echo -n "."
  sleep 1
done

echo -e "${RED}[${YELLOW} Deploying Network Plugin ${RED}]${END}"
kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

echo -e "${RED}[${YELLOW} Removing taint so master node can schedule pods ${RED}]${END}"
kubectl taint node $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint node $(hostname) node-role.kubernetes.io/master:NoSchedule-

echo -e "${RED}[${YELLOW} Downloading HELM ${RED}]${END}"
wget https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz
tar -xvf helm-v3.7.2-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/

# v1
echo -e "${RED}[${YELLOW} Adding the NGINX Ingress Controller ${RED}]${END}"
helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update
helm install nginx-ic nginx-stable/nginx-ingress

echo -e "${RED}[${YELLOW} Adding the Kubernetes Dashboard ${RED}]${END}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.6.1/aio/deploy/recommended.yaml



# v2
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
