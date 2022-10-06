#!/bin/bash
# Gaston Martres <gastonmartres@gmail.com>
#
# Script for installing kubernetes in RHEL like distros.
#
# TODO: 
# - IP Address detection.
# - Command line parameters
#

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
END="\e[0m"

# General Variables
PUBLIC_LAN="192.168.0.0/24"
PODS_CIDR="10.244.0.0/16"
MASTER_IP="192.168.0.70"
HOST_IP="192.168.0.70"

# Kubernetes Variables
KUBE_VERSION="v1.25.2"

# Helm deployments Variables
INSTALL_DASHBOARD=0
INSTALL_NGINX_IC=0
INSTALL_METRICS=0

if [ $USER != "root" ];then
  echo -e "${RED}${BOLD}[ ERROR ]${YELLOW} THIS COMMAND IS INTENDED TO RUN AS ROOT! EXITING${END}"
  exit
fi

clear
echo -e "${GREEN}[ ${YELLOW}This will install Kubernetes ${BLUE}${BOLD}${KUBE_VERSION}${END}${GREEN} ]${END}"
echo -en "${GREEN}[ ${YELLOW}LAN IP CIDR? (Ex: 192.168.0.0/24)${END}${GREEN} ]${END}: "
read lan
if [[ $lan =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2}$ ]]; then
  OIFS=$IFS
  IFS='./'
  ip=($lan)
  IFS=$OIFS
  [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 && ${ip[4]} -le 32 ]]
  PUBLIC_LAN=$lan
else
  echo -e "CIDR no recognized. Exiting..."
  exit
fi

echo -en "${GREEN}[ ${YELLOW}Host IP Address (Ex: 192.168.0.70)${END}${GREEN} ]${END}: "
read hostip
if [[ $hostip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  OIFS=$IFS
  IFS='./'
  ip=($hostip)
  IFS=$OIFS
  [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
  HOST_IP=$hostip
else
  echo -e "Ilegal IP Address. Exiting..."
  exit
fi

echo -en "${GREEN}[ ${YELLOW}Update ${BLUE}${BOLD}packages? (y/n)${END}${GREEN} ]${END}: "
read packages
case $packages in
  y|Y)
    UPDATE_PACKAGES=1
    echo -e "\tWe will update packages...\n"
    ;;
  n|N)
    UPDATE_PACKAGES=0
    echo -e "\tWe will NOT update packages...\n"
    ;;
  *)
    echo "Option not recognized... exit"
    exit 1
    ;;
esac

echo -en "${GREEN}[ ${YELLOW}Install as ${BLUE}${BOLD}(M)aster or (S)lave?${END}${GREEN} ]${END}: "
read master
case $master in
  m|M)
    IS_MASTER=1
    echo -e "\tMaster it is...\n"
    ;;
  s|S)
    IS_MASTER=0
    echo -e "\tSlave it is...\n"
    ;;
  *)
    echo "Option not recognized... exit"
    exit 1
    ;;
esac

echo -en "${GREEN}[ ${YELLOW}Install ${BLUE}${BOLD}HELM? (y/n)${END}${GREEN} ]${END}: "
read helm
case $helm in
  y|Y)
    INSTALL_HELM=1
    echo -e "\tWe will install HELM\n"
    ;;
  n|N)
    INSTALL_HELM=0
    echo -e "\tWe will NOT install HELM\n"
    ;;
  *)
    echo "Option not recognized... exit"
    exit 1
    ;;
esac

# if INSTALL_HELM == 1, then we show deployments that can be installed by helm.
if [ $INSTALL_HELM -eq 1 ];then
  echo -en "${GREEN}[ ${YELLOW}Install ${BLUE}${BOLD}Metrics server? (y/n)${END}${GREEN} ]${END}: "
  read metrics
  case $metrics in
    y|Y)
      INSTALL_METRICS=1
      echo -e "\tWe will install metrics server\n"
      ;;
    n|N)
      INSTALL_METRICS=0
      echo -e "\tWe will NOT install the metrics server\n"
      ;;
    *)
      echo "Option not recognized... exit"
      exit 1
      ;;
  esac

  echo -en "${GREEN}[ ${YELLOW}Install ${BLUE}${BOLD}Dashboard? (y/n)${END}${GREEN} ]${END}: "
  read dashboard
  case $dashboard in
    y|Y)
      INSTALL_DASHBOARD=1
      echo -e "\tWe will install the kubernetes dashboard\n"
      ;;
    n|N)
      INSTALL_DASHBOARD=0
      echo -e "\tWe will NOT install the kubernetes dashboard\n"
      ;;
    *)
      echo "Option not recognized... exit"
      exit 1
      ;;
  esac
  echo -en "${GREEN}[ ${YELLOW}Install ${BLUE}${BOLD}ingress-nginx IC? (y/n)${END}${GREEN} ]${END}: "
  read nginx
  case $nginx in
    y|Y)
      INSTALL_NGINX_IC=1
      echo -e "\tWe will install the ingress-nginx IC\n"
      ;;
    n|N)
      INSTALL_NGINX_IC=0
      echo -e "\tWe will NOT install the ingress-nginx IC\n"
      ;;
    *)
      echo "Option not recognized... exit"
      exit 1
      ;;
  esac
fi

echo -en "${GREEN}[ ${YELLOW}Install ${BLUE}${BOLD}flannel CNI? (y/n)${END}${GREEN} ]${END}: "
read flannel
case $flannel in
  y|Y)
    INSTALL_FLANNEL=1
    echo -e "\tWe will install the flannel CNI Plugin\n"
    ;;
  n|N)
    INSTALL_FLANNEL=0
    echo -e "\tWe will NOT install the flannel CNI Plugin\n"
    ;;
  *)
    echo "Option not recognized... exit"
    exit 1
    ;;
esac

# Show a little summary
echo "LAN CIDR: $PUBLIC_LAN"
echo "HOST IP: $HOST_IP"
echo "UPDATE_PACKAGES: $UPDATE_PACKAGES"
echo "IS_MASTER: $IS_MASTER"
echo "INSTALL_HELM: $INSTALL_HELM"
echo "INSTALL_DASHBOARD: $INSTALL_DASHBOARD"
echo "INSTALL_METRICS: $INSTALL_METRICS"
echo "INSTALL_FLANNEL: $INSTALL_FLANNEL"
echo "INSTALL_NGINX_IC: $INSTALL_NGINX_IC"

echo -en "${GREEN}[ ${RED}${BOLD}Continue? (y/n)${END}${GREEN} ]${END}: "
read yesno

case $yesno in
  n|N)
    echo -e "\tUnderstood my master, exiting."
    exit
    ;;
  y|Y)
    echo -e "\tExcelent my master, I will continue with my duty..."
    ;;
  *)
    echo -e "\tDidn't understand your command, my master!"
    exit
    ;;
esac

# Disable SELinux
echo -e "${RED}[${YELLOW} Disabling SELinux ${RED}]${END}"
sudo setenforce 0
sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux

if [ $UPDATE_PACKAGES -eq 1 ];then
  # System update
  echo -e "${RED}[${YELLOW} System Update ${RED}]${END}"
  sudo dnf -y update
fi

# Install tools
echo -e "${RED}[${YELLOW} Installing Tools ${RED}]${END}"
sudo dnf install -y bind-utils net-tools vim git tar wget iproute-tc

# Disable Swap
echo -e "${RED}[${YELLOW} Disabling SWAP ${RED}]${END}"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Configure firewall
echo -e "${RED}[${YELLOW} Configuring Firewall ${RED}]${END}"
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --permanent --add-port=10255/tcp 
sudo firewall-cmd --permanent --add-port=30000-32767/tcp
sudo firewall-cmd --zone=public --permanent --add-source=${PUBLIC_LAN}
sudo firewall-cmd --add-masquerade --permanent
sudo firewall-cmd --reload

# Add hostname to /etc/hosts
echo -e "${RED}[${YELLOW} Adding hosts to /etc/hosts ${RED}]${END}"
cat <<EOF >> /etc/hosts
${HOST_IP}   $(hostname)
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
if [ $IS_MASTER -eq 1 ];then
  echo -e "${RED}[${YELLOW} Initializing Kubernetes ${RED}]${END}"
  sudo kubeadm config images pull --cri-socket unix:///run/containerd/containerd.sock \
  --kubernetes-version ${KUBE_VERSION}

  sudo kubeadm init --pod-network-cidr=${PODS_CIDR} \
  --upload-certs \
  --kubernetes-version ${KUBE_VERSION}  \
  --control-plane-endpoint=${MASTER_IP} \
  --node-name $(hostname) \
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

  if [ $INSTALL_FLANNEL -eq 1 ];then
    echo -e "\n${RED}[${YELLOW} Deploying Network Plugin ${RED}]${END}"
    kubectl apply -f https://github.com/coreos/flannel/raw/master/Documentation/kube-flannel.yml

    echo -e "${RED}[${YELLOW} Removing taint so master node can schedule pods ${RED}]${END}"
    kubectl taint node $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-
    kubectl taint node $(hostname) node-role.kubernetes.io/master:NoSchedule-
  fi

  if [ $INSTALL_HELM -eq 1 ];then
    echo -e "${RED}[${YELLOW} Downloading HELM ${RED}]${END}"
    wget https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz
    tar -xvf helm-v3.7.2-linux-amd64.tar.gz
    mv linux-amd64/helm /usr/local/bin/
  fi

  if [ $INSTALL_DASHBOARD -eq 1 ];then
    echo -e "${RED}[${YELLOW} Adding the Kubernetes Dashboard ${RED}]${END}"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.6.1/aio/deploy/recommended.yaml
  fi

  if [ $INSTALL_METRICS -eq 1 ];then
    echo -e "${RED}[${YELLOW} Adding the Kubernetes Dashboard ${RED}]${END}"
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm upgrade --install metrics-server metrics-server/metrics-server
  fi

  if [ $INSTALL_NGINX_IC -eq 1 ];then
    echo -e "${RED}[${YELLOW} Installing ingress-nginx Ingress Controller ${RED}]${END}"
    helm upgrade --install ingress-nginx ingress-nginx \
      --repo https://kubernetes.github.io/ingress-nginx \
      --namespace ingress-nginx --create-namespace
  fi
fi