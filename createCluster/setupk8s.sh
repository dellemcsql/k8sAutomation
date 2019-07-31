#!/bin/bash -e

masterNode=""
for node in `cat /servers.txt`; do
    arrIN=(${node//,/ })
    nodeip=${arrIN[0]}
    nodename=${arrIN[1]}
    grep -qxF "$nodeip $nodename" /etc/hosts || echo "$nodeip $nodename" >> /etc/hosts

    if [[ $(hostname) =~ .*master.* ]]
    then
        declare -g masterNode=$nodename
    fi

done

#Adding entry in Hosts file
#cat >>/etc/hosts<<EOF
#10.230.79.151 kubemaster1.sqlteam.com kubemaster1
#10.230.79.152 kubeworker1.sqlteam.com kubeworker1
#10.230.79.153 kubeworker2.sqlteam.com kubeworker2
#10.230.79.154 kubeworker3.sqlteam.com kubeworker3
#EOF

#service network restart

#grep -qxF '$nodeip $nodename' /etc/hosts || echo '$nodeip $nodename' >> /etc/hosts
#grep -qxF '10.230.79.143 kubeworker1.sqlteam.com kubeworker1' /etc/hosts || echo '10.230.79.143 kubeworker1.sqlteam.com kubeworker1' >> /etc/hosts
#grep -qxF '10.230.79.144 kubeworker2.sqlteam.com kubeworker2' /etc/hosts || echo '10.230.79.144 kubeworker2.sqlteam.com kubeworker2' >> /etc/hosts
#grep -qxF '10.230.79.145 kubeworker3.sqlteam.com kubeworker3' /etc/hosts || echo '10.230.79.145 kubeworker3.sqlteam.com kubeworker3' >> /etc/hosts

echo "[Task 1] Setting up Docker-EE..."
# RHEL Subscription
#echo "[] Setting Hostname..."
#host_name=$(uname -n)

#if [[ $(hostname) =~ .*master.* ]]
#then
#    echo " Already you have set hostname i.e : $host_name"
#else 
#    if [[ $(hostname) =~ .*worker.* ]]
#    then
#        echo " Already you have set hostname i.e : $host_name"
#    else
#	echo "Current hostname is  $host_name"
#        echo "Enter new hostname (ex:- name.sqlteam.com) : "
#        read name
#        sudo hostnamectl set-hostname $name >/dev/null 2>&1
#        echo "hostname set to  $name"
#    fi
#fi

# Install the katello-ca-consumer-latest RPM

echo "[] Installing the katello-ca-consumer-latest RPM..."
rpm_kat="katello-ca-consumer-rhs.us.dell.com-1.0-1.noarch"

if rpm -q $rpm_kat
then
    echo "    $rpm_kat already installed"
else
 rpm -Uvh http://rhs.us.dell.com/pub/katello-ca-consumer-latest.noarch.rpm >/dev/null 2>&1
fi

# To subscribe to RHEL repositories, run:
echo "[] Subscribe to RHEL repositories..."
#if  
subscription-manager register --org=Dell --activationkey=rhev >/dev/null 2>&1
#then
#        exit 0
#fi

# To attach to available subscriptions, run:
echo "[] Attach to available subscriptions..."
subscription-manager refresh >/dev/null 2>&1
subscription-manager attach --auto >/dev/null 2>&1

# for docker : enable additional repositories, and it will depend on the packages you need
echo "[] enable additional repositories..."
subscription-manager repos --enable=rhel-7-server-extras-rpms >/dev/null 2>&1
subscription-manager repos --enable=rhel-7-server-rpms >/dev/null 2>&1
subscription-manager repos --enable=rhel-7-server-optional-rpms >/dev/null 2>&1
#subscription-manager repos --enable=rhel-server-rhscl-7-rpms >/dev/null 2>&1

#removing older repos
sudo rm /etc/yum.repos.d/docker*.repo >/dev/null 2>&1
sudo rm /etc/yum.repos.d/kuber*.repo >/dev/null 2>&1

#cat >>/etc/yum.conf<<EOF
#sslverify=false
#EOF
grep -qxF 'sslverify=false' /etc/yum.conf || echo 'sslverify=false' >> /etc/yum.conf

# update the yum repo
echo "[] update the yum repo..."
yum -y update >/dev/null 2>&1
yum -y upgrade >/dev/null 2>&1
#if yum -y update && yum -y upgrade;then
#        exit 0
#fi

# Docker pre-requisites
echo "[] Setup docker pre-requisites..."
#mv /etc/yum.repos.d/redhat.repo / >/dev/null 2>&1
#sudo rm /etc/yum.repos.d/docker*.repo >/dev/null 2>&1
#sudo rm /etc/yum.repos.d/kuber*.repo >/dev/null 2>&1
yum remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine \
		  docker-ee \
		  docker-ee-cli \
		  containerd.io \
		  docker-ce \
		  docker-ce-cli >/dev/null 2>&1

export DOCKERURL="https://storebits.docker.com/ee/m/sub-7d49edb4-830c-4f85-b5f2-e18083b49256";
sudo -E sh -c 'echo "$DOCKERURL/rhel" > /etc/yum/vars/dockerurl';

sudo sh -c 'echo "7.6" > /etc/yum/vars/dockerosversion';
sudo yum-config-manager --enable rhel-7-server-extras-rpms >/dev/null 2>&1
echo "[] Installing yum-utils device-mapper-persistent-data lvm2..."
yum install -y yum-utils device-mapper-persistent-data lvm2 >/dev/null 2>&1
echo "[] Adding docker-ee repo..."
sudo -E yum-config-manager \
    --add-repo \
    "$DOCKERURL/rhel/docker-ee.repo" >/dev/null 2>&1
echo "[] Installing Docker-EE..."
sudo yum -y install docker-ee docker-ee-cli containerd.io >/dev/null 2>&1
echo "[] Setting up docker daemon config option..."

sudo cat >/etc/docker/daemon.json<<EOF
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": { "max-size": "100m" },
"storage-driver": "overlay2",
"storage-opts": [ "overlay2.override_kernel_check=true" ],
"insecure-registries":["dellregistry.com:5000"]
}
EOF

sudo systemctl daemon-reload >/dev/null 2>&1

# Enable start and test docker service
echo "[TASK 2] Enable start and test docker service"

sudo systemctl enable docker >/dev/null 2>&1
sudo systemctl start docker >/dev/null 2>&1
sudo systemctl status docker >/dev/null 2>&1
#docker run hello-world;

echo "[] Docker installation completed...."

systemctl disable firewalld >/dev/null 2>&1
systemctl stop firewalld >/dev/null 2>&1
# Add yum repo file for Kubernetes
echo "[TASK 3] Add yum repo file for kubernetes"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

yum -y update >/dev/null 2>&1

# disable swap
sed -i '/swap/d' /etc/fstab
swapoff -a >/dev/null 2>&1

# selinux disabled
setenforce 0 >/dev/null 2>&1
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Install Kubernetes
echo "[TASK 4] Install Kubernetes (kubeadm, kubelet and kubectl)"

#yum install -y -q kubeadm kubelet kubectl
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes >/dev/null 2>&1

# Start and Enable kubelet service
echo "[TASK 5] Enable and start kubelet service"
#systemctl enable kubelet >/dev/null 2>&1
systemctl enable --now kubelet >/dev/null 2>&1
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/sysconfig/kubelet
systemctl start kubelet >/dev/null 2>&1

# iptable setup
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system >/dev/null 2>&1

# check br_netfilter
lsmod | grep br_netfilter >/dev/null 2>&1
modprobe br_netfilter >/dev/null 2>&1

# Install additional required packages
echo "[TASK 6] Install additional packages"
yum install -y -q which net-tools sudo sshpass bzip2 less >/dev/null 2>&1

# Copy cached images
#echo "coping images"
#sshpass -p @Vantage4 scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@10.230.79.141:/home/sanranjan/automation/allinone.tar.bz2 /allinone.tar.bz2
#echo "unziping the compressed file"
#bunzip2 /allinone.tar.bz2
#echo "loading images"
#docker load < /allinone.tar

#######################################
# To be executed only on master nodes #
#######################################

if [[ $(hostname) =~ .*master.* ]]
then

  # Initialize Kubernetes
  echo "[TASK 7] Initialize Kubernetes Cluster"
  kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=Swap,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,SystemVerification >> /root/kubeinit.log 2>&1

  # Copy Kube admin config to local client
  echo "[TASK 8] Copy kube admin config to root user .kube directory on client machine"
  sshpass -p @Vantage4 scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no /etc/kubernetes/admin.conf root@10.230.79.141:/home/sanranjan/.kube/config 
  #cp /etc/kubernetes/admin.conf /root/.kube/config

  # Copy Kube admin config to master node
  echo "[TASK 8] Copy kube admin config to root user .kube directory"
  mkdir /root/.kube >/dev/null 2>&1
  cp /etc/kubernetes/admin.conf /root/.kube/config

  # Deploy flannel network
  echo "[TASK 9] Deploy flannel network"
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml > /dev/null 2>&1

  # Generate Cluster join command
  echo "[TASK 10] Generate and save cluster join command to /joincluster.sh"
  joinCommand=$(kubeadm token create --print-join-command) 
  echo "$joinCommand --ignore-preflight-errors=Swap,FileContent--proc-sys-net-bridge-bridge-nf-call-iptables,SystemVerification" > /joincluster.sh

fi

#######################################
# To be executed only on worker nodes #
#######################################

if [[ $(hostname) =~ .*worker.* ]]
then

  # Join worker nodes to the Kubernetes cluster
  echo "[TASK 7] Join node to Kubernetes Cluster"
  
  #echo "enter master ip address :"
  #read master_ip
  #echo "enter root password for master node :"
  #read master_pwd

  #$cmd "date --set=\"$(sshpass -p $master_pwd ssh root@$master_ip -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no date)\""
  #eval $cmd
  #$cmd "sshpass -p $master_pwd scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$master_ip:/joincluster.sh /joincluster.sh 2>/tmp/joincluster.log"
  #$cmd "sshpass -p \"$master_pwd\" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@$master_ip:/joincluster.sh /joincluster.sh"
  #eval $cmd
  echo "$masterNode"
  sshpass -p @Vantage4 scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@kubemaster1.sqlteam.com:/joincluster.sh /joincluster.sh 2>/tmp/joincluster.log
  bash /joincluster.sh >> /tmp/joincluster.log 2>&1

fi

